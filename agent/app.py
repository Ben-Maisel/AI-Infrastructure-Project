"""Streamlit chat UI for the agent.

Usage (inside the container, or locally with Ollama running):
    streamlit run agent/app.py
"""
import streamlit as st

from agent.graph import build_graph

st.set_page_config(page_title="K8s Agent", page_icon="☸️")
st.title("Kubernetes Docs Agent")
st.caption(
    "Ask a question about Kubernetes concepts. The agent searches a local "
    "knowledge base and can save summaries to a file on request."
)


@st.cache_resource
def get_agent():
    return build_graph()


agent = get_agent()

if "messages" not in st.session_state:
    st.session_state.messages = []

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

prompt = st.chat_input("Ask about Pods, Deployments, Services...")
if prompt:
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Thinking..."):
            history_len = len(st.session_state.messages)
            result = agent.invoke({"messages": st.session_state.messages})
            new_messages = result["messages"][history_len:]

            tool_calls = [
                call["name"]
                for msg in new_messages
                for call in (getattr(msg, "tool_calls", None) or [])
            ]
            if tool_calls:
                st.caption(f"\U0001f527 used: {', '.join(tool_calls)}")

            answer = new_messages[-1].content
            st.markdown(answer)

    st.session_state.messages.append({"role": "assistant", "content": answer})
