#!/bin/bash
set -e

ENV=${1:-production}
CONFIG_FILE="aws/config/${ENV}.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file $CONFIG_FILE not found"
    exit 1
fi

# Source the env file
source "$CONFIG_FILE"

STACK_NAME="spree-commerce-stack"
TEMPLATE_FILE="aws/cloudformation/infrastructure.yaml"

# Get AWS Account ID for S3 bucket name
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET="cf-templates-${ACCOUNT_ID}-${REGION}"

echo "Deploying $ENV environment..."

# Generate SECRET_KEY_BASE if not in env file
if [ -z "$SECRET_KEY_BASE" ]; then
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    echo "Generated new SECRET_KEY_BASE"
fi

# Deploy stack using S3 bucket (required for templates > 51KB)
echo "Uploading template to S3..."
aws cloudformation deploy \
    --template-file $TEMPLATE_FILE \
    --stack-name $STACK_NAME \
    --s3-bucket $S3_BUCKET \
    --s3-prefix cloudformation-templates \
    --parameter-overrides \
        EnvironmentName=$ENVIRONMENT_NAME \
        DatabasePassword=$DB_PASSWORD \
        SecretKeyBase=$SECRET_KEY_BASE \
        DomainName=$DOMAIN_NAME \
        HostedZoneId=$HOSTED_ZONE_ID \
        CertificateArn=$CERTIFICATE_ARN \
        AlertEmail=${ALERT_EMAIL:-""} \
        HighCPUThreshold=${HIGH_CPU_THRESHOLD:-80} \
        HighMemoryThreshold=${HIGH_MEMORY_THRESHOLD:-85} \
        HighErrorRateThreshold=${HIGH_ERROR_RATE_THRESHOLD:-10} \
        DatabaseConnectionsThreshold=${DATABASE_CONNECTIONS_THRESHOLD:-80} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

echo "Stack deployment complete!"