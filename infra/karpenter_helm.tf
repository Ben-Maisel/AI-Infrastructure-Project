# Installs Karpenter's controller, its ServiceAccount (IRSA-annotated),
# RBAC, and the NodePool/EC2NodeClass CRDs. No NodePool exists yet, so
# it won't provision any nodes until the next file.

resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = "kube-system"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.14.1" # LTS

  values = [
    yamlencode({
      # Default is 2, which needs pod anti-affinity to satisfy (no two
      # replicas on the same node) -- not worth a permanent second
      # system-group node just for HA on a demo/portfolio controller.
      replicas = 1
      settings = {
        clusterName       = module.eks.cluster_name
        interruptionQueue = module.karpenter.queue_name
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter.iam_role_arn
        }
      }
    })
  ]
}
