import json
import os
import uuid

import httpx
from google.adk import Agent
from google.adk.models.lite_llm import LiteLlm

from .mcp_tools import get_mcp_tools
from .prompts_loader import build_instruction

os.environ.setdefault("OTEL_SERVICE_NAME", "platformoncall")
from google.adk.telemetry.setup import maybe_set_otel_providers
maybe_set_otel_providers()

GATEWAY_URL = os.environ.get(
    "GATEWAY_URL", "http://agentgateway-proxy.agentgateway-system.svc.cluster.local"
)
SA_TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"


async def call_agent(agent_name: str, task: str) -> str:
    headers = {"content-type": "application/json"}
    try:
        with open(SA_TOKEN_PATH) as f:
            headers["authorization"] = f"Bearer {f.read().strip()}"
    except FileNotFoundError:
        pass  # running outside Kubernetes
    body = {
        "jsonrpc": "2.0",
        "id": str(uuid.uuid4()),
        "method": "message/send",
        "params": {"message": {
            "role": "user", "kind": "message", "messageId": str(uuid.uuid4()),
            "parts": [{"kind": "text", "text": task}],
        }},
    }
    async with httpx.AsyncClient(timeout=300) as client:
        resp = await client.post(f"{GATEWAY_URL}/a2a/ops/{agent_name}/", json=body, headers=headers)
    if resp.status_code != 200:
        return f"Call to {agent_name} failed: HTTP {resp.status_code} {resp.text[:500]}"
    result = resp.json().get("result", {})
    texts = [p.get("text", "") for a in result.get("artifacts", []) for p in a.get("parts", [])
             if p.get("kind") == "text"]
    if not texts:
        msg = (result.get("status") or {}).get("message") or {}
        texts = [p.get("text", "") for p in msg.get("parts", []) if p.get("kind") == "text"]
    return "\n".join(texts) or json.dumps(result)[:20000]


# Set explicitly: the kagent base image strips docstrings, and Bedrock requires
# every tool to have a non-empty description.
call_agent.__doc__ = """Send a task to a specialist agent over A2A through agentgateway and return its answer.

Args:
    agent_name: the agent's exact name in agentregistry, e.g. ekstroubleshooter (lowercase, no hyphens).
    task: what the agent should do, including namespace, workload name and symptoms.
"""


def create_model():
    """Bedrock via agentgateway's OpenAI-compatible route; the gateway holds the AWS identity."""
    return LiteLlm(model="openai/bedrock-claude", api_base=f"{GATEWAY_URL}/v1", api_key="unused")


mcp_tools = get_mcp_tools()
root_agent = Agent(
    model=create_model(),
    name="platformoncall_agent",
    description="Platform on-call agent for Amazon EKS: finds specialists in agentregistry and delegates over A2A",
    instruction=build_instruction("""
You are the platform on-call agent for Amazon EKS clusters.
For every incident or task:
1. Use the agentregistry tools to search the registry for an agent whose description
   matches the task (for example: eks, troubleshooting, pods). Do not guess agent names.
2. Call the best match with call_agent, using its exact registry name (lowercase, no hyphens).
   Pass the namespace, workload name and symptoms in the task.
3. Reply with: which agent you used, the root cause, the evidence, and the proposed fix.
You never change the cluster yourself. If no registered agent fits, say so.
"""),
    tools=[call_agent] + (mcp_tools if mcp_tools else []),
)
