#!/bin/sh
set -e

: "${OLLAMA_BASE_URL:=http://ollama:11434}"

# Model-pulling and knowledge-base population both live in the
# populate-knowledge-base Job now (infra/cluster-addons/), run once
# deliberately rather than on every app pod start/restart -- this used
# to also build the vector store here, but that was keyed off whether
# a local directory existed, which doesn't mean anything once Chroma
# is a separate networked pod: every restart would find it "missing"
# and destructively rebuild the shared collection out from under any
# other pod querying it.
echo "Waiting for Ollama at $OLLAMA_BASE_URL..."
until curl -sf "$OLLAMA_BASE_URL" > /dev/null; do
  sleep 2
done

exec streamlit run agent/app.py --server.address=0.0.0.0 --server.port=8501
