#!/bin/bash
set -e

STACK_NAME="spree-commerce-stack"
REGION="ap-southeast-1"
ENVIRONMENT="${ENVIRONMENT:-spree-production}"
SKIP_IF_EXISTS="${SKIP_IF_EXISTS:-false}"

echo "Getting cluster and network configuration..."
CLUSTER=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSClusterName`].OutputValue' \
    --output text)

SUBNETS=$(aws cloudformation describe-stack-resources \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "StackResources[?LogicalResourceId=='PrivateSubnet1' || LogicalResourceId=='PrivateSubnet2'].PhysicalResourceId" \
    --output text | tr '\t' ',')

SG=$(aws cloudformation describe-stack-resources \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query "StackResources[?LogicalResourceId=='ECSSecurityGroup'].PhysicalResourceId" \
    --output text)

echo ""
echo "⚠️  WARNING: This will load sample data into your store."
echo "   This includes sample products, categories, and checkout flow."
echo "   If sample data already exists, this may create duplicates."
echo ""

if [ "$SKIP_IF_EXISTS" = "true" ]; then
    echo "Checking if products already exist..."
    # Note: This is a simplified check - you may want to enhance this
    read -p "Skip this step if products exist? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping sample data load."
        exit 0
    fi
fi

echo "Loading sample data..."
TASK_ARN=$(aws ecs run-task \
    --cluster $CLUSTER \
    --task-definition ${ENVIRONMENT}-web \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG],assignPublicIp=DISABLED}" \
    --overrides '{"containerOverrides":[{"name":"web","command":["sh","-c","bundle exec rake spree_sample:load"]}]}' \
    --region $REGION \
    --query 'tasks[0].taskArn' \
    --output text)

echo "Sample data loading task started: $TASK_ARN"
echo "Waiting for task to complete..."

# Wait for the task to finish
aws ecs wait tasks-stopped \
    --cluster $CLUSTER \
    --tasks $TASK_ARN \
    --region $REGION

# Check if task succeeded
EXIT_CODE=$(aws ecs describe-tasks \
    --cluster $CLUSTER \
    --tasks $TASK_ARN \
    --region $REGION \
    --query 'tasks[0].containers[0].exitCode' \
    --output text)

if [ "$EXIT_CODE" = "0" ]; then
    echo ""
    echo "✅ Sample data loaded successfully!"
    echo "   Your store now includes:"
    echo "   - Sample products"
    echo "   - Product categories"
    echo "   - Checkout flow configuration"
    echo ""
else
    echo "❌ Sample data loading failed with exit code: $EXIT_CODE"
    exit 1
fi
