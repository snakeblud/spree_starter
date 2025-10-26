#!/bin/bash
set -e

WAF_STACK_NAME="spree-waf-cloudfront"
WAF_REGION="us-east-1"  # WAF for CloudFront MUST be in us-east-1
MAIN_STACK_NAME="spree-commerce-stack"
MAIN_REGION="ap-southeast-1"
ENVIRONMENT="spree-production"

echo "========================================="
echo "Deploying WAF for CloudFront"
echo "========================================="
echo ""
echo "Note: WAF for CloudFront must be created in us-east-1"
echo ""

# Deploy WAF stack in us-east-1
echo "Step 1: Deploying WAF WebACL in us-east-1..."
aws cloudformation deploy \
    --template-file aws/cloudformation/waf-cloudfront.yaml \
    --stack-name $WAF_STACK_NAME \
    --parameter-overrides \
        EnvironmentName=$ENVIRONMENT \
    --region $WAF_REGION \
    --no-fail-on-empty-changeset

echo ""
echo "✓ WAF WebACL deployed successfully!"
echo ""

# Get WAF ARN
echo "Step 2: Getting WAF WebACL ARN..."
WAF_ARN=$(aws cloudformation describe-stacks \
    --stack-name $WAF_STACK_NAME \
    --region $WAF_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WAFWebACLArn`].OutputValue' \
    --output text)

echo "WAF ARN: $WAF_ARN"
echo ""

# Get CloudFront Distribution ID
echo "Step 3: Getting CloudFront Distribution ID..."
CLOUDFRONT_ID=$(aws cloudformation describe-stacks \
    --stack-name $MAIN_STACK_NAME \
    --region $MAIN_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text)

if [ -z "$CLOUDFRONT_ID" ] || [ "$CLOUDFRONT_ID" = "None" ]; then
    echo "❌ Error: CloudFront Distribution not found in main stack"
    echo "   Make sure the main infrastructure stack is deployed first"
    exit 1
fi

echo "CloudFront Distribution ID: $CLOUDFRONT_ID"
echo ""

# Associate WAF with CloudFront
echo "Step 4: Associating WAF with CloudFront distribution..."
# Note: For CloudFront, the region must be us-east-1 and scope is implicit from the ARN
aws cloudfront update-distribution \
    --id "$CLOUDFRONT_ID" \
    --if-match "$(aws cloudfront get-distribution --id $CLOUDFRONT_ID --query 'ETag' --output text)" \
    --distribution-config "$(aws cloudfront get-distribution --id $CLOUDFRONT_ID --query 'Distribution.DistributionConfig' --output json | jq --arg waf_arn "$WAF_ARN" '.WebACLId = $waf_arn')"

echo ""
echo "========================================="
echo "✓ WAF successfully associated with CloudFront!"
echo "========================================="
echo ""
echo "WAF WebACL ARN: $WAF_ARN"
echo "CloudFront Distribution ID: $CLOUDFRONT_ID"
echo ""
echo "You can view WAF metrics in CloudWatch (us-east-1 region)"
echo "To view blocked requests, check AWS WAF console in us-east-1"
