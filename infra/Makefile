# infra/Makefile - thin wrapper around the Terraform commands in README.md, nothing this
# doesn't already do by hand. Requires GNU Make (not bundled with Git Bash by default - see
# README.md's "Makefile" section for how to get it on Windows) and the AWS CLI credentials
# Terraform itself needs.
#
# Usage:
#   make plan ENV=dev
#   make apply ENV=prd
#   make bootstrap-apply
#   make global-plan
#   make help

SHELL := /bin/bash
ENV   ?= dev
ENVIRONMENTS := dev qa prd

ENV_DIR       := environments/$(ENV)
BOOTSTRAP_DIR := bootstrap
GLOBAL_DIR    := global

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo "Usage: make <target> [ENV=dev|qa|prd]  (ENV defaults to dev)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

## --- Environment targets (dev/qa/prd) ---

.PHONY: check-env
check-env:
	@if [ ! -d "$(ENV_DIR)" ]; then \
		echo "Unknown ENV '$(ENV)' - expected one of: $(ENVIRONMENTS)"; \
		exit 1; \
	fi

.PHONY: init
init: check-env ## Init an environment's S3 backend
	cd $(ENV_DIR) && terraform init -backend-config=backend.hcl

.PHONY: plan
plan: check-env ## Plan an environment
	cd $(ENV_DIR) && terraform plan

.PHONY: apply
apply: check-env ## Apply an environment
	cd $(ENV_DIR) && terraform apply

.PHONY: destroy
destroy: check-env ## Destroy an environment - prompts for the env name as confirmation
	@echo "About to DESTROY the '$(ENV)' environment. This cannot be undone."
	@read -p "Type '$(ENV)' to confirm: " confirm && [ "$$confirm" = "$(ENV)" ] || (echo "Aborted." && exit 1)
	cd $(ENV_DIR) && terraform destroy

.PHONY: output
output: check-env ## Show an environment's outputs
	cd $(ENV_DIR) && terraform output

.PHONY: validate
validate: check-env ## Validate an environment's config
	cd $(ENV_DIR) && terraform validate

## --- Bootstrap: once per AWS account, before anything else ---

.PHONY: bootstrap-init
bootstrap-init: ## Init the bootstrap config (local state - it creates its own backend)
	cd $(BOOTSTRAP_DIR) && terraform init

.PHONY: bootstrap-plan
bootstrap-plan: ## Plan the bootstrap config
	cd $(BOOTSTRAP_DIR) && terraform plan

.PHONY: bootstrap-apply
bootstrap-apply: ## Apply the bootstrap config (creates the state bucket + lock table + CMK)
	cd $(BOOTSTRAP_DIR) && terraform apply
	@echo ""
	@echo "Copy the state_bucket_name / lock_table_name outputs above into every backend.hcl."

## --- Global: once per AWS account, after bootstrap ---

.PHONY: global-init
global-init: ## Init the global config's backend
	cd $(GLOBAL_DIR) && terraform init -backend-config=backend.hcl

.PHONY: global-plan
global-plan: ## Plan the global config
	cd $(GLOBAL_DIR) && terraform plan

.PHONY: global-apply
global-apply: ## Apply the global config (ECR repos + CloudTrail)
	cd $(GLOBAL_DIR) && terraform apply

## --- Whole-repo housekeeping ---

.PHONY: fmt
fmt: ## Format every .tf file under infra/
	terraform fmt -recursive .

.PHONY: fmt-check
fmt-check: ## Fail if any .tf file is unformatted (CI-friendly, no changes written)
	terraform fmt -recursive -check -diff .

.PHONY: validate-all
validate-all: ## init -backend=false + validate for every root config (bootstrap, global, all environments)
	@for d in $(BOOTSTRAP_DIR) $(GLOBAL_DIR) $(foreach e,$(ENVIRONMENTS),environments/$(e)); do \
		echo "==> $$d"; \
		(cd $$d && terraform init -input=false -backend=false -upgrade >/dev/null && terraform validate) || exit 1; \
	done

.PHONY: clean
clean: ## Remove local .terraform provider caches (safe - state itself lives in S3)
	find . -type d -name ".terraform" -prune -exec rm -rf {} +
