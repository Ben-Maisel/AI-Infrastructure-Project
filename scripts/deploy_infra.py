"""Build up the main Terraform-managed AWS infrastructure (infra/ and
infra/cluster-addons/) for a demo session, or preview a teardown.
Deliberately never touches infra/bootstrap/ or infra/trust/ -- those
hold the remote-state bucket and CI's own identity, neither of which
should ever be destroyed.

infra/cluster-addons/ (Karpenter's Helm release + CRD objects) reads
infra/'s outputs to configure its providers, so it must always be
applied after infra/ and destroyed before it.

Actually destroying now runs through the "Destroy Infra" GitHub
Actions workflow (workflow_dispatch), not locally -- destroying the
Kubernetes-backed resources here needs to read their live state
first, which needs essentially the same privilege as creating them. A
personal, intentionally read-only identity can't do that; the CI
deploy role already can.

Usage:
    python scripts/deploy_infra.py plan   # preview only, no changes made
    python scripts/deploy_infra.py up     # terraform apply, after confirmation
    python scripts/deploy_infra.py down   # preview only -- actual destroy is CI-only
"""
import argparse
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
INFRA_DIR = REPO_ROOT / "infra"
ADDONS_DIR = INFRA_DIR / "cluster-addons"


def run(cmd, cwd):
    print(f"$ {' '.join(cmd)}  (in {cwd})")
    subprocess.run(cmd, cwd=cwd, check=True)


def confirm(prompt):
    answer = input(f"\n{prompt}\nType 'yes' to continue: ")
    if answer.strip().lower() != "yes":
        print("Aborted -- nothing changed.")
        sys.exit(1)


def init(cwd):
    run(["terraform", "init"], cwd)


def plan():
    for cwd in (INFRA_DIR, ADDONS_DIR):
        init(cwd)
        run(["terraform", "plan"], cwd)


def up():
    for cwd in (INFRA_DIR, ADDONS_DIR):
        init(cwd)
        run(["terraform", "plan"], cwd)
    confirm(
        "This creates real AWS resources that bill continuously while they "
        "exist -- the GPU node alone is ~$0.526/hr. Review the plans above."
    )
    for cwd in (INFRA_DIR, ADDONS_DIR):
        run(["terraform", "apply", "-auto-approve"], cwd)
    print(
        "\nUp. Remember: tear down via the \"Destroy Infra\" GitHub Actions "
        "workflow (workflow_dispatch) when done -- not this script."
    )


def down():
    # Preview in the order an actual destroy runs: cluster-addons/ first.
    for cwd in (ADDONS_DIR, INFRA_DIR):
        init(cwd)
        run(["terraform", "plan", "-destroy"], cwd)
    print(
        "\nThat's a preview only -- actually tearing down runs through the "
        '"Destroy Infra" GitHub Actions workflow now (Actions -> Destroy '
        "Infra -> Run workflow), not this script. See its own preview job "
        "there before approving."
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=["plan", "up", "down"])
    args = parser.parse_args()

    {"plan": plan, "up": up, "down": down}[args.action]()


if __name__ == "__main__":
    main()
