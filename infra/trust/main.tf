# CI's own identity: the OIDC provider it authenticates through and the
# IAM roles it assumes. Deliberately separate from infra/ and never
# touched by scripts/deploy_infra.py -- CI can't recreate its own
# credentials if they're gone, so this can't share a teardown cycle
# with the demo infra. Applied locally only, same as infra/bootstrap/.

locals {
  cluster_name = "ai-infra-project"
}
