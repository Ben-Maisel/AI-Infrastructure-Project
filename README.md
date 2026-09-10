# AI Agent Infra Pipeline

An end-to-end deployment of a tool-calling AI agent, built to demonstrate production infrastructure practices — CI/CD, infrastructure-as-code, evals, and observability — not just model integration.

## Why This Project Exists

Most AI portfolio projects stop at "I called an LLM API." This one is designed to show the infrastructure engineering layer around an agent: how it's tested, deployed, monitored, and operated after it ships. That's the gap most entry-level candidates don't demonstrate, and it's the skill set hiring managers are actually short on.

## What It Does

A tool-calling agent that:
- Answers questions over a document set using retrieval-augmented generation (RAG)
- Takes at least one real action beyond text generation (e.g., queries a database, hits an external API, or writes a file)
- Runs multi-step logic via an agent framework (e.g., LangGraph), not a single prompt/response call

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   GitHub     │────▶│  CI/CD       │────▶│   Container       │
│   push       │     │  (Actions)   │     │   Registry         │
└─────────────┘     └──────┬───────┘     └────────┬─────────┘
                            │                       │
                    lint / test / eval        deploy to
                            │                  staging → prod
                            ▼                       ▼
                     ┌─────────────┐        ┌──────────────┐
                     │  Eval suite  │        │  Agent runtime │
                     │  (pass/fail) │        │  (K8s / Lambda)│
                     └─────────────┘        └───────┬────────┘
                                                      │
                                             ┌────────▼────────┐
                                             │  Observability   │
                                             │  (traces, logs,  │
                                             │  latency, cost)  │
                                             └──────────────────┘
```

## Components

### 1. The Agent
- **Framework:** LangGraph (or equivalent) for genuine multi-step reasoning and tool calls
- **Retrieval:** Vector store over a document set for RAG
- **Action:** At least one real tool call (DB query, API call, or file write) — not just text generation

### 2. Deployment
- **Containerization:** Docker
- **Target:** Kubernetes (kind/minikube locally, or a managed free tier) *or* serverless (AWS Lambda/Fargate) for a zero-cost setup
- **Infrastructure as Code:** Terraform — defines the deployment target, networking, and any managed services. This is the highest-signal piece for an infra-focused portfolio, since most ML projects skip IaC entirely.

### 3. CI/CD Pipeline
GitHub Actions workflow triggered on every push:
1. Lint and unit test the code
2. Run the **eval suite** — a fixed set of test prompts with expected behaviors/outputs, checked automatically
3. Build the container image
4. Deploy to a staging environment
5. Manual approval gate to promote to "production"

### 4. Observability
- Tracing and logging via OpenTelemetry or a purpose-built tool (LangSmith, Langfuse)
- Dashboard surfacing latency, token usage/cost, and failure modes
- Demonstrates ownership of the system *after* deployment, not just at build time

## Project Structure

```
.
├── agent/              # Agent logic, tools, and RAG pipeline
├── evals/              # Test prompts and expected behaviors
├── infra/              # Terraform configs
├── .github/workflows/  # CI/CD pipeline definitions
├── Dockerfile
└── docs/
    └── design.md        # Design decisions and tradeoffs (see below)
```

## Design Decisions & Tradeoffs

*(To be filled in as built — this is the section that turns a repo into an interview talking point.)*

- Why this agent framework over alternatives
- Why this deployment target over alternatives
- What broke during development, and how it was fixed
- How this would need to change to scale (traffic, cost, reliability)

## Status

- [ ] Agent core (RAG + tool calling)
- [ ] Dockerized
- [ ] Terraform infra
- [ ] CI/CD pipeline
- [ ] Eval suite
- [ ] Observability/dashboard
- [ ] Design write-up

## Scope Notes

This can be built as a **weekend version** (single tool call, local Docker + GitHub Actions lint/test only, no cloud deploy) or a **multi-week version** (full cloud deployment, Terraform-managed infra, staging/prod promotion gate, full observability stack) depending on time available before applying.
