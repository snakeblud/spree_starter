#!/bin/bash
set -e

STACK_NAME="spree-commerce-stack"
REGION="ap-southeast-1"
ENVIRONMENT="${ENVIRONMENT:-spree-production}"

echo "Getting cluster name..."
CLUSTER=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSClusterName`].OutputValue' \
    --output text 2>/dev/null)

if [ -z "$CLUSTER" ] || [ "$CLUSTER" = "None" ]; then
    CLUSTER="${ENVIRONMENT}-cluster"
fi

echo "Cluster: $CLUSTER"

echo "Updating web service (desired count: 2)..."
aws ecs update-service \
    --cluster $CLUSTER \
    --service ${ENVIRONMENT}-web \
    --desired-count 2 \
    --force-new-deployment \
    --region $REGION

echo "Updating worker service (desired count: 1)..."
aws ecs update-service \
    --cluster $CLUSTER \
    --service ${ENVIRONMENT}-worker \
    --desired-count 1 \
    --force-new-deployment \
    --region $REGION

echo ""
echo "Services updated! Waiting for deployment..."

aws ecs wait services-stable \
    --cluster $CLUSTER \
    --services ${ENVIRONMENT}-web ${ENVIRONMENT}-worker \
    --region $REGION

echo "Deployment complete!"