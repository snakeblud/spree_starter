Spree Commerce on AWS ECS with CloudFront VPC Origins
Architecture Overview
This is a production-ready, multi-AZ e-commerce platform built with Ruby on Rails (Spree Commerce) deployed on AWS ECS Fargate with private infrastructure and CloudFront VPC Origins for global content delivery.
Architecture Diagram
┌─────────────────────────────────────────────────────────────────┐
│                         CloudFront (Global CDN)                  │
│                    SSL/TLS, DDoS Protection, Caching             │
└────────────────────────┬────────────────────────────────────────┘
                         │ VPC Origin Connection
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ap-southeast-1 (Singapore)                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                      VPC (10.0.0.0/16)                    │  │
│  │  ┌─────────────────┐              ┌─────────────────┐    │  │
│  │  │  Public Subnet  │              │  Public Subnet  │    │  │
│  │  │   AZ1 (NAT)     │              │   AZ2 (NAT)     │    │  │
│  │  └────────┬────────┘              └────────┬────────┘    │  │
│  │           │                                │              │  │
│  │  ┌────────▼────────┐              ┌───────▼─────────┐   │  │
│  │  │ Private Subnet  │              │ Private Subnet  │   │  │
│  │  │      AZ1        │              │      AZ2        │   │  │
│  │  │                 │              │                 │   │  │
│  │  │  ┌──────────┐   │              │  ┌──────────┐  │   │  │
│  │  │  │ Private  │───┼──────────────┼──│ Private  │  │   │  │
│  │  │  │   ALB    │   │              │  │   ALB    │  │   │  │
│  │  │  └────┬─────┘   │              │  └────┬─────┘  │   │  │
│  │  │       │         │              │       │        │   │  │
│  │  │  ┌────▼─────┐   │              │  ┌────▼─────┐ │   │  │
│  │  │  │ECS Tasks │   │              │  │ECS Tasks │ │   │  │
│  │  │  │Web(2-10) │   │              │  │Web(2-10) │ │   │  │
│  │  │  │Worker(1-5│   │              │  │Worker(1-5│ │   │  │
│  │  │  └────┬─────┘   │              │  └────┬─────┘ │   │  │
│  │  │       │         │              │       │        │   │  │
│  │  │  ┌────▼─────────▼──────────────▼───────▼─────┐ │   │  │
│  │  │  │        RDS PostgreSQL (Multi-AZ)          │ │   │  │
│  │  │  │     Primary + Read Replica + Standby      │ │   │  │
│  │  │  └───────────────────────────────────────────┘ │   │  │
│  │  │  ┌───────────────────────────────────────────┐ │   │  │
│  │  │  │   Redis Cluster (Multi-AZ Replication)    │ │   │  │
│  │  │  └───────────────────────────────────────────┘ │   │  │
│  │  └───────────────────────────────────────────────────┘  │
│  └──────────────────────────────────────────────────────────┘
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  S3 Bucket   │  │     ECR      │  │   Secrets    │       │
│  │   (Assets)   │  │  (Container) │  │   Manager    │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└───────────────────────────────────────────────────────────────┘
Component Justification
1. CloudFront with VPC Origins
Why:

Global CDN reduces latency for international users
DDoS protection (AWS Shield Standard included)
SSL/TLS termination at edge locations
VPC Origins keep ALB completely private (no public internet exposure)
Cost savings on data transfer vs direct ALB access

2. Private Application Load Balancer
Why:

Internal ALB only accessible via CloudFront VPC Origin
Zero direct internet exposure
SSL offloading handled by CloudFront
Health checks and connection draining for zero-downtime deployments
Session stickiness for consistent user experience

3. ECS Fargate (Private Subnets)
Why:

Serverless containers (no EC2 management)
Auto-scaling based on CPU, memory, and request count
Private subnets prevent direct internet access
NAT Gateways provide outbound internet for updates/APIs
Task-level IAM roles for fine-grained permissions
Deployment circuit breakers prevent bad deployments

Web Service:

Min 2, Max 10 tasks for horizontal scaling
512 CPU, 1024 MB memory per task
Auto-scales at 70% CPU, 80% memory, or 1000 requests/target

Worker Service:

Min 1, Max 5 tasks for background jobs
256 CPU, 512 MB memory per task
Handles Sidekiq jobs (emails, image processing, etc.)

4. RDS PostgreSQL (Multi-AZ with Read Replica)
Why:

Multi-AZ: Automatic failover to standby in another AZ (< 60 seconds)
Read Replica: Offload read queries, reduce primary load
Automated backups (7 days retention)
Encryption at rest
Private subnets: Not accessible from internet
db.t3.micro: Cost-effective for small-medium workloads

5. ElastiCache Redis (Replication Group)
Why:

2-node cluster with automatic failover
Session storage, caching, Sidekiq job queue
Sub-millisecond latency
Multi-AZ replication for high availability
Encryption at rest and in transit

6. NAT Gateways (2x - One per AZ)
Why:

Allow private subnet resources to access internet (ECR, updates, APIs)
Highly available (managed by AWS)
One per AZ prevents single point of failure
Required for ECS tasks to pull Docker images from ECR

Cost Warning: This is the most expensive component (~$32/month each = $64/month total)
7. S3 Bucket
Why:

Scalable object storage for product images and assets
Integration with Rails Active Storage
Versioning enabled for accidental deletion recovery
Encryption at rest
Lifecycle policies to delete old versions (cost optimization)

8. ECR (Elastic Container Registry)
Why:

Private Docker registry integrated with ECS
Image scanning for vulnerabilities
Lifecycle policies (keep last 10 images)
Faster pulls than Docker Hub (same region)

9. Secrets Manager
Why:

Secure storage for database credentials, Redis URL, Rails secret key
Automatic rotation support
Fine-grained IAM access control
No secrets in environment variables or code

10. CloudWatch Logs
Why:

Centralized logging from all ECS tasks
7-day retention (cost optimization)
Searchable and filterable
Integration with CloudWatch Insights for log analysis

11. Route 53
Why:

DNS management for custom domain
Alias records point to CloudFront (no charge for alias queries)
Health checks and routing policies available

12. ACM (Certificate Manager)
Why:

Free SSL/TLS certificates
Automatic renewal
Wildcard certificate for subdomain flexibility

Prerequisites
Local Development Tools
bash# Required
- Docker Desktop (with BuildKit support)
- AWS CLI v2
- Make
- Git
- OpenSSL

# Verify installations
docker --version          # Should be 20.10+
aws --version            # Should be 2.x
make --version
git --version
AWS Account Requirements

Active AWS account
IAM user with AdministratorAccess (or specific permissions for CloudFormation, ECS, RDS, etc.)
AWS CLI configured with credentials
Domain name (optional but recommended)

AWS CLI Configuration
bashaws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: ap-southeast-1
# Default output format: json
Project Structure
spree_starter/
├── Dockerfile                          # Multi-stage build for Rails app
├── Gemfile                             # Ruby dependencies
├── Gemfile.lock
├── Makefile                            # Deployment automation
├── config/
│   ├── storage.yml                     # Active Storage S3 config
│   ├── environments/
│   │   └── production.rb               # Production settings
│   └── ...
├── aws/
│   ├── cloudformation/
│   │   └── infrastructure.yaml         # Complete infrastructure
│   └── scripts/
│       ├── deploy-stack.sh             # Deploy CloudFormation
│       ├── build-and-push.sh           # Build & push Docker image
│       ├── initial-setup.sh            # Database initialization
│       ├── run-migrations.sh           # Run migrations
│       └── update-services.sh          # Deploy new version
└── README.md
Deployment Guide
Step 1: Clone and Configure
bashgit clone <your-repo>
cd spree_starter

# Set your database password
export DB_PASSWORD="YourSecurePassword123"

# Optional: Set domain name
export DOMAIN_NAME="mystore.com"
export HOSTED_ZONE_ID="Z1234567890ABC"
Step 2: Deploy Infrastructure (~20-25 minutes)
bashmake deploy
This creates:

VPC with 2 public and 2 private subnets
NAT Gateways
Security groups
RDS PostgreSQL (Multi-AZ with read replica)
Redis cluster
S3 bucket
ECR repository
ECS cluster
Private ALB
CloudFront distribution (if domain provided)
IAM roles
Secrets Manager secrets
Auto-scaling policies

Wait for completion. Note the outputs, especially PrivateALBArn.
Step 3: Build and Push Docker Image (~5-10 minutes)
bashmake build
This:

Logs into ECR
Builds Docker image for linux/amd64
Tags as latest and git commit hash
Pushes to ECR

Step 4: Database Initialization (~3-5 minutes)
bashmake setup
This runs an ECS task that:

Creates database schema
Runs migrations
Installs Active Storage tables

Wait for task to complete (check with make logs).
Step 5: Configure Store URL and Admin User
bashmake configure-store
This creates:

Admin user: admin@store.com / admin123456
Configures store URL to CloudFront domain

Step 6: Manual CloudFront VPC Origin Configuration
CloudFormation doesn't support VPC Origins yet, so this must be done manually:

Get your Private ALB ARN:

bashmake outputs | grep PrivateALBArn

Go to CloudFront Console:
https://console.aws.amazon.com/cloudfront/v4/home?region=ap-southeast-1
Click VPC origins → Create VPC origin
Paste your ALB ARN
Click Create VPC origin
Wait 10-15 minutes for status: Deployed
Edit your CloudFront distribution:

Origins tab → Create origin
Select VPC origin from dropdown
Save


Update default behavior:

Behaviors tab → Edit Default (*)
Change Origin to your VPC origin
Save and deploy



Step 7: SSL Certificate Validation (if using custom domain)

Go to ACM Console:
https://console.aws.amazon.com/acm/home?region=us-east-1
Find your certificate
Click Create records in Route 53
Wait 5-30 minutes for validation

Step 8: Access Your Store
Without custom domain:
bashmake outputs | grep CloudFrontDomainName
# Visit: https://d1234567890.cloudfront.net
With custom domain:
https://yourdomain.com
Admin panel:
https://yourdomain.com/admin
Email: admin@store.com
Password: admin123456
Ongoing Operations
Deploy New Version
bash# Make code changes
git commit -am "New feature"

# Build and push new image
make build

# Deploy to ECS (zero-downtime)
make update
Run Database Migrations
bashmake migrate
View Logs
bash# All logs
make logs

# Filter by service
aws logs tail /ecs/spree-production --follow --filter-pattern "web" --region ap-southeast-1
aws logs tail /ecs/spree-production --follow --filter-pattern "worker" --region ap-southeast-1
Manual Scaling
bash# Scale web service
aws ecs update-service \
  --cluster spree-production-cluster \
  --service spree-production-web \
  --desired-count 5 \
  --region ap-southeast-1

# Scale worker service
aws ecs update-service \
  --cluster spree-production-cluster \
  --service spree-production-worker \
  --desired-count 3 \
  --region ap-southeast-1
Check Auto-Scaling Activity
bashaws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --region ap-southeast-1
Cost Estimate (Monthly - Singapore Region)
Fixed Costs
ServiceConfigurationCost/MonthNAT Gateway2x (Multi-AZ)$64.00RDS PostgreSQLdb.t3.micro Multi-AZ$27.00RDS Read Replicadb.t3.micro$13.50ElastiCache Redis2x cache.t3.micro$24.00ECS Fargate - Web2 tasks × 0.5 vCPU, 1GB$21.60ECS Fargate - Worker1 task × 0.25 vCPU, 0.5GB$5.40ALBPrivate (internal)$16.20CloudWatch Logs7-day retention (~5GB)$2.50Secrets Manager3 secrets$1.20Route 53Hosted zone$0.50Total Fixed~$176/month
Variable Costs (Estimated)
ServiceUsageCost/MonthNAT Gateway Data100GB outbound$4.50S3 Storage50GB images$1.15S3 Requests1M requests$0.40CloudFront100GB transfer, 1M requests$8.50ECR Storage10 images (~5GB)$0.50RDS Storage20GB × 2 (Multi-AZ)$4.60Data Transfer Out50GB$4.50Total Variable~$24/month
Auto-Scaling Additional Costs
ScenarioAdditional TasksExtra CostNormal2 web, 1 worker$0 (included above)Medium Traffic5 web, 2 workers+$35/monthHigh Traffic10 web, 5 workers+$105/month
Total Estimated Cost

Minimum: ~$200/month (base infrastructure)
Average: ~$235/month (moderate traffic)
Peak: ~$305/month (high traffic with auto-scaling)

Cost Optimization Options

Use Single NAT Gateway (-$32/month)

Remove one NAT Gateway
Single point of failure - not recommended for production


Remove Read Replica (-$13.50/month)

Keep only primary RDS instance
Reduces read capacity


Use Single-AZ RDS (-$13.50/month)

No automatic failover
Not recommended for production


Reduce Log Retention (-$1/month)

1-day retention instead of 7


Use Fargate Spot (-20-30%)

Can be interrupted
Good for dev/staging



Realistic Production Minimum: ~$190/month (removing read replica only)
Architecture Benefits
✅ High Availability

Multi-AZ deployment across 2 availability zones
Automatic failover for RDS and Redis
ECS tasks distributed across AZs
No single point of failure

✅ Security

ALB completely private (no public IP)
All traffic through CloudFront VPC Origins
Encryption at rest (RDS, Redis, S3, ECR)
Secrets in AWS Secrets Manager
Security groups limit access to minimum required

✅ Scalability

Auto-scales 2-10 web tasks based on load
Auto-scales 1-5 worker tasks
RDS read replica for read-heavy workloads
CloudFront caching reduces origin load

✅ Performance

CloudFront edge locations globally
Redis caching (sub-millisecond)
RDS read replica for queries
Connection pooling

✅ Reliability

Deployment circuit breakers
Health checks with automatic recovery
Zero-downtime deployments
Automated backups (7 days)

✅ Observability

Centralized CloudWatch Logs
Container Insights for metrics
RDS Performance Insights
CloudFront access logs

Monitoring and Alerts
Key Metrics to Monitor
bash# ECS Service Health
aws ecs describe-services \
  --cluster spree-production-cluster \
  --services spree-production-web \
  --region ap-southeast-1 \
  --query 'services[0].[runningCount,desiredCount]'

# RDS CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=spree-production-postgres \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region ap-southeast-1
Recommended CloudWatch Alarms

ECS Task Count < 1 (Critical)
RDS CPU > 80% (Warning)
RDS Free Storage < 2GB (Warning)
ALB Unhealthy Targets > 0 (Critical)
NAT Gateway Errors > 0 (Warning)

Disaster Recovery
Backup Strategy
RDS:

Automated daily backups (7 days retention)
Final snapshot on deletion
Manual snapshots before major changes

Recovery:
bash# Restore from automated backup
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier spree-production-postgres \
  --target-db-instance-identifier spree-production-postgres-restored \
  --restore-time 2025-01-15T10:00:00Z \
  --region ap-southeast-1
S3:

Versioning enabled
Can restore deleted objects within 30 days

Rollback Procedure
bash# Rollback to previous image
IMAGE_TAG="previous-working-commit-hash"

aws ecs update-service \
  --cluster spree-production-cluster \
  --service spree-production-web \
  --task-definition spree-production-web:VERSION \
  --region ap-southeast-1
Troubleshooting
ECS Tasks Failing to Start
bash# Check task failures
aws ecs describe-tasks \
  --cluster spree-production-cluster \
  --tasks $(aws ecs list-tasks --cluster spree-production-cluster --region ap-southeast-1 --query 'taskArns[0]' --output text) \
  --region ap-southeast-1
Common issues:

ECR pull errors: Check IAM permissions
Database connection: Check security groups
Out of memory: Increase task memory

Database Connection Issues
bash# Test from ECS task
aws ecs run-task \
  --cluster spree-production-cluster \
  --task-definition spree-production-web \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=DISABLED}" \
  --overrides '{"containerOverrides":[{"name":"web","command":["sh","-c","nc -zv $DATABASE_HOST 5432"]}]}' \
  --region ap-southeast-1
CloudFront Not Routing to VPC Origin

Verify VPC Origin status is "Deployed"
Check CloudFront distribution uses VPC origin
Verify ALB security group allows CloudFront prefix list
Check ALB listener rules

High Costs
bash# Check NAT Gateway data transfer
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination \
  --dimensions Name=NatGatewayId,Value=nat-xxx \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400 \
  --statistics Sum \
  --region ap-southeast-1
Cleanup
WARNING: This destroys all data!
bash# Delete stack
make destroy

# Manually delete:
# - S3 bucket contents (versioned objects)
# - ECR images
# - RDS snapshots (if you want them gone)
# - CloudWatch log groups
Support and Resources

Spree Documentation: https://guides.spreecommerce.org/
AWS ECS: https://docs.aws.amazon.com/ecs/
CloudFront VPC Origins: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-vpc-origins.html
Rails Deployment: https://guides.rubyonrails.org/deployment.html

License
[Your License Here]

Built with: Ruby 3.3, Rails 8.0, Spree 5.1, PostgreSQL 16, Redis 7.1, AWS ECS Fargate
