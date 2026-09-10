"""One-time scrape of a handful of Kubernetes concept docs into local
markdown files, used as the RAG knowledge base.

Usage:
    python -m agent.scrape
"""
import os
import re
import time

import requests
from bs4 import BeautifulSoup

from agent import config

SOURCES = {
    "pods": "https://kubernetes.io/docs/concepts/workloads/pods/",
    "deployments": "https://kubernetes.io/docs/concepts/workloads/controllers/deployment/",
    "services": "https://kubernetes.io/docs/concepts/services-networking/service/",
    "configmaps-secrets": "https://kubernetes.io/docs/concepts/configuration/configmap/",
    "ingress": "https://kubernetes.io/docs/concepts/services-networking/ingress/",
    "autoscaling": "https://kubernetes.io/docs/concepts/workloads/autoscaling/",
}

HEADERS = {"User-Agent": "ai-infra-portfolio-project-scraper/1.0"}


def clean_text(html):
    soup = BeautifulSoup(html, "html.parser")
    main = soup.find("main") or soup.body

    for tag in main.select("script, style, nav, footer"):
        tag.decompose()

    text = main.get_text(separator="\n", strip=True)
    return re.sub(r"\n{3,}", "\n\n", text)


def scrape_page(slug, url):
    dest = os.path.join(config.KNOWLEDGE_BASE_DIR, f"{slug}.md")
    if os.path.exists(dest):
        print(f"Skipping {slug} (already scraped)")
        return

    print(f"Scraping {url}")
    response = requests.get(url, headers=HEADERS, timeout=10)
    response.raise_for_status()

    text = clean_text(response.text)
    with open(dest, "w", encoding="utf-8") as f:
        f.write(f"Source: {url}\n\n{text}")


def main():
    os.makedirs(config.KNOWLEDGE_BASE_DIR, exist_ok=True)
    for slug, url in SOURCES.items():
        try:
            scrape_page(slug, url)
        except requests.RequestException as e:
            print(f"Failed to scrape {url}: {e}")
        time.sleep(1)


if __name__ == "__main__":
    main()
