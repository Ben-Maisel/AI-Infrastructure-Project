"""LangGraph agent: binds the chat model to the RAG retrieval tool and
the file-write tool, and wires up the reasoning loop.

Usage:
    python -m agent.graph "your question here"
"""
import sys

from langchain_core.tools import tool
from langchain_ollama import ChatOllama
from langgraph.graph import START, MessagesState, StateGraph
from langgraph.prebuilt import ToolNode, tools_condition

from agent import config
from agent.retrieval import get_retriever
from agent.tools import write_file


@tool
def search_knowledge_base(query: str) -> str:
    """Search the Kubernetes documentation knowledge base for relevant
    information. Use this before answering questions about Kubernetes
    concepts like Pods, Deployments, Services, ConfigMaps, Ingress, or
    autoscaling.
    """
    retriever = get_retriever()
    docs = retriever.invoke(query)
    if not docs:
        return "No relevant documents found."
    return "\n\n---\n\n".join(d.page_content for d in docs)


TOOLS = [search_knowledge_base, write_file]

SYSTEM_PROMPT = (
    "You are an infrastructure assistant that answers questions about "
    "Kubernetes using the search_knowledge_base tool, and can save "
    "results to a file with the write_file tool when asked. Always "
    "search the knowledge base before answering a Kubernetes question "
    "rather than relying on prior knowledge.\n\n"
    "Tool argument names are exact and case-sensitive:\n"
    "- search_knowledge_base(query: str)\n"
    "- write_file(filename: str, content: str)\n"
    "Never invent different argument names, and never write out a tool "
    "call as plain text in your reply — always use the actual tool-calling "
    "mechanism.\n\n"
    "When saving to a file, write a concise summary in your own words — "
    "never copy retrieved text verbatim into the content argument."
)


def _tool_error_message(error: Exception) -> str:
    return (
        f"Tool call failed: {error}. write_file takes exactly two string "
        "arguments named 'filename' and 'content' (no others) — retry the "
        "call using those exact argument names."
    )


def build_graph():
    model = ChatOllama(
        model=config.CHAT_MODEL, base_url=config.OLLAMA_BASE_URL, temperature=0, num_predict=4096
    )
    model_with_tools = model.bind_tools(TOOLS)

    def call_model(state: MessagesState):
        messages = [{"role": "system", "content": SYSTEM_PROMPT}] + state["messages"]
        response = model_with_tools.invoke(messages)
        return {"messages": [response]}

    graph = StateGraph(MessagesState)
    graph.add_node("agent", call_model)
    graph.add_node("tools", ToolNode(TOOLS, handle_tool_errors=_tool_error_message))

    graph.add_edge(START, "agent")
    graph.add_conditional_edges("agent", tools_condition)
    graph.add_edge("tools", "agent")

    return graph.compile()


def run(question: str) -> str:
    app = build_graph()
    result = app.invoke({"messages": [{"role": "user", "content": question}]})
    return result["messages"][-1].content


if __name__ == "__main__":
    query = " ".join(sys.argv[1:]) or "What is a Kubernetes Deployment?"
    print(run(query))
