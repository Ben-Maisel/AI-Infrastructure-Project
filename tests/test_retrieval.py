from unittest.mock import Mock, patch

from langchain_core.documents import Document

from agent import config
from agent.retrieval import build_vector_store, get_retriever


def test_get_retriever_uses_local_persist_dir_by_default(monkeypatch):
    monkeypatch.setattr(config, "CHROMA_HOST", None)
    monkeypatch.setattr(config, "VECTOR_STORE_DIR", "docs/vector_store")

    with patch("agent.retrieval.Chroma") as mock_chroma:
        get_retriever()

    mock_chroma.assert_called_once()
    assert mock_chroma.call_args.kwargs["persist_directory"] == "docs/vector_store"
    assert "host" not in mock_chroma.call_args.kwargs


def test_get_retriever_uses_remote_host_when_configured(monkeypatch):
    monkeypatch.setattr(config, "CHROMA_HOST", "chroma")
    monkeypatch.setattr(config, "CHROMA_PORT", 8000)

    with patch("agent.retrieval.Chroma") as mock_chroma:
        get_retriever()

    mock_chroma.assert_called_once()
    assert mock_chroma.call_args.kwargs["host"] == "chroma"
    assert mock_chroma.call_args.kwargs["port"] == 8000
    assert "persist_directory" not in mock_chroma.call_args.kwargs


def test_build_vector_store_clears_remote_collection_before_rebuilding(monkeypatch):
    monkeypatch.setattr(config, "CHROMA_HOST", "chroma")
    monkeypatch.setattr(config, "CHROMA_PORT", 8000)

    fake_store = Mock()
    with (
        patch("agent.retrieval.load_documents", return_value=[Document(page_content="hello world")]),
        patch("agent.retrieval.Chroma") as mock_chroma,
    ):
        mock_chroma.return_value = fake_store
        mock_chroma.from_documents = Mock()

        build_vector_store()

    fake_store.delete_collection.assert_called_once()
    mock_chroma.from_documents.assert_called_once()
    assert mock_chroma.from_documents.call_args.kwargs["host"] == "chroma"


def test_build_vector_store_tolerates_delete_failing_on_first_run(monkeypatch):
    monkeypatch.setattr(config, "CHROMA_HOST", "chroma")
    monkeypatch.setattr(config, "CHROMA_PORT", 8000)

    fake_store = Mock()
    fake_store.delete_collection.side_effect = Exception("collection does not exist")
    with (
        patch("agent.retrieval.load_documents", return_value=[Document(page_content="hello world")]),
        patch("agent.retrieval.Chroma") as mock_chroma,
    ):
        mock_chroma.return_value = fake_store
        mock_chroma.from_documents = Mock()

        build_vector_store()  # must not raise

    mock_chroma.from_documents.assert_called_once()
