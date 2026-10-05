#!/usr/bin/env bash
# Amazon RDS for PostgreSQL + agentregistry (Helm), then arctl.
set -euo pipefail
: "${CLUSTER:?source scripts/00-env.sh first}"

SUBNETS=$(aws ec2 describe-subnets --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:kubernetes.io/role/internal-elb,Values=1" \
  --query 'Subnets[].SubnetId' --output text)
[ -n "$SUBNETS" ] || { echo "No subnets tagged kubernetes.io/role/internal-elb=1"; exit 1; }

aws rds create-db-subnet-group --region "$AWS_REGION" --db-subnet-group-name agentregistry \
  --db-subnet-group-description agentregistry --subnet-ids $SUBNETS
RDS_SG=$(aws ec2 create-security-group --region "$AWS_REGION" --group-name agentregistry-rds \
  --description "agentregistry RDS" --vpc-id "$VPC_ID" --query GroupId --output text)
echo "RDS_SG=$RDS_SG   # keep for cleanup"
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$RDS_SG" \
  --protocol tcp --port 5432 --source-group "$CLUSTER_SG"
if [ -n "${NODE_SG:-}" ]; then
  aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$RDS_SG" \
    --protocol tcp --port 5432 --source-group "$NODE_SG"
fi

aws rds create-db-instance --region "$AWS_REGION" --db-instance-identifier agentregistry \
  --engine postgres --db-instance-class db.t4g.medium --allocated-storage 20 \
  --db-name agentregistry --master-username agentregistry --manage-master-user-password \
  --db-subnet-group-name agentregistry --vpc-security-group-ids "$RDS_SG" \
  --no-publicly-accessible --storage-encrypted --backup-retention-period 7
aws rds wait db-instance-available --region "$AWS_REGION" --db-instance-identifier agentregistry

DB_HOST=$(aws rds describe-db-instances --region "$AWS_REGION" --db-instance-identifier agentregistry \
  --query 'DBInstances[0].Endpoint.Address' --output text)
DB_SECRET_ARN=$(aws rds describe-db-instances --region "$AWS_REGION" --db-instance-identifier agentregistry \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
DB_PASSWORD=$(aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$DB_SECRET_ARN" \
  --query SecretString --output text | jq -r .password)
DB_PASS_ENC=$(jq -rn --arg p "$DB_PASSWORD" '$p|@uri')

# Chart 0.4.0 takes a full connection string; pass it in a values file, never on the command line
( umask 077; cat > agentregistry-values.yaml <<EOF
database:
  postgres:
    type: external
    external:
      url: "postgres://agentregistry:${DB_PASS_ENC}@${DB_HOST}:5432/agentregistry?sslmode=require"
EOF
)
helm upgrade --install agentregistry oci://ghcr.io/agentregistry-dev/agentregistry/charts/agentregistry \
  -n agentregistry --create-namespace -f agentregistry-values.yaml
rm -f agentregistry-values.yaml
kubectl -n agentregistry rollout status deploy/agentregistry --timeout=5m

# arctl (umask 022 so the binary is executable)
( umask 022; curl -fsSL https://raw.githubusercontent.com/agentregistry-dev/agentregistry/main/scripts/get-arctl | bash )

cat <<'EOF'

agentregistry is running. In a separate terminal keep this port-forward open (arctl uses localhost:12121):
  kubectl -n agentregistry port-forward svc/agentregistry 12121:12121
Then check:
  arctl version
  arctl get runtimes     # expect kubernetes-default
EOF
