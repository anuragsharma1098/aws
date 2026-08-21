ENV ?= dev
DIR := environments/$(ENV)

.PHONY: bootstrap init plan apply destroy fmt validate

bootstrap:
	cd bootstrap && terraform init && terraform apply -var="environment=$(ENV)"

init:
	cd $(DIR) && terraform init -backend-config=backend.hcl

plan:
	cd $(DIR) && terraform plan

apply:
	cd $(DIR) && terraform apply

destroy:
	cd $(DIR) && terraform destroy

fmt:
	terraform fmt -recursive

validate:
	cd $(DIR) && terraform validate
