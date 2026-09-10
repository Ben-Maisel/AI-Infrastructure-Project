"""Tools the agent can call. Currently: writing a result to a local file
— the "real action" beyond text generation.
"""
import os

from langchain_core.tools import tool

from agent import config


@tool
def write_file(filename: str, content: str) -> str:
    """Save content to a file in the agent's output directory.

    Use this when asked to save, write, or export something to a file.
    filename should be a simple name like "summary.md" — no directories.
    """
    os.makedirs(config.TOOL_OUTPUT_DIR, exist_ok=True)

    safe_name = os.path.basename(filename)
    if not safe_name or safe_name in (".", ".."):
        return f"Refused: '{filename}' is not a valid filename."

    output_root = os.path.abspath(config.TOOL_OUTPUT_DIR)
    dest = os.path.abspath(os.path.join(output_root, safe_name))

    if os.path.commonpath([dest, output_root]) != output_root:
        return f"Refused: '{filename}' resolves outside the allowed output directory."

    with open(dest, "w", encoding="utf-8") as f:
        f.write(content)

    return f"Saved to {dest}"


TOOLS = [write_file]
