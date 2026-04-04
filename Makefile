.PHONY: help build push lint clean login

REGISTRY ?= docker.io
REPOSITORY ?= anisimovdk
CHART_DIR := .
DIST_DIR := dist
CHART_NAME := $(shell awk '/^name:/ {print $$2; exit}' Chart.yaml)
CHART_VERSION := $(shell awk '/^version:/ {print $$2; exit}' Chart.yaml)

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

lint: ## Lint the chart
	@echo "Linting $(CHART_NAME)..."
	@helm lint $(CHART_DIR)

build: $(DIST_DIR) lint ## Build (package) the chart
	@echo "Packaging $(CHART_NAME) $(CHART_VERSION)..."
	@helm package $(CHART_DIR) -d $(DIST_DIR)
	@echo "Chart packaged successfully"

login: ## Login to Helm OCI registry (requires DOCKER_PASSWORD, DOCKER_USERNAME defaults to REPOSITORY)
	@if [ -z "$(DOCKER_PASSWORD)" ]; then \
		echo "Error: DOCKER_PASSWORD must be set"; \
		exit 1; \
	fi
	@USERNAME=$${DOCKER_USERNAME:-$(REPOSITORY)}; \
		echo "$(DOCKER_PASSWORD)" | helm registry login $(REGISTRY) --username $$USERNAME --password-stdin
	@echo "Logged in to $(REGISTRY)"

push: build ## Build and push the chart to the OCI registry
	@CHART_PACKAGE=$(DIST_DIR)/$(CHART_NAME)-$(CHART_VERSION).tgz; \
		if [ ! -f $$CHART_PACKAGE ]; then \
			echo "Error: Chart package $$CHART_PACKAGE not found"; \
			exit 1; \
		fi; \
		echo "Pushing $(CHART_NAME) $(CHART_VERSION) to $(REGISTRY)/$(REPOSITORY)..."; \
		helm push $$CHART_PACKAGE oci://$(REGISTRY)/$(REPOSITORY)
	@echo "Chart pushed successfully"

clean: ## Remove build artifacts
	@echo "Cleaning up..."
	@rm -rf $(DIST_DIR)
	@echo "Cleaned $(DIST_DIR)"
