#!/bin/bash
set -e

STACK_NAME="spree-commerce-stack"
REGION="ap-southeast-1"

echo "Getting ECR repository URI..."
ECR_URI=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
    --output text)

if [ -z "$ECR_URI" ]; then
    echo "Error: Could not get ECR URI. Is the stack deployed?"
    exit 1
fi

echo "ECR Repository: $ECR_URI"

if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
fi

echo "Building Docker image with tag: $IMAGE_TAG"

echo "Logging in to ECR..."
aws ecr get-login-password --region $REGION | \
    docker login --username AWS --password-stdin $ECR_URI

echo "Building Docker image..."
# Use docker buildx with --load to avoid manifest lists (ECS Fargate doesn't support them)
# This creates a single-platform image that can be pulled directly
docker buildx build --platform linux/amd64 --load -t spree-starter:$IMAGE_TAG .

echo "Tagging image..."
docker tag spree-starter:$IMAGE_TAG $ECR_URI:$IMAGE_TAG
docker tag spree-starter:$IMAGE_TAG $ECR_URI:latest

echo "Pushing image to ECR..."
docker push $ECR_URI:$IMAGE_TAG
docker push $ECR_URI:latest

echo ""
echo "Image pushed successfully!"
echo "Image: $ECR_URI:$IMAGE_TAG"