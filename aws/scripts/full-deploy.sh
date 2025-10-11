#!/bin/bash
set -e

ENV=${1:-production}
CONFIG_FILE="aws/config/${ENV}.env"
STACK_NAME="spree-commerce-stack"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file $CONFIG_FILE not found"
    exit 1
fi

# Source the env file
source "$CONFIG_FILE"

# Generate SECRET_KEY_BASE if not set
if [ -z "$SECRET_KEY_BASE" ]; then
    SECRET_KEY_BASE=$(openssl rand -hex 64)
    echo "Generated new SECRET_KEY_BASE"
fi

# Get AWS Account ID for S3 bucket name
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET="cf-templates-${ACCOUNT_ID}-${REGION}"

echo "=== Full Deployment Process ==="
echo ""

echo "Stage 1: Deploy infrastructure with DesiredCount=0..."
echo "Uploading template to S3..."

# Upload template to S3 first
TEMPLATE_S3_KEY="cloudformation-templates/infrastructure-$(date +%s).yaml"
aws s3 cp aws/cloudformation/infrastructure.yaml \
    "s3://${S3_BUCKET}/${TEMPLATE_S3_KEY}" \
    --region $REGION

echo "Template uploaded to: s3://${S3_BUCKET}/${TEMPLATE_S3_KEY}"

# Deploy using create-stack or update-stack (non-blocking)
echo "Creating/Updating CloudFormation stack..."
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION 2>/dev/null; then
    echo "Stack exists, updating..."
    aws cloudformation update-stack \
        --stack-name $STACK_NAME \
        --template-url "https://${S3_BUCKET}.s3.${REGION}.amazonaws.com/${TEMPLATE_S3_KEY}" \
        --parameters \
            ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT_NAME \
            ParameterKey=DatabasePassword,ParameterValue=$DB_PASSWORD \
            ParameterKey=SecretKeyBase,ParameterValue=$SECRET_KEY_BASE \
            ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME \
            ParameterKey=HostedZoneId,ParameterValue=$HOSTED_ZONE_ID \
            ParameterKey=CertificateArn,ParameterValue=$CERTIFICATE_ARN \
            ParameterKey=DockerImageTag,ParameterValue=latest \
            ParameterKey=AlertEmail,ParameterValue=${ALERT_EMAIL:-""} \
            ParameterKey=HighCPUThreshold,ParameterValue=${HIGH_CPU_THRESHOLD:-80} \
            ParameterKey=HighMemoryThreshold,ParameterValue=${HIGH_MEMORY_THRESHOLD:-85} \
            ParameterKey=HighErrorRateThreshold,ParameterValue=${HIGH_ERROR_RATE_THRESHOLD:-10} \
            ParameterKey=DatabaseConnectionsThreshold,ParameterValue=${DATABASE_CONNECTIONS_THRESHOLD:-80} \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION || echo "No updates to be performed (stack may be up to date)"
else
    echo "Stack does not exist, creating..."
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-url "https://${S3_BUCKET}.s3.${REGION}.amazonaws.com/${TEMPLATE_S3_KEY}" \
        --parameters \
            ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT_NAME \
            ParameterKey=DatabasePassword,ParameterValue=$DB_PASSWORD \
            ParameterKey=SecretKeyBase,ParameterValue=$SECRET_KEY_BASE \
            ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME \
            ParameterKey=HostedZoneId,ParameterValue=$HOSTED_ZONE_ID \
            ParameterKey=CertificateArn,ParameterValue=$CERTIFICATE_ARN \
            ParameterKey=DockerImageTag,ParameterValue=latest \
            ParameterKey=AlertEmail,ParameterValue=${ALERT_EMAIL:-""} \
            ParameterKey=HighCPUThreshold,ParameterValue=${HIGH_CPU_THRESHOLD:-80} \
            ParameterKey=HighMemoryThreshold,ParameterValue=${HIGH_MEMORY_THRESHOLD:-85} \
            ParameterKey=HighErrorRateThreshold,ParameterValue=${HIGH_ERROR_RATE_THRESHOLD:-10} \
            ParameterKey=DatabaseConnectionsThreshold,ParameterValue=${DATABASE_CONNECTIONS_THRESHOLD:-80} \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION
fi

echo ""
echo "CloudFormation stack deployment initiated (non-blocking)"
echo "Waiting for stack to be ready before proceeding to next stages..."
echo ""
echo "Monitoring stack status (this may take 15-20 minutes)..."
echo "Press Ctrl+C at any time to exit monitoring (deployment will continue in AWS)"
echo ""

# Wait for stack to complete (but allow user to exit)
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION 2>/dev/null || \
aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION 2>/dev/null || {
    echo ""
    echo "⚠️  Stack deployment is still in progress or you exited the wait."
    echo ""
    echo "To check status:"
    echo "  aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].StackStatus'"
    echo ""
    echo "To continue deployment manually after stack is ready:"
    echo "  make build          # Build and push Docker image"
    echo "  make scale-up       # Scale ECS services"
    echo "  make setup          # Run migrations"
    echo ""
    exit 1
}

echo "✓ Stack deployment complete!"
echo ""
echo "Stage 2: Build and push Docker image..."
chmod +x ./aws/scripts/build-and-push.sh
./aws/scripts/build-and-push.sh

echo ""
echo "Stage 3: Scale services to desired count..."
aws ecs update-service \
    --cluster ${ENVIRONMENT_NAME}-cluster \
    --service ${ENVIRONMENT_NAME}-web \
    --desired-count 2 \
    --region $REGION

aws ecs update-service \
    --cluster ${ENVIRONMENT_NAME}-cluster \
    --service ${ENVIRONMENT_NAME}-worker \
    --desired-count 1 \
    --region $REGION

echo ""
echo "Stage 4: Wait for services to stabilize..."
aws ecs wait services-stable \
    --cluster ${ENVIRONMENT_NAME}-cluster \
    --services ${ENVIRONMENT_NAME}-web ${ENVIRONMENT_NAME}-worker \
    --region $REGION

echo ""
echo "Stage 5: Run database setup..."
chmod +x ./aws/scripts/initial-setup.sh
./aws/scripts/initial-setup.sh


echo ""
echo "Stage 6: Run migrations setup..."
chmod +x ./aws/scripts/run-migrations.sh
./aws/scripts/run-migrations.sh

echo ""
echo "Stage 7: Load sample data (optional)..."
# Uncomment the lines below to load sample data during deployment
# This will add sample products, categories, and checkout flow
# WARNING: Running this multiple times may create duplicate data
chmod +x ./aws/scripts/load-sample-data.sh
./aws/scripts/load-sample-data.sh

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "📝 Note: To load sample data manually, run:"
echo "   ./aws/scripts/load-sample-data.sh"