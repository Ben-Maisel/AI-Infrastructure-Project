# Chroma's real Kubernetes resources: PVC, Deployment, Service.
# agent/retrieval.py talks to this Service over the network whenever
# AGENT_CHROMA_HOST is set (see populate_knowledge_base.tf and,
# eventually, the app Deployment).

resource "kubectl_manifest" "chroma_pvc" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: chroma-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: gp3
      resources:
        requests:
          storage: 10Gi
  YAML

  depends_on = [kubectl_manifest.gp3_storageclass]
}

resource "kubectl_manifest" "chroma_deployment" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: chroma
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: chroma
      template:
        metadata:
          labels:
            app: chroma
        spec:
          # Lands on the on-demand-only cpu-chroma NodePool.
          nodeSelector:
            workload-tier: chroma
          containers:
            - name: chroma
              image: chromadb/chroma:1.5.9
              ports:
                - containerPort: 8000
              volumeMounts:
                - name: data
                  mountPath: /data
              resources:
                requests:
                  cpu: 250m
                  memory: 512Mi
                limits:
                  cpu: "1"
                  memory: 1Gi
          volumes:
            - name: data
              persistentVolumeClaim:
                claimName: chroma-data
  YAML

  depends_on = [kubectl_manifest.chroma_pvc]
}

resource "kubectl_manifest" "chroma_service" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: chroma
    spec:
      selector:
        app: chroma
      ports:
        - port: 8000
          targetPort: 8000
  YAML

  depends_on = [kubectl_manifest.chroma_deployment]
}
