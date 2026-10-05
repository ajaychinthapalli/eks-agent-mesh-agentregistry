# Copy to scripts/00-env.sh, fill in, then: source scripts/00-env.sh
export AWS_REGION=us-east-2
export CLUSTER=my-eks-cluster
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Network (from: aws eks describe-cluster --name $CLUSTER)
export VPC_ID=$(aws eks describe-cluster --name $CLUSTER --region $AWS_REGION --query cluster.resourcesVpcConfig.vpcId --output text)
export CLUSTER_SG=$(aws eks describe-cluster --name $CLUSTER --region $AWS_REGION --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text)
# Security group of any existing self-managed nodes that must reach RDS (leave empty if none)
export NODE_SG=

# Bedrock model (an inference profile your account can use in this region)
export BEDROCK_MODEL=us.anthropic.claude-sonnet-4-5-20250929-v1:0

# In-cluster addresses
export GW=http://agentgateway-proxy.agentgateway-system.svc.cluster.local
export REGISTRY_MCP_URL=http://agentregistry.agentregistry.svc.cluster.local:31313/mcp

# EKS OIDC issuer (used by the JWT policy)
export OIDC_ISSUER=$(aws eks describe-cluster --name $CLUSTER --region $AWS_REGION --query cluster.identity.oidc.issuer --output text)
export OIDC_ID=${OIDC_ISSUER##*/}

# On-call image
export ONCALL_VERSION=0.1.1
export IMAGE=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/agents/platformoncall:$ONCALL_VERSION
