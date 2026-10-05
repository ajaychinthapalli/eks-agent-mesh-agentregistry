#!/usr/bin/env bash
# AWS Load Balancer Controller, Gateway API CRDs, agentgateway and kagent (upstream Helm charts).
set -euo pipefail
: "${CLUSTER:?source scripts/00-env.sh first}"

# AWS Load Balancer Controller (skip if already installed)
if ! kubectl -n kube-system get deploy aws-load-balancer-controller >/dev/null 2>&1; then
  curl -fsSo /tmp/alb-iam-policy.json \
    https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file:///tmp/alb-iam-policy.json || echo "policy exists, continuing"
  eksctl create podidentityassociation --cluster "$CLUSTER" --region "$AWS_REGION" \
    --namespace kube-system --service-account-name aws-load-balancer-controller \
    --role-name "AmazonEKSLoadBalancerControllerRole-$CLUSTER" \
    --permission-policy-arns "arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy"
  helm repo add eks https://aws.github.io/eks-charts >/dev/null && helm repo update eks
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
    --set clusterName="$CLUSTER" --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region="$AWS_REGION" --set vpcId="$VPC_ID"
  kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
fi

# Gateway API CRDs (v1.5.0+ required; skip if present)
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 || \
  kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.0/standard-install.yaml

# agentgateway
helm upgrade -i --create-namespace -n agentgateway-system --version v1.6.0 \
  agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds
helm upgrade -i -n agentgateway-system --version v1.6.0 \
  agentgateway oci://cr.agentgateway.dev/charts/agentgateway

# kagent (the provider key is a placeholder; models go through agentgateway)
helm upgrade -i kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds -n kagent --create-namespace
helm upgrade -i kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent -n kagent \
  --set providers.default=openAI --set providers.openAI.apiKey=placeholder-not-used
kubectl -n kagent rollout status deploy --timeout=5m
kubectl -n kagent delete agents --all   # demo agents

# Clusters with the CloudWatch Observability add-on: keep its auto-instrumentation out of the agent namespaces.
# Merge into any existing add-on configuration first.
if aws eks describe-addon --cluster-name "$CLUSTER" --region "$AWS_REGION" \
     --addon-name amazon-cloudwatch-observability >/dev/null 2>&1; then
  echo "CloudWatch Observability add-on found. Current configuration:"
  aws eks describe-addon --cluster-name "$CLUSTER" --region "$AWS_REGION" \
    --addon-name amazon-cloudwatch-observability --query addon.configurationValues --output text
  echo "If empty, apply: aws eks update-addon --cluster-name $CLUSTER --addon-name amazon-cloudwatch-observability --configuration-values file://infra/cw-addon-config.json"
fi

kubectl get gatewayclass agentgateway
kubectl -n kagent get remotemcpservers
