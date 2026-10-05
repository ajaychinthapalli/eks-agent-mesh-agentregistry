#!/usr/bin/env bash
# Internal-NLB Gateway, Pod Identity for Bedrock, Bedrock route, kagent ModelConfig.
set -euo pipefail
: "${CLUSTER:?source scripts/00-env.sh first}"

kubectl apply -f k8s/gateway.yaml
kubectl -n agentgateway-system wait gateway/agentgateway-proxy --for=condition=Programmed --timeout=5m

aws iam create-policy --policy-name AgentgatewayBedrockInvoke \
  --policy-document file://infra/bedrock-invoke.json || echo "policy exists, continuing"
eksctl create podidentityassociation --cluster "$CLUSTER" --region "$AWS_REGION" \
  --namespace agentgateway-system --service-account-name agentgateway-proxy \
  --role-name "AgentgatewayBedrockRole-$CLUSTER" \
  --permission-policy-arns "arn:aws:iam::$ACCOUNT_ID:policy/AgentgatewayBedrockInvoke"

# Restart so the new pod gets the Pod Identity credentials (the first pod predates the association)
kubectl -n agentgateway-system rollout restart deploy/agentgateway-proxy
kubectl -n agentgateway-system rollout status deploy/agentgateway-proxy
POD=$(kubectl -n agentgateway-system get pods -o name | grep agentgateway-proxy | head -1)
kubectl -n agentgateway-system get "$POD" \
  -o jsonpath='{range .spec.containers[*].env[*]}{.name}{"\n"}{end}' | grep AWS_CONTAINER_CREDENTIALS_FULL_URI \
  || { echo "Pod Identity env missing; restart the proxy again"; exit 1; }

envsubst < k8s/bedrock.yaml | kubectl apply -f -
envsubst < k8s/modelconfig.yaml | kubectl apply -f -

# Test the Bedrock route from inside the cluster
kubectl run gwtest --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s "$GW/v1/chat/completions" -H content-type:application/json \
  -d '{"model":"","messages":[{"role":"user","content":"Reply with the word ready."}]}'
echo
kubectl -n kagent get modelconfig bedrock-via-agentgateway
