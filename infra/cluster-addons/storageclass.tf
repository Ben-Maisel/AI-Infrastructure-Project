# Explicit StorageClass rather than relying on whatever default the
# EBS CSI addon may or may not auto-create (undocumented consistently
# across EKS versions) -- Chroma's PVC (next) references this by name.

resource "kubectl_manifest" "gp3_storageclass" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: gp3
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
    provisioner: ebs.csi.aws.com
    # Delays actually creating the EBS volume until a pod using it is
    # scheduled to a specific node -- so the volume lands in the same
    # AZ as that node. EBS volumes are AZ-locked; without this, the
    # volume could get created in an AZ that doesn't match wherever
    # the pod actually ends up.
    volumeBindingMode: WaitForFirstConsumer
    # Delete the real EBS volume when its PVC is deleted -- same
    # cost-hygiene reasoning as deleteOnTermination on node root disks.
    reclaimPolicy: Delete
    parameters:
      type: gp3
  YAML
}
