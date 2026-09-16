# Ollama's Deployment + Service. No PVC on purpose -- a standard EBS
# volume can only attach to one node at a time, which would cap this
# at 1 replica forever and defeat the whole point of the GPU NodePool.
# Each GPU node downloads its own model files onto its own (100Gi)
# root disk instead; the GPU EC2NodeClass was already sized with this
# in mind.

resource "kubectl_manifest" "ollama_deployment" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ollama
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: ollama
      template:
        metadata:
          labels:
            app: ollama
        spec:
          # Lands on the GPU NodePool.
          nodeSelector:
            workload-tier: ollama
          # Matches the taint on the GPU NodePool -- same shape the
          # NVIDIA device plugin itself uses (Exists, no fixed value).
          tolerations:
            - key: nvidia.com/gpu
              operator: Exists
              effect: NoSchedule
          containers:
            - name: ollama
              image: ollama/ollama:0.34.1
              ports:
                - containerPort: 11434
              resources:
                requests:
                  cpu: "1"
                  memory: 4Gi
                limits:
                  cpu: "3"
                  memory: 14Gi
                  nvidia.com/gpu: 1
  YAML
}

resource "kubectl_manifest" "ollama_service" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: ollama
    spec:
      selector:
        app: ollama
      ports:
        - port: 11434
          targetPort: 11434
  YAML

  depends_on = [kubectl_manifest.ollama_deployment]
}
