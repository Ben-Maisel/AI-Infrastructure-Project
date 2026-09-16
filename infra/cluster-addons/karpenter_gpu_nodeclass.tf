# Infrastructure shape for the GPU node Ollama runs on. NVIDIA drivers
# ship baked into this AMI; the device plugin DaemonSet (next file)
# is still needed for Kubernetes to see the GPU as a schedulable
# resource at all.

resource "kubectl_manifest" "gpu_ec2_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: gpu
    spec:
      role: ${data.terraform_remote_state.infra.outputs.karpenter_node_iam_role_name}
      amiFamily: AL2023
      amiSelectorTerms:
        # Pinned to the cluster's own Kubernetes version -- an
        # unqualified wildcard can match an AMI built for a different,
        # incompatible k8s version (a real, reported Karpenter issue).
        # Real naming convention verified directly against the actual
        # AMIs in this account/region (an earlier guess here --
        # "amazon-eks-node-1.31-nvidia-*" -- matched zero real AMIs and
        # silently made Karpenter exclude this NodePool from scheduling
        # entirely, with no error, just no node ever getting built).
        - name: "amazon-eks-node-al2023-x86_64-nvidia-*-1.31-*"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${data.terraform_remote_state.infra.outputs.eks_cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${data.terraform_remote_state.infra.outputs.eks_cluster_name}
      kubelet:
        systemReserved:
          cpu: 100m
          memory: 100Mi
      # NVIDIA drivers + Ollama's model images want real room -- the
      # default root volume is too small for this.
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 100Gi
            volumeType: gp3
            deleteOnTermination: true
      tags:
        Project: "ai-infra-project"
        ManagedBy: "karpenter"
        karpenter.sh/discovery: ${data.terraform_remote_state.infra.outputs.eks_cluster_name}
  YAML

  depends_on = [helm_release.karpenter]
}
