#!/usr/bin/env bash
# Removes what the pilot added. Keeps the cluster, the Gateway API CRDs, the default StorageClass,
# and the AWS Load Balancer Controller (remove that yourself if the pilot installed it).
set -uo pipefail
: "${CLUSTER:?source scripts/00-env.sh first}"

kubectl delete namespace shop ops-callers --ignore-not-found
kubectl -n kagent delete agents --all --ignore-not-found

# Delete routes and the Gateway first so the NLB is removed
kubectl -n agentgateway-system delete httproute --all --ignore-not-found
kubectl -n agentgateway-system delete gateway agentgateway-proxy --ignore-not-found
sleep 30

helm uninstall agentregistry -n agentregistry
helm uninstall kagent kagent-crds -n kagent
helm uninstall agentgateway agentgateway-crds -n agentgateway-system
kubectl delete namespace agentregistry kagent agentgateway-system --ignore-not-found

eksctl delete podidentityassociation --cluster "$CLUSTER" --region "$AWS_REGION" \
  --namespace agentgateway-system --service-account-name agentgateway-proxy

aws rds delete-db-instance --region "$AWS_REGION" --db-instance-identifier agentregistry --skip-final-snapshot
aws rds wait db-instance-deleted --region "$AWS_REGION" --db-instance-identifier agentregistry
aws rds delete-db-subnet-group --region "$AWS_REGION" --db-subnet-group-name agentregistry
RDS_SG=$(aws ec2 describe-security-groups --region "$AWS_REGION" \
  --filters "Name=group-name,Values=agentregistry-rds" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text)
[ "$RDS_SG" != "None" ] && aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$RDS_SG"

aws ecr delete-repository --region "$AWS_REGION" --repository-name agents/platformoncall --force
aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/AgentgatewayBedrockInvoke"

echo "Optional: delete the agents node group with: eksctl delete nodegroup -f infra/agents-nodegroup.yaml --approve"
