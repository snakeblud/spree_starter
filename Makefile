.PHONY: deploy build update migrate setup logs destroy force-cleanup check-cleanup full-deploy outputs scale-up help

STACK_NAME = spree-commerce-stack
REGION = ap-southeast-1
ENVIRONMENT = spree-production
ENV ?= production

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
	@echo "Scaling ECS services to desired count..."
	@aws ecs update-service \
		--cluster $(ENVIRONMENT)-cluster \
		--service $(ENVIRONMENT)-web \
		--desired-count 2 \
		--region $(REGION)
	@aws ecs update-service \
		--cluster $(ENVIRONMENT)-cluster \
		--service $(ENVIRONMENT)-worker \
		--desired-count 1 \
		--region $(REGION)
	@echo "Services scaled up. Waiting for services to stabilize..."
	@aws ecs wait services-stable \
		--cluster $(ENVIRONMENT)-cluster \
		--services $(ENVIRONMENT)-web $(ENVIRONMENT)-worker \
		--region $(REGION)
	@echo "✓ Services are stable and running!"

help:
	@echo "Available commands:"
	@echo "  make deploy           - Deploy/update CloudFormation stack"
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