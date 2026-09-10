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
Terraform (infra/bootstrap/ once, then infra/ every session)
  remote state: S3 bucket, native lockfile locking (not DynamoDB --
  Terraform 1.15+ flags dynamodb_table as deprecated)
      │
      ▼
VPC (2 AZs: us-east-2a/b)
  public subnets (→ Internet Gateway) │ private subnets (→ 1 shared NAT)
      │
      ▼
EKS cluster (control plane)
  ├── system node group (always-on: CoreDNS + Karpenter controller)
  ├── Karpenter CPU NodePool  ──  app Deployment (LangGraph + Streamlit)
  │                               exposed via LoadBalancer Service; own HPA
  ├── Karpenter CPU NodePool  ──  chroma Deployment (vector store, own PVC)
  │                               queried over the network, built once
  └── Karpenter GPU NodePool  ──  ollama Deployment (g4dn.xlarge,
       (nvidia.com/gpu)            NVIDIA device plugin); own HPA, scales
                                    independently of the app tier
      │
      ▼
HPA (one per Deployment)              Karpenter (node autoscaler)
  scales app + ollama pod        ──►   provisions matching CPU/GPU nodes
  replicas independently                when pods don't fit; terminates
                                         empty nodes once idle
      │
      ▼
scripts/loadtest/locustfile.py
  drives concurrent chat requests at the public LB, forcing a visible
  scale-up across app pods, ollama pods, AND both node pools -- then
  stops to observe all of it scale back down
```

**Why Terraform state is split into two configs (`infra/bootstrap/` +
`infra/`), and why locking is native S3 rather than DynamoDB:**
- `infra/bootstrap/` creates the S3 bucket that everything else's state
  lives in — a genuine chicken-and-egg problem, since a config can't
  store its own state in a bucket it hasn't created yet. It's applied
  once and rarely touched again; its own state stays local.
- The bucket is versioned (recover from a bad apply) and encrypted,
  with public access explicitly blocked.
- Originally built with a DynamoDB table for state locking (the classic,
  most widely-documented pattern) — switched to native S3 locking
  (`use_lockfile = true`) after Terraform 1.15 flagged the DynamoDB
  parameter as deprecated. Removed the now-unused table via a normal
  `terraform apply` diff, not a `-target` bypass, so the removal itself
  stayed reviewable.

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
- Decided to build this rather than leave it as a future note: a
  GPU-backed Karpenter NodePool (`g4dn.xlarge`) runs Ollama with real
  hardware acceleration instead of CPU-only inference. Because these
  are real EC2 nodes (not Fargate), mixing a CPU NodePool and a GPU
  NodePool in one cluster is straightforward — Fargate would not have
  allowed this at all, since it has no GPU support whatsoever, which
  was itself part of the original case for choosing Karpenter over it.

**Why Ollama (self-hosted) over a hosted LLM API:**
- Zero per-token cost and no API key management, which matters for a
  project meant to be run/demoed repeatedly without accruing bills.
- Tradeoff: lower output quality than Claude/GPT-class hosted models.
  Latency is addressed by the GPU NodePool above rather than accepted
  as a permanent tradeoff.

**Why each service is its own decoupled Deployment, not baked into the
app container:**
- Caught before building the Kubernetes manifests, by reasoning through
  what changes once there are *multiple* app pod replicas instead of
  one Compose container: the original design (each app pod scrapes and
  embeds the knowledge base itself on startup, exactly like
  `entrypoint.sh` does locally) would mean every pod HPA creates during
  a load spike independently re-scrapes kubernetes.io and rebuilds an
  identical vector store from scratch before it can serve a single
  request — slow, wasteful, and a bad way to treat an external site as
  a side effect of autoscaling.
- Fix: **Chroma runs as its own Deployment** (own persistent volume),
  built once, queried over the network by every app replica — the same
  pattern already used for Ollama, just applied consistently. "Scale
  the app" and "own the knowledge base" become fully independent
  concerns.
- **Ollama is also its own independently-scaled Deployment**, not a
  fixed singleton. Important nuance: unlike the app tier's cheap
  per-request work, Ollama's work is genuinely CPU/GPU-bound compute —
  running more replicas on the *same* fixed node capacity doesn't help,
  it just splits one compute budget more ways. It only avoids queuing
  because Karpenter provisions real additional GPU nodes to back new
  replicas, not because replication is free. This is why Ollama gets
  its own HPA and its own NodePool rather than sharing the app tier's.
- **`write_file` targets S3 in the cloud deployment, not local disk.**
  Same root problem as the knowledge base: a file written by one app
  pod is invisible to a different pod handling a later request, and is
  lost outright if that pod is scaled down or rescheduled. S3 is
  inherently shared and durable without needing any shared-filesystem
  infrastructure (no EFS, no PVC) — simpler than fixing the knowledge
  base problem was, since it's just an API call instead of a mount.

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
- **The GPU node dominates the cost, by a wide margin.** Queried real
  on-demand pricing (`aws pricing get-products`, us-east-2): `g4dn.xlarge`
  = $0.526/hr vs. `t3.medium` = $0.0416/hr — the GPU instance costs
  roughly 12-13x a CPU node. Everything else in this stack (EKS control
  plane, NAT Gateway, CPU nodes) is genuinely small change by comparison.
- **Realistic demo-session estimate: ~$1-2** for a ~2-hour session
  (setup, a ~30-minute load test at peak scale, teardown), itemized:
  EKS $0.20, NAT ~$0.30, system node ~$0.08, baseline compute (1 CPU +
  1 GPU node) for the non-peak portion ~$0.82, peak surcharge (extra
  CPU + GPU node during the load test) ~$0.28. A quick, focused demo
  would land under $1; even a generous 3-hour session stays well under
  $5.
- **The actual financial risk isn't the demo — it's forgetting to tear
  down.** An idle `g4dn.xlarge` costs the same $0.526/hr whether it's
  serving requests or sitting empty overnight.
- **Operating practice: stand the cluster up via `scripts/deploy_infra.py`
  for a demo/recording session, then tear it down immediately after —
  never leave it running unattended.** Treating teardown as a normal
  part of the workflow (not an afterthought) is itself worth calling out
  in interviews as a cost-awareness habit.
- **Safety rails against a runaway bill:** an explicit `maxReplicas` on
  every HPA, and a resource limit on each Karpenter NodePool, so a
  misconfigured metric or an unattended Locust run can't silently
  autoscale past what was intended.
- The load test should run in a short, bounded window — long enough to
  show a clear scale-up/scale-down cycle, not left running.
- **HPA metric nuance to resolve when building it:** default HPA scales
  on CPU/memory utilization, but the app pod is mostly *idle* (blocked
  on network I/O) while waiting on an Ollama response — CPU may not
  reflect the real signal of "under load." Worth deciding deliberately
  rather than defaulting into it.

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
  - Done already, not just planned: Ollama moved to a GPU NodePool, and
    Chroma decoupled into its own Deployment so pod replicas share one
    index instead of each holding a copy — see "why each service is its
    own decoupled Deployment" above.
  - Still open: Chroma today is self-hosted (own PVC), not a managed
    service — a real production system at larger scale would likely move
    to a managed vector DB (pgvector on RDS, or OpenSearch) for
    durability/ops guarantees beyond what one PVC-backed pod provides.
  - `single_nat_gateway = true` trades AZ-level resilience for half the
    hourly NAT cost — one AZ outage currently takes out egress for both
    AZs. A production system would use one NAT per AZ instead.
  - Queue-based request handling if load becomes bursty rather than
    steady, to smooth scale-up latency.
