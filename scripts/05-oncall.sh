#!/usr/bin/env bash
# Scaffold, build, publish and deploy the Platform On-call Agent through agentregistry.
# Needs the agentregistry port-forward on localhost:12121 and Docker with buildx.
set -euo pipefail
: "${CLUSTER:?source scripts/00-env.sh first}"
REPO_ROOT=$(pwd)
WORK=${WORK:-$HOME/agent-mesh}
mkdir -p "$WORK"

if [ ! -d "$WORK/platformoncall" ]; then
  ( cd "$WORK" && arctl init agent platformoncall --framework adk --language python \
      --description "Platform on-call agent for Amazon EKS: finds specialists in agentregistry and delegates over A2A" \
      --model-provider openai --model-name bedrock-claude )
fi
cp "$REPO_ROOT/agents/platformoncall/platformoncall/agent.py"        "$WORK/platformoncall/platformoncall/agent.py"
cp "$REPO_ROOT/agents/platformoncall/platformoncall/agent-card.json" "$WORK/platformoncall/platformoncall/agent-card.json"
envsubst < "$REPO_ROOT/agents/platformoncall/agent.yaml" > "$WORK/platformoncall/agent.yaml"

aws ecr describe-repositories --region "$AWS_REGION" --repository-names agents/platformoncall >/dev/null 2>&1 || \
  aws ecr create-repository --region "$AWS_REGION" --repository-name agents/platformoncall \
    --image-scanning-configuration scanOnPush=true
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${IMAGE%%/*}"
( cd "$WORK/platformoncall" && docker buildx build --platform linux/amd64 --tag "$IMAGE" --push . )

( cd "$WORK/platformoncall" && arctl apply -f agent.yaml )
envsubst < "$REPO_ROOT/registry/platformoncall-deployment.yaml" | arctl apply -f -

kubectl -n kagent wait agent/platformoncall-latest-platformoncall --for=condition=Ready --timeout=5m
P=$(kubectl -n kagent get pods -o name | grep -i platformoncall | head -1)
kubectl -n kagent get "$P" -o jsonpath='image={.spec.containers[0].image} init={.spec.initContainers[*].name}{"\n"}'
echo "If init lists opentelemetry-auto-instrumentation-*, exclude the namespace (infra/cw-addon-config.json) and restart."
arctl get deployments
