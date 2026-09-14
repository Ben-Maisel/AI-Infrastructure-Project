# Without this, Kubernetes has no concept of nvidia.com/gpu as a
# schedulable resource at all, even on a node with a real physical
# GPU -- Ollama's pod could request one forever and stay Pending.
# Runs as a DaemonSet: one copy per matching (GPU) node.

resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  namespace  = "kube-system"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.17.1"

  values = [
    yamlencode({
      # Only attempt this on nodes the GPU NodePool actually creates --
      # no point trying (and failing) on every CPU node too. The
      # chart's default DaemonSet template already tolerates the
      # nvidia.com/gpu:NoSchedule taint, so no toleration override
      # needed here.
      nodeSelector = {
        workload-tier = "ollama"
      }
    })
  ]
}
