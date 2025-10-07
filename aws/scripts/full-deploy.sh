#!/bin/bash
set -e

ENV=${1:-production}
REGION="ap-southeast-1"
STACK_NAME="spree-commerce-stack"

echo "=== Full Deployment Process ==="
echo ""

echo "Stage 1: Deploy infrastructure with DesiredCount=0..."
aws cloudformation deploy \
    --template-file aws/cloudformation/infrastructure.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        EnvironmentName=spree-production \
        DatabasePassword=SpreeCommerce2025 \
        SecretKeyBase=$(openssl rand -hex 64) \
        DomainName="doubleclick.systems" \
        HostedZoneId="Z033521913X4N9C48W9EH" \
        CertificateArn="arn:aws:acm:us-east-1:246926547243:certificate/a179637b-c4ea-443d-be22-b94053312e40" \
        DockerImageTag=latest \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

echo ""
echo "Stage 2: Build and push Docker image..."
chmod +x ./aws/scripts/build-and-push.sh
./aws/scripts/build-and-push.sh

echo ""
echo "Stage 3: Scale services to desired count..."
aws ecs update-service \
    --cluster spree-production-cluster \
    --service spree-production-web \
    --desired-count 2 \
    --region $REGION

aws ecs update-service \
    --cluster spree-production-cluster \
    --service spree-production-worker \
    --desired-count 1 \
    --region $REGION

echo ""
echo "Stage 4: Wait for services to stabilize..."
aws ecs wait services-stable \
    --cluster spree-production-cluster \
    --services spree-production-web spree-production-worker \
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
# chmod +x ./aws/scripts/load-sample-data.sh
# ./aws/scripts/load-sample-data.sh

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "📝 Note: To load sample data manually, run:"
echo "   ./aws/scripts/load-sample-data.sh"