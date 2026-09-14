# GPU NodePool for Ollama. Pinned to the specific g4dn.xlarge already
# decided on (not a broad instance-family range like the CPU pools),
# on-demand only (a spot interruption mid-demo would be worse here
# than anywhere else in the stack), and tainted so only a pod that
# explicitly tolerates it can land here -- otherwise an ordinary
# CPU-only pod could get scheduled onto this expensive node by accident.

resource "kubectl_manifest" "gpu_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: gpu
    spec:
      template:
        metadata:
          labels:
            workload-tier: ollama
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: node.kubernetes.io/instance-type
              operator: In
              values: ["g4dn.xlarge"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
          nodeClassRef:
            name: gpu
            group: karpenter.k8s.aws
            kind: EC2NodeClass
          taints:
            - key: nvidia.com/gpu
              effect: NoSchedule
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m
      # Hard cap of 1 GPU node ever -- the real cost risk this whole
      # project has flagged repeatedly is an idle GPU node left running.
      limits:
        nvidia.com/gpu: 1
  YAML

  depends_on = [kubectl_manifest.gpu_ec2_node_class]
}
