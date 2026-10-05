#!/usr/bin/env bash
# JWT on the A2A routes (EKS ServiceAccount tokens) and per-route caller allow-lists.
set -euo pipefail
: "${OIDC_ISSUER:?source scripts/00-env.sh first}"

envsubst < k8s/security-policies.yaml | kubectl apply -f -
kubectl -n agentgateway-system get agentgatewaypolicy \
  -o custom-columns=NAME:.metadata.name,STATUS:.status.ancestors[0].conditions[0].reason
