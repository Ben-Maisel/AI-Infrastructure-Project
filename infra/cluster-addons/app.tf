# The app itself: Streamlit chat UI + LangGraph agent. Talks to Ollama
# and Chroma over the network (same Services as populate_knowledge_base
# uses), writes tool output to S3 via IRSA instead of local disk.

resource "kubectl_manifest" "app_service_account" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: app
      annotations:
        eks.amazonaws.com/role-arn: ${data.terraform_remote_state.infra.outputs.app_iam_role_arn}
  YAML
}

resource "kubectl_manifest" "app_deployment" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: app
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: app
      template:
        metadata:
          labels:
            app: app
        spec:
          serviceAccountName: app
          # Lands on the spot-preferred cpu-app NodePool.
          nodeSelector:
            workload-tier: app
          containers:
            - name: app
              image: ${data.terraform_remote_state.infra.outputs.ecr_repository_url}:${var.app_image_tag}
              ports:
                - containerPort: 8501
              env:
                - name: OLLAMA_BASE_URL
                  value: "http://ollama:11434"
                - name: AGENT_CHROMA_HOST
                  value: "chroma"
                - name: AGENT_TOOL_OUTPUT_S3_BUCKET
                  value: "${data.terraform_remote_state.infra.outputs.app_tool_output_bucket}"
              resources:
                requests:
                  cpu: 250m
                  memory: 512Mi
                limits:
                  cpu: "1"
                  memory: 1Gi
  YAML

  depends_on = [
    kubectl_manifest.app_service_account,
    kubectl_manifest.populate_knowledge_base,
  ]
}

resource "kubectl_manifest" "app_service" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: app
    spec:
      type: LoadBalancer
      selector:
        app: app
      ports:
        - port: 80
          targetPort: 8501
  YAML

  depends_on = [kubectl_manifest.app_deployment]
}
