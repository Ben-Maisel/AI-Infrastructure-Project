"""Build up the main Terraform-managed AWS infrastructure (infra/) for a
demo session, or preview a teardown. Deliberately never touches
infra/bootstrap/ or infra/trust/ -- those hold the remote-state bucket
and CI's own identity, neither of which should ever be destroyed.

Actually destroying infra/ now runs through the "Destroy Infra" GitHub
Actions workflow (workflow_dispatch), not locally -- destroying the
Kubernetes-backed resources here (Helm release, Karpenter CRDs) needs
to read their live state first, which needs essentially the same
privilege as creating them. A personal, intentionally read-only
identity can't do that; the CI deploy role already can.

Usage:
    python scripts/deploy_infra.py plan   # preview only, no changes made
    python scripts/deploy_infra.py up     # terraform apply, after confirmation
    python scripts/deploy_infra.py down   # preview only -- actual destroy is CI-only
"""
import argparse
import subprocess
import sys
from pathlib import Path

INFRA_DIR = Path(__file__).resolve().parent.parent / "infra"


def run(cmd):
    print(f"$ {' '.join(cmd)}  (in {INFRA_DIR})")
    subprocess.run(cmd, cwd=INFRA_DIR, check=True)


def confirm(prompt):
    answer = input(f"\n{prompt}\nType 'yes' to continue: ")
    if answer.strip().lower() != "yes":
        print("Aborted -- nothing changed.")
        sys.exit(1)


def init():
    run(["terraform", "init"])


def plan():
    init()
    run(["terraform", "plan"])


def up():
    init()
    run(["terraform", "plan"])
    confirm(
        "This creates real AWS resources that bill continuously while they "
        "exist -- the GPU node alone is ~$0.526/hr. Review the plan above."
    )
    run(["terraform", "apply", "-auto-approve"])
    print(
        "\nUp. Remember: tear down via the \"Destroy Infra\" GitHub Actions "
        "workflow (workflow_dispatch) when done -- not this script."
    )


def down():
    init()
    run(["terraform", "plan", "-destroy"])
    print(
        "\nThat's a preview only -- actually tearing down runs through the "
        '"Destroy Infra" GitHub Actions workflow now (Actions -> Destroy '
        "Infra -> Run workflow), not this script. See its own preview job "
        "there before approving."
    )
    print("\nDown. Nothing in infra/ should be billing anymore.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=["plan", "up", "down"])
    args = parser.parse_args()

    {"plan": plan, "up": up, "down": down}[args.action]()


if __name__ == "__main__":
    main()
