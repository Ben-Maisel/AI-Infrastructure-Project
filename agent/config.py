import os

# Ollama server (local, free — no API key required)
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")

# Chat model: does the reasoning + tool calling
CHAT_MODEL = os.getenv("AGENT_CHAT_MODEL", "llama3.1:8b")

# Embedding model: turns text into vectors for retrieval
EMBEDDING_MODEL = os.getenv("AGENT_EMBEDDING_MODEL", "nomic-embed-text")

# RAG document pipeline
KNOWLEDGE_BASE_DIR = os.getenv("AGENT_KNOWLEDGE_BASE_DIR", "docs/knowledge_base")
VECTOR_STORE_DIR = os.getenv("AGENT_VECTOR_STORE_DIR", "docs/vector_store")
CHUNK_SIZE = int(os.getenv("AGENT_CHUNK_SIZE", "1000"))
CHUNK_OVERLAP = int(os.getenv("AGENT_CHUNK_OVERLAP", "200"))

# File-write tool: where the agent is allowed to save output
TOOL_OUTPUT_DIR = os.getenv("AGENT_TOOL_OUTPUT_DIR", "agent_output")
