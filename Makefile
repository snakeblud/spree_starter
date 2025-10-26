.PHONY: deploy build update migrate setup logs destroy force-cleanup check-cleanup full-deploy outputs scale-up create-bucket deploy-waf help

STACK_NAME = spree-commerce-stack
REGION = ap-southeast-1
ENVIRONMENT = spree-production
ENV ?= production
ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
S3_BUCKET = cf-templates-$(ACCOUNT_ID)-$(REGION)

deploy:
	@chmod +x aws/scripts/deploy-stack.sh
	@aws/scripts/deploy-stack.sh $(ENV)

build:
	@chmod +x aws/scripts/build-and-push.sh
	@aws/scripts/build-and-push.sh

update:
	@chmod +x aws/scripts/update-services.sh
	@ENVIRONMENT=$(ENVIRONMENT) aws/scripts/update-services.sh

migrate:
	@chmod +x aws/scripts/run-migrations.sh
	@ENVIRONMENT=$(ENVIRONMENT) aws/scripts/run-migrations.sh

setup:
	@chmod +x aws/scripts/initial-setup.sh
	@ENVIRONMENT=$(ENVIRONMENT) aws/scripts/initial-setup.sh

logs:
	@aws logs tail /ecs/$(ENVIRONMENT) --follow --region $(REGION)

outputs:
	@aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--region $(REGION) \
		--query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
		--output table

force-cleanup:
	@chmod +x aws/scripts/force-cleanup.sh
	@aws/scripts/force-cleanup.sh

check-cleanup:
	@echo "Checking for remaining resources..."
	@aws elasticache describe-replication-groups --region $(REGION) \
		--query "ReplicationGroups[?starts_with(ReplicationGroupId, '$(ENVIRONMENT)')].ReplicationGroupId" || true
	@aws rds describe-db-instances --region $(REGION) \
		--query "DBInstances[?starts_with(DBInstanceIdentifier, '$(ENVIRONMENT)')].DBInstanceIdentifier" || true
	@aws ecs list-clusters --region $(REGION) \
		--query "clusterArns[?contains(@, '$(ENVIRONMENT)')]" || true

destroy:
	@echo "========================================="
	@echo "WARNING: This will destroy ALL resources!"
	@echo "========================================="
	@echo "This will delete:"
	@echo "  - S3 bucket and all objects"
	@echo "  - ECR repository and Docker images"
	@echo "  - ECS cluster, services, and tasks"
	@echo "  - RDS database (primary + read replica)"
	@echo "  - ElastiCache Redis cluster"
	@echo "  - All Secrets Manager secrets"
	@echo "  - SNS topics and subscriptions"
	@echo "  - CloudWatch dashboard and alarms"
	@echo "  - CloudWatch log groups"
	@echo "  - VPC and all networking resources"
	@echo "  - CloudFront distribution"
	@echo "  - WAF WebACL"
	@echo "========================================="
	@read -p "Type 'DELETE' (all caps) to confirm: " CONFIRM; \
	if [ "$$CONFIRM" = "DELETE" ]; then \
		echo "Starting cleanup process..."; \
		make force-cleanup; \
		echo ""; \
		echo "Deleting CloudFormation stack..."; \
		aws cloudformation delete-stack --stack-name $(STACK_NAME) --region $(REGION); \
		echo ""; \
		echo "Stack deletion initiated. Monitoring progress..."; \
		aws cloudformation wait stack-delete-complete --stack-name $(STACK_NAME) --region $(REGION) && \
		echo "" && \
		echo "=========================================" && \
		echo "✓ Stack deleted successfully!" && \
		echo "=========================================" || \
		echo "Stack deletion in progress. Check AWS Console for status."; \
	else \
		echo "Cancelled. (You must type 'DELETE' to confirm)"; \
	fi

full-deploy:
	@chmod +x aws/scripts/full-deploy.sh
	@aws/scripts/full-deploy.sh

scale-up:
	@chmod +x aws/scripts/update-services.sh
	@ENVIRONMENT=$(ENVIRONMENT) aws/scripts/update-services.sh

create-bucket:
	@echo "Creating S3 bucket for CloudFormation templates..."
	@echo "Bucket name: $(S3_BUCKET)"
	@aws s3 mb s3://$(S3_BUCKET) --region $(REGION) 2>/dev/null || echo "Bucket already exists or error occurred"
	@echo "Enabling versioning on bucket..."
	@aws s3api put-bucket-versioning \
		--bucket $(S3_BUCKET) \
		--versioning-configuration Status=Enabled \
		--region $(REGION)
	@echo "✓ S3 bucket ready: s3://$(S3_BUCKET)"

deploy-waf:
	@chmod +x aws/scripts/deploy-waf.sh
	@aws/scripts/deploy-waf.sh

help:
	@echo "Available commands:"
	@echo "  make create-bucket    - Create S3 bucket for CloudFormation templates"
	@echo "  make deploy           - Deploy/update CloudFormation stack"
	@echo "  make deploy-waf       - Deploy WAF WebACL for CloudFront (us-east-1)"
	@echo "  make build            - Build and push Docker image"
	@echo "  make scale-up         - Scale ECS services to desired count (2 web, 1 worker)"
	@echo "  make setup            - Run DB migrations and seed data (includes store config)"
	@echo "  make update           - Force new deployment of ECS services"
	@echo "  make migrate          - Run database migrations only"
	@echo "  make logs             - View application logs"
	@echo "  make outputs          - Show CloudFormation outputs"
	@echo "  make full-deploy      - Complete deployment from scratch (all stages)"
	@echo "  make force-cleanup    - Force cleanup stuck resources"
	@echo "  make destroy          - Delete the entire stack"