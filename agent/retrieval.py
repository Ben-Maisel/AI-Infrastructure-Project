"""Builds the local Chroma vector store from the scraped knowledge base,
and exposes a retriever for the agent to query it.

Usage:
    python -m agent.retrieval
"""
import glob
import os
import shutil

from langchain_chroma import Chroma
from langchain_core.documents import Document
from langchain_ollama import OllamaEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter

from agent import config


def _embeddings():
    return OllamaEmbeddings(model=config.EMBEDDING_MODEL, base_url=config.OLLAMA_BASE_URL)


def _remote_store():
    return Chroma(host=config.CHROMA_HOST, port=config.CHROMA_PORT, embedding_function=_embeddings())


def load_documents():
    paths = glob.glob(os.path.join(config.KNOWLEDGE_BASE_DIR, "*.md"))
    documents = []
    for path in paths:
        with open(path, "r", encoding="utf-8") as f:
            documents.append(Document(page_content=f.read(), metadata={"source": path}))
    return documents


def build_vector_store():
    documents = load_documents()
    if not documents:
        raise RuntimeError(
            f"No documents found in {config.KNOWLEDGE_BASE_DIR}. "
            "Run 'python -m agent.scrape' first."
        )

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=config.CHUNK_SIZE, chunk_overlap=config.CHUNK_OVERLAP
    )
    chunks = splitter.split_documents(documents)

    if config.CHROMA_HOST:
        # Clear any existing collection so reruns don't duplicate data.
        # Errors harmlessly on a fresh Chroma with nothing to delete yet --
        # a real connection problem surfaces immediately on the next call anyway.
        try:
            _remote_store().delete_collection()
        except Exception as e:  # noqa: BLE001 -- best-effort, see comment above
            print(f"No existing collection to clear ({e}); continuing.")

        print(f"Embedding {len(chunks)} chunks from {len(documents)} documents...")
        Chroma.from_documents(
            chunks,
            embedding=_embeddings(),
            host=config.CHROMA_HOST,
            port=config.CHROMA_PORT,
        )
        print(f"Vector store built at {config.CHROMA_HOST}:{config.CHROMA_PORT}")
        return

    if os.path.exists(config.VECTOR_STORE_DIR):
        # Clear contents rather than removing the directory itself: when this
        # path is a Docker bind mount, rmtree-ing the mount point fails with
        # "device or resource busy".
        for entry in os.listdir(config.VECTOR_STORE_DIR):
            entry_path = os.path.join(config.VECTOR_STORE_DIR, entry)
            if os.path.isdir(entry_path):
                shutil.rmtree(entry_path)
            else:
                os.remove(entry_path)

    print(f"Embedding {len(chunks)} chunks from {len(documents)} documents...")
    Chroma.from_documents(
        chunks,
        embedding=_embeddings(),
        persist_directory=config.VECTOR_STORE_DIR,
    )
    print(f"Vector store built at {config.VECTOR_STORE_DIR}")


def get_retriever(k=4):
    if config.CHROMA_HOST:
        store = _remote_store()
    else:
        store = Chroma(
            persist_directory=config.VECTOR_STORE_DIR,
            embedding_function=_embeddings(),
        )
    return store.as_retriever(search_kwargs={"k": k})


if __name__ == "__main__":
    build_vector_store()
