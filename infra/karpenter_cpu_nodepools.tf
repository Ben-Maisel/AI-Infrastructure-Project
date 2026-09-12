# Two CPU NodePools, both built from the same "cpu" EC2NodeClass --
# only the capacity-type policy differs. Deployments (later) steer onto
# the right one via nodeSelector matching the workload-tier label below.

resource "kubectl_manifest" "app_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: cpu-app
    spec:
      template:
        metadata:
          labels:
            workload-tier: app
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m"]
            - key: karpenter.k8s.aws/instance-cpu
              operator: In
              values: ["2", "4"]
          nodeClassRef:
            name: cpu
            group: karpenter.k8s.aws
            kind: EC2NodeClass
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m
      limits:
        cpu: "16"
        memory: 32Gi
  YAML

  depends_on = [kubectl_manifest.cpu_ec2_node_class]
}

resource "kubectl_manifest" "chroma_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: cpu-chroma
    spec:
      template:
        metadata:
          labels:
            workload-tier: chroma
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            # On-demand only -- Chroma runs a single replica, and an
            # interruption mid-demo would briefly break RAG lookups.
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m"]
            - key: karpenter.k8s.aws/instance-cpu
              operator: In
              values: ["2", "4"]
          nodeClassRef:
            name: cpu
            group: karpenter.k8s.aws
            kind: EC2NodeClass
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m
      limits:
        cpu: "8"
        memory: 16Gi
  YAML

  depends_on = [kubectl_manifest.cpu_ec2_node_class]
}
