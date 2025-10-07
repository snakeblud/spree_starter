.PHONY: deploy build update migrate setup logs destroy force-cleanup check-cleanup full-deploy outputs help

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
	@echo "WARNING: This will destroy all resources!"
	@read -p "Are you sure? Type 'yes' to confirm: " CONFIRM; \
	if [ "$$CONFIRM" = "yes" ]; then \
		make force-cleanup; \
		aws cloudformation delete-stack --stack-name $(STACK_NAME) --region $(REGION); \
		echo "Stack deletion initiated..."; \
	else \
		echo "Cancelled."; \
	fi

full-deploy:
	@chmod +x aws/scripts/full-deploy.sh
	@aws/scripts/full-deploy.sh

help:
	@echo "Available commands:"
	@echo "  make deploy           - Deploy CloudFormation stack with services at desired count"
	@echo "  make build            - Build and push Docker image"
	@echo "  make setup            - Run DB migrations and seed data (includes store config)"
	@echo "  make update           - Force new deployment of ECS services"
	@echo "  make migrate          - Run database migrations only"
	@echo "  make logs             - View application logs"
	@echo "  make outputs          - Show CloudFormation outputs"
	@echo "  make full-deploy      - Complete deployment from scratch"
	@echo "  make force-cleanup    - Force cleanup stuck resources"
	@echo "  make destroy          - Delete the entire stack"