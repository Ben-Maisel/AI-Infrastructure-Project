#!/bin/sh
set -e

: "${OLLAMA_BASE_URL:=http://ollama:11434}"
: "${AGENT_CHAT_MODEL:=llama3.2}"
: "${AGENT_EMBEDDING_MODEL:=nomic-embed-text}"
: "${AGENT_VECTOR_STORE_DIR:=docs/vector_store}"

echo "Waiting for Ollama at $OLLAMA_BASE_URL..."
until curl -sf "$OLLAMA_BASE_URL" > /dev/null; do
  sleep 2
done

pull_model() {
  echo "Ensuring model is pulled: $1"
  curl -sf -X POST "$OLLAMA_BASE_URL/api/pull" -d "{\"name\": \"$1\"}" > /dev/null
}

pull_model "$AGENT_CHAT_MODEL"
pull_model "$AGENT_EMBEDDING_MODEL"

if [ ! -d "$AGENT_VECTOR_STORE_DIR" ] || [ -z "$(ls -A "$AGENT_VECTOR_STORE_DIR" 2>/dev/null)" ]; then
  echo "Vector store not found at $AGENT_VECTOR_STORE_DIR — scraping docs and building it now..."
  python -m agent.scrape
  python -m agent.retrieval
fi

exec streamlit run agent/app.py --server.address=0.0.0.0 --server.port=8501
