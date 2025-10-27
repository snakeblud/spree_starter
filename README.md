# Spree Starter - AWS Cloud Deployment

This is a production-ready cloud deployment of [Spree Commerce](https://spreecommerce.org) on AWS with CloudFront CDN, WAF security, and auto-scaling capabilities.

## Architecture Overview

This deployment uses a fully managed AWS infrastructure including:

* **[Spree Commerce 5](https://spreecommerce.org/announcing-spree-5-the-biggest-open-source-release-ever/)** - Admin Dashboard, API, and Storefront
* **AWS ECS Fargate** - Containerized application hosting (auto-scaling)
* **Amazon RDS PostgreSQL** - Primary database with read replica
* **Amazon ElastiCache Redis** - Session storage and caching
* **CloudFront CDN** - Global content delivery with caching
* **AWS WAF** - Web Application Firewall for DDoS and security protection
* **Application Load Balancer** - Traffic distribution across containers
* **Amazon S3** - Asset storage (images, uploads)
* **AWS Secrets Manager** - Secure credential management
* **CloudWatch** - Monitoring, logging, and alerting
* **Stripe** for payment processing
* **Google Analytics 4** integration
* **Klaviyo** integration
* **[Sidekiq](https://github.com/mperham/sidekiq)** for background jobs

## AWS Deployment

### Prerequisites

1. AWS Account with appropriate permissions
2. AWS CLI installed and configured: `aws configure`
3. Docker installed locally
4. Domain name configured in Route 53
5. SSL certificate in ACM (us-east-1 region for CloudFront)

### Initial Setup

1. **Configure your environment**

   Edit `aws/config/production.env` with your settings:
   ```bash
   ENVIRONMENT_NAME=spree-production
   REGION=ap-southeast-1
   DB_PASSWORD=your-secure-password
   DOMAIN_NAME=yourdomain.com
   HOSTED_ZONE_ID=Z0123456789ABC
   CERTIFICATE_ARN=arn:aws:acm:us-east-1:123456789:certificate/...
   ALERT_EMAIL=your-email@example.com
   ```

2. **Create S3 bucket for CloudFormation templates**
   ```bash
   make create-bucket
   ```

### Full Deployment (Recommended)

Deploy everything in one command:

```bash
make full-deploy
```

This will:
1. Deploy infrastructure (VPC, ECS, RDS, Redis, CloudFront, ALB)
2. Deploy WAF WebACL in us-east-1 and associate with CloudFront
3. Build and push Docker image to ECR
4. Scale ECS services (2 web, 1 worker)
5. Run database setup and migrations
6. Load sample data and CMS content

**Deployment takes ~20-30 minutes.**

### Manual Step-by-Step Deployment

If you prefer to deploy step-by-step:

```bash
# 1. Deploy infrastructure
make deploy

# 2. Deploy WAF for CloudFront (in us-east-1)
make deploy-waf

# 3. Build and push Docker image
make build

# 4. Scale services and deploy
make scale-up

# 5. Initialize database
make setup

# 6. Run migrations
make migrate
```

## Available Make Commands

```bash
make create-bucket    # Create S3 bucket for CloudFormation templates
make deploy           # Deploy/update CloudFormation stack
make deploy-waf       # Deploy WAF WebACL for CloudFront (us-east-1)
make build            # Build and push Docker image to ECR
make scale-up         # Scale ECS services (2 web, 1 worker) and deploy
make update           # Force new deployment with latest image
make setup            # Run DB migrations and seed data
make migrate          # Run database migrations only
make logs             # View application logs
make outputs          # Show CloudFormation stack outputs
make full-deploy      # Complete deployment from scratch (all stages)
make force-cleanup    # Force cleanup stuck resources
make destroy          # Delete the entire stack (requires confirmation)
make help             # Show all available commands
```

## Accessing Your Application

After deployment completes:

### Storefront
Visit: `https://yourdomain.com`

### Admin Dashboard
Visit: `https://yourdomain.com/admin`

**Default Admin Credentials:**
- Email: `admin@yourdomain.com`
- Password: `admin123456` (or value set in `ADMIN_PASSWORD` env var)

**Important:** Change the default password immediately after first login!

## Configuration Files

### Application Configuration
- `aws/config/production.env` - Production environment variables
- `config/environments/production.rb` - Rails production settings

### Infrastructure as Code
- `aws/cloudformation/infrastructure.yaml` - Main infrastructure stack
- `aws/cloudformation/waf-cloudfront.yaml` - WAF WebACL for CloudFront

### Deployment Scripts
- `aws/scripts/full-deploy.sh` - Complete deployment automation
- `aws/scripts/deploy-stack.sh` - Deploy infrastructure
- `aws/scripts/deploy-waf.sh` - Deploy and associate WAF
- `aws/scripts/build-and-push.sh` - Build Docker image
- `aws/scripts/update-services.sh` - Update ECS services
- `aws/scripts/initial-setup.sh` - Database initialization
- `aws/scripts/run-migrations.sh` - Run migrations
- `aws/scripts/load-sample-data.sh` - Load sample products/content
- `aws/scripts/force-cleanup.sh` - Cleanup resources

## Monitoring & Logs

### View Application Logs
```bash
make logs
```

### CloudWatch Dashboard
- Go to AWS Console → CloudWatch → Dashboards
- Select `spree-production-dashboard`
- View metrics for CPU, memory, errors, database connections

### CloudWatch Alarms
Alerts are configured for:
- High CPU utilization (>80%)
- High memory utilization (>85%)
- High error rate (>10 errors/min)
- High database connections (>80%)

Alerts are sent to the email specified in `ALERT_EMAIL`.

### WAF Monitoring
- Go to AWS Console → WAF & Shield (us-east-1 region)
- View blocked requests and security metrics
- Monitor rate limiting and bot blocking

## Scaling

### Manual Scaling
Adjust the desired count in `aws/scripts/update-services.sh`:
```bash
# Edit the script to change from 2/1 to your desired count
WEB_DESIRED_COUNT=4    # Number of web containers
WORKER_DESIRED_COUNT=2 # Number of worker containers
```

Then deploy:
```bash
make update
```

### Auto-Scaling
The infrastructure is configured for auto-scaling based on CPU utilization:
- Web services: Scale between 2-10 instances
- Worker services: Scale between 1-5 instances
- Target CPU: 70%

## Updating Your Application

After making code changes:

```bash
# Build new Docker image and deploy
make build
make update
```

## Database Backups

- **Automated Backups**: Enabled with 7-day retention
- **Manual Snapshots**: Create via AWS Console → RDS → Snapshots

## Destroying the Stack

**WARNING:** This deletes ALL resources including database and S3 data!

```bash
make destroy
```

You will be prompted to type `DELETE` (all caps) to confirm.

## Security Features

### WAF Protection
- AWS Managed Rules (Core, Known Bad Inputs, SQL Injection, Linux OS)
- Rate limiting (2000 requests per 5 minutes per IP)
- Bot blocking (allows legitimate bots like Googlebot)
- Admin paths are excluded from aggressive rules

### Network Security
- Private subnets for application and database
- NAT Gateways for outbound internet access
- Security groups restricting traffic between layers
- SSL/TLS encryption (ACM certificate)

### Application Security
- CSRF protection enabled
- Secure session cookies
- Environment variables via Secrets Manager
- No hardcoded credentials

## Cost Optimization

Estimated monthly cost: **~$200-400/month** depending on traffic

**Cost breakdown:**
- ECS Fargate: ~$50-100
- RDS (db.t4g.medium): ~$70
- ElastiCache (cache.t4g.micro): ~$15
- ALB: ~$20
- NAT Gateways: ~$35
- CloudFront: Variable (first 1TB free)
- WAF: $5 + $1 per million requests
- Data transfer: Variable

**Cost saving tips:**
- Use reserved instances for RDS if long-term
- Scale down dev/staging environments when not in use
- Use CloudFront caching aggressively
- Monitor and optimize S3 storage

## Troubleshooting

### Deployment Issues

**Stack creation fails:**
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name spree-commerce-stack \
  --region ap-southeast-1 | less
```

**ECS tasks not starting:**
```bash
# Check ECS task status
aws ecs describe-services \
  --cluster spree-production-cluster \
  --services spree-production-web \
  --region ap-southeast-1
```

**View container logs:**
```bash
make logs
```

### Application Issues

**422 errors on admin login:**
- Verify you're using correct admin email: `admin@yourdomain.com`
- Check CloudFront is forwarding all necessary headers
- Ensure latest code is deployed: `make build && make update`

**Assets not loading:**
- Check S3 bucket permissions
- Verify CloudFront distribution is active
- Create CloudFront invalidation: `make invalidate`

**Database connection errors:**
- Check RDS instance is running
- Verify security group rules
- Check Secrets Manager has correct credentials

## Local Development

For local development instructions, see [Spree Quickstart guide](https://spreecommerce.org/docs/developer/getting-started/quickstart).

## Customizing

Follow [Customization guide](https://spreecommerce.org/docs/developer/customization/quickstart) to learn how to customize and extend your Spree application.

## Running Tests

This repository is pre-configured for running tests:

```bash
bundle exec rspec
```


## Enterprise Edition

[Spree Enterprise Edition](https://spreecommerce.org/spree-commerce-version-comparison-community-edition-vs-enterprise-edition/) provides:
* Multi-vendor marketplace capabilities
* B2B eCommerce features
* Multi-tenant/white-label SaaS
* Advanced integrations (Stripe Connect, etc.)
* Audit logging
* Enterprise support

[Contact Sales](https://spreecommerce.org/get-started/) to learn more.

## License

Spree Commerce is released under the [BSD-3-Clause License](https://opensource.org/licenses/BSD-3-Clause).
