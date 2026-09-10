"""One-command setup: builds and starts the full stack (Ollama +
the agent's Streamlit UI) with Docker Compose. Model pulling and
knowledge-base ingestion happen automatically on container startup.

Usage:
    python scripts/setup.py
"""
import shutil
import subprocess
import sys


def run(cmd):
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, check=True)


def main():
    if shutil.which("docker") is None:
        sys.exit(
            "Docker not found. Install Docker Desktop from "
            "https://www.docker.com/products/docker-desktop, then re-run this script."
        )

    run(["docker", "compose", "up", "--build"])
    print("\nOnce containers are up, open http://localhost:8501 to chat with the agent.")


if __name__ == "__main__":
    main()
