"""Build up or tear down the main Terraform-managed AWS infrastructure
(infra/) for a demo session. Deliberately never touches infra/bootstrap/
-- that holds the remote-state bucket everything else's state lives in,
and should essentially never be destroyed.

Usage:
    python scripts/deploy_infra.py plan   # preview only, no changes made
    python scripts/deploy_infra.py up     # terraform apply, after confirmation
    python scripts/deploy_infra.py down   # terraform destroy, after confirmation
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
    print("\nUp. Remember: tear down with `python scripts/deploy_infra.py down` when done.")


def down():
    init()
    run(["terraform", "plan", "-destroy"])
    confirm(
        "This DESTROYS everything shown above. Make sure the demo/session "
        "is actually finished first."
    )
    run(["terraform", "destroy", "-auto-approve"])
    print("\nDown. Nothing in infra/ should be billing anymore.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=["plan", "up", "down"])
    args = parser.parse_args()

    {"plan": plan, "up": up, "down": down}[args.action]()


if __name__ == "__main__":
    main()
