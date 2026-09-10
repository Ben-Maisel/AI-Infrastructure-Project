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
