# One-shot Job: pulls both Ollama models, then scrapes the docs and
# builds the Chroma collection over the network. Reuses the same image
# build-and-push-app already builds -- it just needs to run our own
# agent/scrape.py and agent/retrieval.py, which no public image contains.
#
# Not expected to be re-run often (matches how rarely the knowledge
# base itself changes) -- but if it ever does need a re-run, its Pod
# spec is immutable once created, so re-apply won't recreate it on its
# own; delete the Job manually first (kubectl delete job
# populate-knowledge-base) and the next apply will recreate it.
#
# ignore_changes is load-bearing, not cosmetic: var.app_image_tag
# changes on every push now (build-and-push-app runs unconditionally),
# and without this, every later apply tries to update this Job's image
# -- which Kubernetes rejects outright since a Job's spec.template is
# immutable after creation, failing the whole cluster-addons/ apply
# and blocking everything depends_on this Job, forever. Confirmed live:
# exactly this happened, and Terraform's state ended up recording the
# rejected new tag anyway even though the actual object was untouched
# -- the next real (non -refresh=false) apply corrects that drift by
# refreshing from the live object before this lifecycle block applies.
#
# Known limitation: Ollama has no PVC (see ollama.tf), so if its pod
# is ever rescheduled onto a new node, the fresh container starts with
# zero models again and nothing auto-repulls them -- re-running this
# Job is the documented recovery step.

resource "kubectl_manifest" "populate_knowledge_base" {
  yaml_body = <<-YAML
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: populate-knowledge-base
    spec:
      backoffLimit: 2
      ttlSecondsAfterFinished: 3600
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: populate
              image: ${data.terraform_remote_state.infra.outputs.ecr_repository_url}:${var.app_image_tag}
              command: ["sh", "-c"]
              args:
                - |
                  until curl -sf "$OLLAMA_BASE_URL" > /dev/null; do
                    echo "Waiting for Ollama..."
                    sleep 2
                  done
                  curl -sf -X POST "$OLLAMA_BASE_URL/api/pull" -d "{\"name\": \"$AGENT_CHAT_MODEL\"}"
                  curl -sf -X POST "$OLLAMA_BASE_URL/api/pull" -d "{\"name\": \"$AGENT_EMBEDDING_MODEL\"}"
                  python -m agent.scrape
                  python -m agent.retrieval
              env:
                - name: OLLAMA_BASE_URL
                  value: "http://ollama:11434"
                - name: AGENT_CHROMA_HOST
                  value: "chroma"
                # config.py's defaults for these only apply inside
                # Python (os.getenv) -- the curl calls above are raw
                # shell, so these must be set explicitly or they'd
                # substitute as empty strings.
                - name: AGENT_CHAT_MODEL
                  value: "llama3.2"
                - name: AGENT_EMBEDDING_MODEL
                  value: "nomic-embed-text"
              resources:
                requests:
                  cpu: 250m
                  memory: 512Mi
                limits:
                  cpu: "1"
                  memory: 1Gi
  YAML

  depends_on = [
    kubectl_manifest.ollama_service,
    kubectl_manifest.chroma_service,
  ]

  lifecycle {
    ignore_changes = [yaml_body]
  }
}
