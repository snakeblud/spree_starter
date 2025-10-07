# AWS Deployment Scripts

This directory contains scripts for deploying and managing your Spree Commerce application on AWS ECS.

## Scripts Overview

### Main Deployment Scripts

#### `full-deploy.sh`
Complete deployment process from scratch. Use this for initial deployments or major updates.

```bash
./aws/scripts/full-deploy.sh
```

**What it does:**
1. Deploys CloudFormation infrastructure
2. Builds and pushes Docker image
3. Scales ECS services to desired count
4. Waits for services to stabilize
5. Runs database setup
6. Runs database migrations
7. _(Optional)_ Loads sample data

**Note:** Sample data loading is commented out by default to prevent duplicates on re-deployments.

---

#### `build-and-push.sh`
Builds Docker image and pushes to ECR.

```bash
./aws/scripts/build-and-push.sh
```

**Use this when:**
- You've made code changes
- You want to deploy a new version without infrastructure changes

---

### Database Management Scripts

#### `initial-setup.sh`
Sets up the database for the first time.

```bash
./aws/scripts/initial-setup.sh
```

**What it does:**
- Creates database
- Loads schema
- Seeds initial data

**⚠️ Warning:** Only run once during initial setup!

---

#### `run-migrations.sh`
Runs database migrations.

```bash
./aws/scripts/run-migrations.sh
```

**Use this when:**
- You have new migrations to apply
- After pulling code changes that include migrations

---

#### `load-sample-data.sh` ✨ NEW
Loads Spree sample data into your store.

```bash
./aws/scripts/load-sample-data.sh
```

**What it includes:**
- Sample products
- Product categories
- Checkout flow configuration

**⚠️ Warning:**
- Running this multiple times will create duplicate products
- Best for development/staging environments
- Review products before using in production

**Environment Variables:**
```bash
# Skip if products already exist
SKIP_IF_EXISTS=true ./aws/scripts/load-sample-data.sh
```

---

## Common Workflows

### Initial Deployment (Fresh Start)
```bash
# 1. Run full deployment
./aws/scripts/full-deploy.sh

# 2. Load sample data (optional)
./aws/scripts/load-sample-data.sh
```

### Code Updates
```bash
# 1. Build and push new image
./aws/scripts/build-and-push.sh

# 2. Update ECS service (force new deployment)
aws ecs update-service \
  --cluster spree-production-cluster \
  --service spree-production-web \
  --force-new-deployment
```

### Database Migrations
```bash
./aws/scripts/run-migrations.sh
```

### Adding Sample Data (Anytime)
```bash
./aws/scripts/load-sample-data.sh
```

---

## Configuration

All scripts use these default values:
- **Stack Name:** `spree-commerce-stack`
- **Region:** `ap-southeast-1`
- **Environment:** `spree-production`

To override:
```bash
STACK_NAME=my-stack REGION=us-east-1 ./aws/scripts/run-migrations.sh
```

---

## Troubleshooting

### Task Failed
Check ECS task logs:
```bash
aws logs tail /ecs/spree-production --since 30m
```

### Sample Data Already Exists
If you accidentally run sample data twice, you'll need to manually remove duplicate products through the admin panel or database.

### Migration Failed
1. Check logs
2. Fix the migration
3. Re-run: `./aws/scripts/run-migrations.sh`

---

## Auto Scaling

Your ECS service is configured with auto scaling:
- **Min:** 2 tasks
- **Max:** 10 tasks
- **Metrics:** CPU (70%), Memory (80%), ALB Requests (1000/target)

No manual intervention needed! 🎉
