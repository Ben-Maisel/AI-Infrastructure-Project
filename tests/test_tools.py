from unittest.mock import Mock

from agent import config
from agent.tools import write_file


def test_write_file_saves_content(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "TOOL_OUTPUT_DIR", str(tmp_path))

    result = write_file.invoke({"filename": "note.txt", "content": "hello"})

    saved = tmp_path / "note.txt"
    assert saved.exists()
    assert saved.read_text(encoding="utf-8") == "hello"
    assert "Saved to" in result


def test_write_file_neutralizes_path_traversal(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "TOOL_OUTPUT_DIR", str(tmp_path))

    write_file.invoke({"filename": "../../evil.txt", "content": "pwned"})

    assert (tmp_path / "evil.txt").exists()
    assert not (tmp_path.parent.parent / "evil.txt").exists()


def test_write_file_refuses_dotdot_filename(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "TOOL_OUTPUT_DIR", str(tmp_path))

    result = write_file.invoke({"filename": "..", "content": "x"})

    assert "Refused" in result
    assert list(tmp_path.iterdir()) == []


def test_write_file_refuses_empty_filename(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "TOOL_OUTPUT_DIR", str(tmp_path))

    result = write_file.invoke({"filename": "", "content": "x"})

    assert "Refused" in result
    assert list(tmp_path.iterdir()) == []


def test_write_file_uses_s3_when_bucket_configured(monkeypatch):
    monkeypatch.setattr(config, "TOOL_OUTPUT_S3_BUCKET", "my-bucket")
    s3_client = Mock()
    monkeypatch.setattr("agent.tools.boto3.client", Mock(return_value=s3_client))

    result = write_file.invoke({"filename": "note.txt", "content": "hello"})

    s3_client.put_object.assert_called_once_with(
        Bucket="my-bucket", Key="note.txt", Body=b"hello"
    )
    assert result == "Saved to s3://my-bucket/note.txt"


def test_write_file_refuses_dotdot_filename_before_touching_s3(monkeypatch):
    monkeypatch.setattr(config, "TOOL_OUTPUT_S3_BUCKET", "my-bucket")
    s3_client = Mock()
    monkeypatch.setattr("agent.tools.boto3.client", Mock(return_value=s3_client))

    result = write_file.invoke({"filename": "..", "content": "x"})

    assert "Refused" in result
    s3_client.put_object.assert_not_called()
