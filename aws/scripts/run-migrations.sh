#!/bin/bash
set -e

STACK_NAME="spree-commerce-stack"
REGION="ap-southeast-1"
ENVIRONMENT="${ENVIRONMENT:-spree-production}"

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

echo "Running migrations..."
aws ecs run-task \
    --cluster $CLUSTER \
    --task-definition ${ENVIRONMENT}-web \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG],assignPublicIp=DISABLED}" \
    --overrides '{"containerOverrides":[{"name":"web","command":["sh","-c","bundle exec rails db:migrate"]}]}' \
    --region $REGION

echo "Migration task started!"