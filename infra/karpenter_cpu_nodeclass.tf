# Infrastructure shape for CPU nodes Karpenter provisions (app, Chroma).
# A separate GPU EC2NodeClass comes later for Ollama.

resource "kubectl_manifest" "cpu_ec2_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: cpu
    spec:
      role: ${module.karpenter.node_iam_role_name}
      amiSelectorTerms:
        - alias: al2023@latest
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      # Reserves a slice of node resources for the OS/kubelet itself so
      # workloads can't starve them out.
      kubelet:
        systemReserved:
          cpu: 100m
          memory: 100Mi
      # Karpenter-created nodes never pass through Terraform, so
      # default_tags in providers.tf never reaches them -- set explicitly.
      tags:
        Project: "ai-infra-project"
        ManagedBy: "karpenter"
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [helm_release.karpenter]
}
