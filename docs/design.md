# Design Decisions & Tradeoffs

This document tracks the architecture as planned, and gets updated as things
change during implementation. It's the record of *why*, not just *what*.

## System Overview

A tool-calling agent (LangGraph) that answers questions using RAG over a
scraped Kubernetes-docs knowledge base, and can write results to a file as
its "real action." It runs behind a Streamlit chat UI, backed by a local
LLM (Ollama) for both chat and embeddings — no external API keys, no
per-token cost.

## Local Development Architecture

- `docker-compose.yml` runs two services: `ollama` (model runtime) and
  `app` (LangGraph agent + Streamlit UI + Chroma vector store).
- On first startup, the app container scrapes the Kubernetes docs, builds
  the vector store, and pulls required Ollama models if missing — so
  `docker compose up` (via `scripts/setup.py`) is the entire setup process.
- This is deliberately the same container image used in production, so
  local dev and prod stay in parity — what you test locally is what runs
  on AWS.

## Production Deployment Architecture (planned)

```
GitHub push (main)
      │
      ▼
GitHub Actions CI/CD
  lint → unit test → eval suite → build image → push to ECR
      │
      ▼
Terraform-provisioned AWS infra
  ┌───────────────────────────────────────────────────┐
  │ EKS cluster (control plane)                        │
  │  ├── small managed node group (system add-ons +    │
  │  │     Karpenter controller itself)                │
  │  └── Karpenter-provisioned EC2 nodes (workload)     │
  │        └── app Deployment (agent+Streamlit)         │
  │              exposed via LoadBalancer Service       │
  └───────────────────────────────────────────────────┘
      │
      ▼
Horizontal Pod Autoscaler (HPA)          Karpenter (node autoscaler)
  watches CPU / request latency    ──►     provisions new EC2 nodes when
  scales app pod replicas up/down          pods can't be scheduled, and
                                            terminates empty nodes at rest
      │
      ▼
scripts/loadtest/locustfile.py
  drives concurrent chat requests at the public endpoint to force a
  visible scale-up at both the pod layer (HPA) and node layer (Karpenter),
  then stops to observe both scale back down
```

**Why EKS + Karpenter (real EC2 nodes) over a Fargate profile:**
- Kubernetes experience is the more broadly transferable, more
  sought-after skill for infra-focused roles compared to an ECS-specific
  setup — worth the extra complexity for the resume story.
- Fargate was considered first, but it abstracts node capacity away
  entirely — AWS provisions it invisibly, so there is no infrastructure
  layer to observe or screenshot. It would only ever show pod-count
  changing, not the fuller "Kubernetes autoscaling" story.
- Karpenter (AWS's modern, recommended node autoscaler, having largely
  replaced Cluster Autoscaler) gives two visible, demoable layers of
  scaling instead of one: HPA scales pod replicas, and when those pods
  don't fit on current capacity, Karpenter provisions new EC2 nodes
  within seconds — then terminates them once they're empty again.
- Chicken-and-egg note for implementation: Karpenter itself needs
  somewhere to run, so the cluster needs one small, always-on managed
  node group hosting system add-ons (CoreDNS, Karpenter controller)
  before Karpenter can provision anything else.
- Cost mitigation: Karpenter natively supports Spot instances — the
  workload NodePool can prioritize Spot capacity to minimize the cost of
  the demo window. Worth calling out explicitly as a cost-conscious
  choice, not just a scaling one.
- Future extension: because these are real EC2 nodes (not Fargate),
  a GPU-backed NodePool (e.g. `g5` instances) could later run Ollama with
  hardware acceleration instead of CPU-only inference — not needed for
  the initial demo, but a natural next step the architecture already
  supports.

**Why Ollama (self-hosted) over a hosted LLM API:**
- Zero per-token cost and no API key management, which matters for a
  project meant to be run/demoed repeatedly without accruing bills.
- Tradeoff: lower output quality and higher latency (CPU inference,
  initially) than Claude/GPT-class hosted models. Documented as a
  deliberate cost/capability tradeoff, not an oversight.

**Load testing / autoscaling demo:**
- `scripts/loadtest/locustfile.py` (Locust) simulates many concurrent
  users hitting the chat endpoint.
- Both the HPA (pod replica count) and Karpenter (node count) should
  visibly scale up as load rises, and scale back down once Locust stops
  — this two-layer scale-up/scale-down cycle, captured via the
  observability stack (replica count, node count, latency, and cost over
  time), is the core "I understand production operations" artifact of
  this project.

## Cost & Operational Notes

- EKS control plane costs a flat ~$0.10/hr regardless of usage — there is
  no free tier. EC2 node costs bill on top of that, minimized by using
  Spot capacity via Karpenter for the workload NodePool.
- **Operating practice: stand the cluster up via Terraform for a demo/
  recording session, then `terraform destroy` immediately after.** Treating
  teardown as a normal part of the workflow (not an afterthought) is itself
  worth calling out in interviews as a cost-awareness habit.
- The load test should run in a short, bounded window — long enough to
  show a clear scale-up/scale-down cycle, not left running.

## Design Decisions & Tradeoffs (README checklist)

- **Why this agent framework (LangGraph) over alternatives:** explicit
  graph-based control flow over tool calls and retrieval, rather than a
  single prompt/response — matches the "genuine multi-step reasoning"
  requirement and is more debuggable than an implicit agent loop.
- **Why this deployment target over alternatives:** see EKS + Karpenter
  rationale above.
- **What broke during development, and how it was fixed:** _(to fill in as
  built)_
- **How this would need to change to scale (traffic, cost, reliability):**
  - Swap Ollama for a GPU node group or hosted LLM API to fix latency
  - Replace the local Chroma file-based vector store with a managed vector
    DB (e.g., pgvector on RDS, or OpenSearch) so multiple pod replicas
    share one consistent index instead of each holding its own copy
  - Multi-AZ node/Fargate placement for availability
  - Queue-based request handling if load becomes bursty rather than
    steady, to smooth scale-up latency
