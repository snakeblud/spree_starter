#!/bin/bash
set -e

STACK_NAME="spree-commerce-stack"
REGION="ap-southeast-1"
ENVIRONMENT="spree-production"

echo "Forcing cleanup of stuck resources..."

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ==================== S3 Bucket Cleanup ====================
echo ""
echo "Step 1: Emptying S3 bucket..."
S3_BUCKET="${ENVIRONMENT}-spree-assets-${ACCOUNT_ID}"
if aws s3 ls "s3://${S3_BUCKET}" 2>/dev/null; then
    echo "Found S3 bucket: ${S3_BUCKET}"

    # Delete all objects
    echo "Deleting all objects..."
    aws s3 rm "s3://${S3_BUCKET}" --recursive --region $REGION 2>/dev/null || true

    # Delete all versions if versioning is enabled
    echo "Deleting all object versions..."
    aws s3api list-object-versions \
        --bucket "${S3_BUCKET}" \
        --output json 2>/dev/null | \
    jq -r '.Versions[]? | "s3api delete-object --bucket '${S3_BUCKET}' --key \"" + .Key + "\" --version-id " + .VersionId' | \
    xargs -I {} aws {} 2>/dev/null || true

    # Delete all delete markers
    echo "Deleting delete markers..."
    aws s3api list-object-versions \
        --bucket "${S3_BUCKET}" \
        --output json 2>/dev/null | \
    jq -r '.DeleteMarkers[]? | "s3api delete-object --bucket '${S3_BUCKET}' --key \"" + .Key + "\" --version-id " + .VersionId' | \
    xargs -I {} aws {} 2>/dev/null || true

    echo "S3 bucket emptied successfully"
else
    echo "S3 bucket not found or already deleted"
fi

# ==================== ECR Cleanup ====================
echo ""
echo "Step 2: Deleting ECR repository..."
aws ecr delete-repository \
    --repository-name spree-starter \
    --force \
    --region $REGION 2>/dev/null || echo "ECR already deleted"

# ==================== ECS Service Cleanup ====================
echo ""
echo "Step 3: Scaling down ECS services..."
# Scale services to 0 first
for service in web worker; do
    aws ecs update-service \
        --cluster ${ENVIRONMENT}-cluster \
        --service ${ENVIRONMENT}-${service} \
        --desired-count 0 \
        --region $REGION 2>/dev/null || echo "Service ${service} not found"
done

echo "Waiting 10 seconds for tasks to drain..."
sleep 10

# Delete services
echo "Deleting ECS services..."
for service in web worker; do
    aws ecs delete-service \
        --cluster ${ENVIRONMENT}-cluster \
        --service ${ENVIRONMENT}-${service} \
        --force \
        --region $REGION 2>/dev/null || echo "Service ${service} already deleted"
done

# ==================== Redis Cleanup ====================
echo ""
echo "Step 4: Deleting Redis..."
aws elasticache delete-replication-group \
    --replication-group-id ${ENVIRONMENT}-redis \
    --region $REGION 2>/dev/null || echo "Redis already deleted or doesn't exist"

# Delete individual Redis cache clusters if replication group fails
for cluster in $(aws elasticache describe-cache-clusters \
    --region $REGION \
    --query "CacheClusters[?starts_with(CacheClusterId, '${ENVIRONMENT}-redis')].CacheClusterId" \
    --output text 2>/dev/null); do
    echo "Deleting cache cluster: $cluster"
    aws elasticache delete-cache-cluster \
        --cache-cluster-id $cluster \
        --region $REGION 2>/dev/null || true
done

# ==================== RDS Cleanup ====================
echo ""
echo "Step 5: Deleting RDS instances..."
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

# ==================== ECS Cluster Cleanup ====================
echo ""
echo "Step 6: Deleting ECS cluster..."
aws ecs delete-cluster \
    --cluster ${ENVIRONMENT}-cluster \
    --region $REGION 2>/dev/null || echo "Cluster already deleted"

# ==================== Secrets Manager Cleanup ====================
echo ""
echo "Step 7: Deleting Secrets Manager secrets..."
for secret in database-url redis-url secret-key-base; do
    echo "Deleting secret: ${ENVIRONMENT}/$secret"
    aws secretsmanager delete-secret \
        --secret-id ${ENVIRONMENT}/$secret \
        --force-delete-without-recovery \
        --region $REGION 2>/dev/null || true
done

# ==================== SNS Topic Cleanup ====================
echo ""
echo "Step 8: Deleting SNS topics..."
SNS_TOPIC_ARN=$(aws sns list-topics \
    --region $REGION \
    --query "Topics[?contains(TopicArn, '${ENVIRONMENT}-alerts')].TopicArn" \
    --output text 2>/dev/null)

if [ ! -z "$SNS_TOPIC_ARN" ]; then
    echo "Deleting SNS topic: $SNS_TOPIC_ARN"
    aws sns delete-topic --topic-arn "$SNS_TOPIC_ARN" --region $REGION 2>/dev/null || true
else
    echo "SNS topic not found or already deleted"
fi

# ==================== CloudWatch Dashboard Cleanup ====================
echo ""
echo "Step 9: Deleting CloudWatch dashboard..."
aws cloudwatch delete-dashboards \
    --dashboard-names ${ENVIRONMENT}-dashboard \
    --region $REGION 2>/dev/null || echo "Dashboard not found or already deleted"

# ==================== CloudWatch Alarms Cleanup ====================
echo ""
echo "Step 10: Deleting CloudWatch alarms..."
ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "${ENVIRONMENT}-" \
    --query 'MetricAlarms[].AlarmName' \
    --output text \
    --region $REGION 2>/dev/null)

if [ ! -z "$ALARMS" ]; then
    echo "Found alarms to delete: $ALARMS"
    aws cloudwatch delete-alarms \
        --alarm-names $ALARMS \
        --region $REGION 2>/dev/null || true
else
    echo "No alarms found"
fi

# ==================== CloudWatch Log Groups Cleanup ====================
echo ""
echo "Step 11: Deleting CloudWatch log groups..."
aws logs delete-log-group \
    --log-group-name /ecs/${ENVIRONMENT} \
    --region $REGION 2>/dev/null || echo "Log group already deleted"

echo ""
echo "Waiting 30 seconds for resources to finish deleting..."
echo "Press Ctrl+C if you want to proceed without waiting"
sleep 30

echo ""
echo "Cleanup completed successfully!"
echo ""
echo "Note: RDS and ElastiCache deletions can take 5-15 minutes."
echo "The CloudFormation stack will be deleted separately by the 'make destroy' command."
