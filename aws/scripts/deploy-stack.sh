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

echo "Deploying $ENV environment..."

# Generate SECRET_KEY_BASE if not in env file
if [ -z "$SECRET_KEY_BASE" ]; then
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    echo "Generated new SECRET_KEY_BASE"
fi

# Deploy stack
aws cloudformation deploy \
    --template-file $TEMPLATE_FILE \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        EnvironmentName=$ENVIRONMENT_NAME \
        DatabasePassword=$DB_PASSWORD \
        SecretKeyBase=$SECRET_KEY_BASE \
        DomainName=$DOMAIN_NAME \
        HostedZoneId=$HOSTED_ZONE_ID \
        CertificateArn=$CERTIFICATE_ARN \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

echo "Stack deployment complete!"