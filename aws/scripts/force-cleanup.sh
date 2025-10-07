#!/bin/bash
set -e

STACK_NAME="spree-commerce-stack"
REGION="ap-southeast-1"
ENVIRONMENT="spree-production"

echo "ðŸ§¹ Force cleaning up stuck resources..."

# Delete Redis replication group
echo "Deleting Redis..."
aws elasticache delete-replication-group \
    --replication-group-id ${ENVIRONMENT}-redis \
    --region $REGION 2>/dev/null || echo "Redis already deleted or doesn't exist"

# Delete individual Redis cache clusters if replication group fails
for cluster in $(aws elasticache describe-cache-clusters \
    --region $REGION \
    --query "CacheClusters[?starts_with(CacheClusterId, '${ENVIRONMENT}-redis')].CacheClusterId" \
    --output text); do
    echo "Deleting cache cluster: $cluster"
    aws elasticache delete-cache-cluster \
        --cache-cluster-id $cluster \
        --region $REGION 2>/dev/null || true
done

# Delete RDS instances
echo "Deleting RDS read replica..."
aws rds delete-db-instance \
    --db-instance-identifier ${ENVIRONMENT}-postgres-readreplica \
    --skip-final-snapshot \
    --region $REGION 2>/dev/null || echo "Read replica already deleted"

echo "Deleting RDS primary..."
aws rds delete-db-instance \
    --db-instance-identifier ${ENVIRONMENT}-postgres \
    --skip-final-snapshot \
    --delete-automated-backups \
    --region $REGION 2>/dev/null || echo "Primary already deleted"

# Delete ECS cluster if exists
echo "Deleting ECS cluster..."
aws ecs delete-cluster \
    --cluster ${ENVIRONMENT}-cluster \
    --region $REGION 2>/dev/null || echo "Cluster already deleted"

# Delete ECR repository
echo "Deleting ECR repository..."
aws ecr delete-repository \
    --repository-name spree-starter \
    --force \
    --region $REGION 2>/dev/null || echo "ECR already deleted"

# Delete Secrets Manager secrets
for secret in database-url redis-url secret-key-base; do
    echo "Deleting secret: ${ENVIRONMENT}/$secret"
    aws secretsmanager delete-secret \
        --secret-id ${ENVIRONMENT}/$secret \
        --force-delete-without-recovery \
        --region $REGION 2>/dev/null || true
done

echo ""
echo "â³ Waiting for resources to finish deleting (this may take 5-10 minutes)..."
echo "Press Ctrl+C if you want to proceed without waiting"
sleep 10

# Now delete the CloudFormation stack
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name $STACK_NAME \
    --region $REGION

echo ""
echo "âœ… Cleanup initiated. Run this to check status:"
echo "   aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION"