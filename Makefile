# MCP Atlassian - Container and OpenShift Deployment Makefile
# Usage: make help

# Configuration
CONTAINER_RUNTIME ?= $(shell command -v podman || command -v docker || echo "container-runtime-not-found")
IMAGE_NAME ?= mcp-atlassian
IMAGE_TAG ?= latest
REGISTRY ?= quay.io
REGISTRY_USERNAME ?= $(USER)
FULL_IMAGE := $(REGISTRY)/$(REGISTRY_USERNAME)/$(IMAGE_NAME):$(IMAGE_TAG)

# OpenShift Configuration
NAMESPACE ?= default
DEPLOY_DIR := deploy
TEMPLATES_DIR := $(DEPLOY_DIR)/templates
ARTIFACTS_DIR := $(DEPLOY_DIR)/artifacts

# Required for secrets deployment
JIRA_URL ?=

# Authentication method selection (choose one)
# For API Token authentication (Cloud):
JIRA_USERNAME ?=
JIRA_API_TOKEN ?=
# For Personal Access Token (Server/DC or Cloud):
JIRA_PERSONAL_TOKEN ?=

# Optional Confluence configuration (not required by default)
CONFLUENCE_URL ?=
CONFLUENCE_USERNAME ?=
CONFLUENCE_API_TOKEN ?=
CONFLUENCE_PERSONAL_TOKEN ?=

# Optional configuration with defaults
MCP_PORT ?= 8000
TRANSPORT ?= streamable-http
READ_ONLY_MODE ?= true
MCP_VERBOSE ?= true
ENABLE_CONFLUENCE ?= false

.PHONY: help
help: ## Show this help message
	@echo "MCP Atlassian - Container and OpenShift Deployment"
	@echo ""
	@echo "Container targets:"
	@echo "  build              Build container image"
	@echo "  push               Push image to registry"
	@echo "  run                Run container locally"
	@echo "  clean              Remove local images"
	@echo ""
	@echo "OpenShift targets:"
	@echo "  deploy             Deploy to OpenShift (requires secrets)"
	@echo "  deploy-secrets     Deploy secrets from template"
	@echo "  deploy-app         Deploy application resources"
	@echo "  undeploy           Remove all resources from OpenShift"
	@echo "  generate-manifests Generate manifests from templates"
	@echo ""
	@echo "Configuration:"
	@echo "  CONTAINER_RUNTIME  Container runtime (podman/docker, auto-detected)"
	@echo "  IMAGE_NAME         Image name (default: mcp-atlassian)"
	@echo "  IMAGE_TAG          Image tag (default: latest)"
	@echo "  REGISTRY           Container registry (default: quay.io)"
	@echo "  REGISTRY_USERNAME  Registry username (default: $$USER)"
	@echo "  NAMESPACE          OpenShift namespace (default: default)"
	@echo ""
	@echo "Required for deployment:"
	@echo "  JIRA_URL           Jira instance URL"
	@echo ""
	@echo "Authentication (choose one method):"
	@echo "  JIRA_USERNAME + JIRA_API_TOKEN     API Token authentication (Cloud)"
	@echo "  JIRA_PERSONAL_TOKEN                Personal Access Token (Server/DC or Cloud)"
	@echo ""
	@echo "Optional Confluence (set ENABLE_CONFLUENCE=true):"
	@echo "  CONFLUENCE_URL     Confluence instance URL"
	@echo "  CONFLUENCE_USERNAME + CONFLUENCE_API_TOKEN  OR  CONFLUENCE_PERSONAL_TOKEN"
	@echo ""
	@echo "Configuration defaults:"
	@echo "  READ_ONLY_MODE=true    Security default (set to false for write operations)"
	@echo "  ENABLE_CONFLUENCE=false  Jira-only by default"
	@echo ""
	@echo "Examples:"
	@echo "  # PAT authentication (Server/DC or Cloud)"
	@echo "  make deploy JIRA_URL=https://jira.company.com JIRA_PERSONAL_TOKEN=xxx"
	@echo "  # API Token authentication (Cloud)"
	@echo "  make deploy JIRA_URL=https://company.atlassian.net JIRA_USERNAME=user@company.com JIRA_API_TOKEN=xxx"
	@echo "  # With Confluence enabled"
	@echo "  make deploy ENABLE_CONFLUENCE=true JIRA_URL=... CONFLUENCE_URL=... JIRA_PERSONAL_TOKEN=xxx CONFLUENCE_PERSONAL_TOKEN=yyy"

# Container targets
.PHONY: build
build: ## Build container image
	@echo "Building $(FULL_IMAGE) with $(CONTAINER_RUNTIME)..."
	$(CONTAINER_RUNTIME) build -t $(IMAGE_NAME):$(IMAGE_TAG) -t $(FULL_IMAGE) .

.PHONY: push
push: build ## Push image to registry
	@echo "Pushing $(FULL_IMAGE)..."
	$(CONTAINER_RUNTIME) push $(FULL_IMAGE)

.PHONY: run
run: ## Run container locally
	@echo "Running $(IMAGE_NAME):$(IMAGE_TAG) on port $(MCP_PORT)..."
	$(CONTAINER_RUNTIME) run --rm -it \
		-p $(MCP_PORT):$(MCP_PORT) \
		-e TRANSPORT=$(TRANSPORT) \
		-e PORT=$(MCP_PORT) \
		-e READ_ONLY_MODE=$(READ_ONLY_MODE) \
		-e MCP_VERBOSE=$(MCP_VERBOSE) \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		--transport $(TRANSPORT) --port $(MCP_PORT) -v

.PHONY: clean
clean: ## Remove local container images
	@echo "Removing local images..."
	-$(CONTAINER_RUNTIME) rmi $(IMAGE_NAME):$(IMAGE_TAG) $(FULL_IMAGE)

# OpenShift targets
.PHONY: check-oc
check-oc:
	@command -v oc >/dev/null 2>&1 || { echo "Error: oc (OpenShift CLI) is required but not installed."; exit 1; }

.PHONY: check-deploy-vars
check-deploy-vars:
	@if [ -z "$(JIRA_URL)" ]; then \
		echo "Error: JIRA_URL is required for deployment."; \
		echo "Usage: make deploy JIRA_URL=https://jira.company.com JIRA_PERSONAL_TOKEN=your_token"; \
		exit 1; \
	fi
	@if [ -z "$(JIRA_API_TOKEN)" ] && [ -z "$(JIRA_PERSONAL_TOKEN)" ]; then \
		echo "Error: Either JIRA_API_TOKEN (with JIRA_USERNAME) or JIRA_PERSONAL_TOKEN is required."; \
		echo "For API Token: make deploy JIRA_URL=... JIRA_USERNAME=user@company.com JIRA_API_TOKEN=your_token"; \
		echo "For PAT: make deploy JIRA_URL=... JIRA_PERSONAL_TOKEN=your_token"; \
		exit 1; \
	fi
	@if [ -n "$(JIRA_API_TOKEN)" ] && [ -z "$(JIRA_USERNAME)" ]; then \
		echo "Error: JIRA_USERNAME is required when using JIRA_API_TOKEN."; \
		echo "Usage: make deploy JIRA_URL=... JIRA_USERNAME=user@company.com JIRA_API_TOKEN=your_token"; \
		exit 1; \
	fi
	@if [ "$(ENABLE_CONFLUENCE)" = "true" ]; then \
		if [ -z "$(CONFLUENCE_URL)" ]; then \
			echo "Error: CONFLUENCE_URL is required when ENABLE_CONFLUENCE=true."; \
			echo "Usage: make deploy ENABLE_CONFLUENCE=true CONFLUENCE_URL=https://confluence.company.com ..."; \
			exit 1; \
		fi; \
		if [ -z "$(CONFLUENCE_API_TOKEN)" ] && [ -z "$(CONFLUENCE_PERSONAL_TOKEN)" ]; then \
			echo "Error: Either CONFLUENCE_API_TOKEN (with CONFLUENCE_USERNAME) or CONFLUENCE_PERSONAL_TOKEN is required when ENABLE_CONFLUENCE=true."; \
			exit 1; \
		fi; \
		if [ -n "$(CONFLUENCE_API_TOKEN)" ] && [ -z "$(CONFLUENCE_USERNAME)" ]; then \
			echo "Error: CONFLUENCE_USERNAME is required when using CONFLUENCE_API_TOKEN."; \
			exit 1; \
		fi; \
	fi

.PHONY: setup-deploy-dir
setup-deploy-dir:
	@echo "Setting up deployment directories..."
	@mkdir -p $(ARTIFACTS_DIR)

.PHONY: generate-manifests
generate-manifests: setup-deploy-dir check-deploy-vars ## Generate OpenShift manifests from templates
	@echo "Generating manifests for namespace $(NAMESPACE)..."
	
	# Generate secrets.yaml
	@sed 's|{{NAMESPACE}}|$(NAMESPACE)|g; \
		s|{{JIRA_URL}}|$(JIRA_URL)|g; \
		s|{{JIRA_USERNAME}}|$(JIRA_USERNAME)|g; \
		s|{{JIRA_API_TOKEN}}|$(JIRA_API_TOKEN)|g; \
		s|{{JIRA_PERSONAL_TOKEN}}|$(JIRA_PERSONAL_TOKEN)|g; \
		s|{{CONFLUENCE_URL}}|$(CONFLUENCE_URL)|g; \
		s|{{CONFLUENCE_USERNAME}}|$(CONFLUENCE_USERNAME)|g; \
		s|{{CONFLUENCE_API_TOKEN}}|$(CONFLUENCE_API_TOKEN)|g; \
		s|{{CONFLUENCE_PERSONAL_TOKEN}}|$(CONFLUENCE_PERSONAL_TOKEN)|g; \
		s|{{ENABLE_CONFLUENCE}}|$(ENABLE_CONFLUENCE)|g' \
		$(TEMPLATES_DIR)/secrets.yaml.template > $(ARTIFACTS_DIR)/secrets.yaml
	
	# Generate deployment.yaml
	@sed 's|{{NAMESPACE}}|$(NAMESPACE)|g; \
		s|{{IMAGE}}|$(FULL_IMAGE)|g; \
		s|{{MCP_PORT}}|$(MCP_PORT)|g; \
		s|{{TRANSPORT}}|$(TRANSPORT)|g; \
		s|{{READ_ONLY_MODE}}|$(READ_ONLY_MODE)|g; \
		s|{{MCP_VERBOSE}}|$(MCP_VERBOSE)|g; \
		s|{{ENABLE_CONFLUENCE}}|$(ENABLE_CONFLUENCE)|g' \
		$(TEMPLATES_DIR)/deployment.yaml.template > $(ARTIFACTS_DIR)/deployment.yaml
	
	# Generate service.yaml
	@sed 's|{{NAMESPACE}}|$(NAMESPACE)|g; \
		s|{{MCP_PORT}}|$(MCP_PORT)|g' \
		$(TEMPLATES_DIR)/service.yaml.template > $(ARTIFACTS_DIR)/service.yaml
	
	# Generate route.yaml
	@sed 's|{{NAMESPACE}}|$(NAMESPACE)|g' \
		$(TEMPLATES_DIR)/route.yaml.template > $(ARTIFACTS_DIR)/route.yaml
	
	@echo "Manifests generated in $(ARTIFACTS_DIR)/"

.PHONY: deploy-secrets
deploy-secrets: check-oc generate-manifests ## Deploy secrets to OpenShift
	@echo "Deploying secrets to namespace $(NAMESPACE)..."
	oc apply -f $(ARTIFACTS_DIR)/secrets.yaml -n $(NAMESPACE)

.PHONY: deploy-app
deploy-app: check-oc generate-manifests ## Deploy application resources to OpenShift
	@echo "Deploying application to namespace $(NAMESPACE)..."
	oc apply -f $(ARTIFACTS_DIR)/deployment.yaml -n $(NAMESPACE)
	oc apply -f $(ARTIFACTS_DIR)/service.yaml -n $(NAMESPACE)
	oc apply -f $(ARTIFACTS_DIR)/route.yaml -n $(NAMESPACE)
	@echo "Waiting for deployment to be ready..."
	oc rollout status deployment/mcp-atlassian -n $(NAMESPACE) --timeout=300s

.PHONY: deploy
deploy: check-oc push deploy-secrets deploy-app ## Full deployment (push image + deploy secrets + deploy app)
	@echo "Deployment complete!"
	@echo "Getting route URL..."
	@oc get route mcp-atlassian -n $(NAMESPACE) -o jsonpath='{.spec.host}' 2>/dev/null || echo "Route not found"

.PHONY: undeploy
undeploy: check-oc ## Remove all resources from OpenShift
	@echo "Removing MCP Atlassian from namespace $(NAMESPACE)..."
	-oc delete route mcp-atlassian -n $(NAMESPACE)
	-oc delete service mcp-atlassian -n $(NAMESPACE)
	-oc delete deployment mcp-atlassian -n $(NAMESPACE)
	-oc delete secret mcp-atlassian-secrets -n $(NAMESPACE)
	@echo "Undeployment complete."

.PHONY: status
status: check-oc ## Show deployment status
	@echo "MCP Atlassian status in namespace $(NAMESPACE):"
	@echo "================================"
	-oc get deployment mcp-atlassian -n $(NAMESPACE)
	@echo ""
	-oc get pods -l app=mcp-atlassian -n $(NAMESPACE)
	@echo ""
	-oc get service mcp-atlassian -n $(NAMESPACE)
	@echo ""
	-oc get route mcp-atlassian -n $(NAMESPACE)

.PHONY: logs
logs: check-oc ## Show application logs
	oc logs -l app=mcp-atlassian -n $(NAMESPACE) --tail=100 -f

# Development helpers
.PHONY: dev-setup
dev-setup: ## Set up local development environment
	@echo "Setting up development environment..."
	uv sync --frozen --all-extras --dev
	pre-commit install

.PHONY: test
test: ## Run tests
	uv run pytest

.PHONY: lint
lint: ## Run code quality checks
	pre-commit run --all-files
