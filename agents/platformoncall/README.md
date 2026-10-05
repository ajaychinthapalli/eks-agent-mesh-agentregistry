# Platform On-call Agent

A Google ADK agent that runs on kagent's ADK base image. It finds specialists in agentregistry (over MCP) and calls them over A2A through agentgateway.

This folder holds only the files changed from arctl's scaffold. To build:

```bash
# 1. Scaffold (writes Dockerfile, pyproject.toml, mcp_tools.py and more)
arctl init agent platformoncall --framework adk --language python \
  --description "Platform on-call agent for Amazon EKS: finds specialists in agentregistry and delegates over A2A" \
  --model-provider openai --model-name bedrock-claude

# 2. Copy this folder's files over the scaffold
cp agents/platformoncall/platformoncall/agent.py        platformoncall/platformoncall/agent.py
cp agents/platformoncall/platformoncall/agent-card.json platformoncall/platformoncall/agent-card.json
envsubst < agents/platformoncall/agent.yaml > platformoncall/agent.yaml

# 3. Build for x86 nodes and push (from an arm64 Mac, arctl build cannot cross-build)
cd platformoncall
docker buildx build --platform linux/amd64 --tag $IMAGE --push .

# 4. Publish the record
arctl apply -f agent.yaml
```

Notes:

- **Registry tools need no code.** The generated `mcp_tools.py` reads `MCP_SERVERS_CONFIG`, which the registry Deployment sets. Its tools appear with an `agentregistry_` prefix; all of them are read-only (`get_*`, `list_*`).
- **The model goes through agentgateway.** LiteLLM's OpenAI provider points at `$GATEWAY_URL/v1`; the gateway holds the AWS identity and translates to Bedrock.
- **`call_agent.__doc__` is set explicitly.** kagent's base image drops docstrings, and Bedrock rejects tools with an empty description.
- **Authentication:** `call_agent` sends the pod's ServiceAccount token, which agentgateway verifies against the EKS OIDC issuer.
