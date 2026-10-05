#!/usr/bin/env bash
# Broken demo workload, the EKS Troubleshooter agent, the A2A backend and Troubleshooter route, and its registry record.
# Needs the agentregistry port-forward on localhost:12121.
set -euo pipefail
: "${CLUSTER:?source scripts/00-env.sh first}"

kubectl apply -f k8s/demo-checkout.yaml
kubectl apply -f k8s/eks-troubleshooter.yaml
kubectl -n kagent wait agent/eks-troubleshooter --for=condition=Ready --timeout=3m

# Applies the kagent A2A backend and both routes (the On-call route resolves once that agent exists)
kubectl apply -f k8s/a2a-routes.yaml

arctl apply -f registry/ekstroubleshooter.yaml
arctl get agents

cat <<'EOF'

Test through the gateway (port-forward first: kubectl -n agentgateway-system port-forward svc/agentgateway-proxy 8080:80):
  curl -s localhost:8080/a2a/ops/ekstroubleshooter/.well-known/agent-card.json | jq '{name, skills: [.skills[].id]}'
EOF
