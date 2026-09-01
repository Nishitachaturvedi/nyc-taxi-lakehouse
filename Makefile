# Makefile — one-word commands for common project tasks.
# Run `make help` to list targets. NOTE: recipe lines are TAB-indented (Make requires tabs).

TF_DIR := terraform

.PHONY: help tf-bootstrap tf-init tf-plan tf-apply tf-destroy tf-fmt tf-validate teardown download-data

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

tf-bootstrap: ## One-time: create the remote-state bucket + lock table
	cd $(TF_DIR)/bootstrap && terraform init && terraform apply

tf-init: ## Initialize the main Terraform config
	cd $(TF_DIR) && terraform init

tf-plan: ## Preview infrastructure changes
	cd $(TF_DIR) && terraform plan

tf-apply: ## Create/update infrastructure
	cd $(TF_DIR) && terraform apply

tf-destroy: ## Destroy all main infrastructure
	cd $(TF_DIR) && terraform destroy

tf-fmt: ## Format all Terraform files
	cd $(TF_DIR) && terraform fmt -recursive

tf-validate: ## Validate Terraform without AWS (offline)
	cd $(TF_DIR) && terraform init -backend=false && terraform validate

teardown: tf-destroy ## Destroy everything, then verify nothing is left billing
	bash scripts/teardown_verify.sh

download-data: ## Download NYC TLC data into the lake's bronze/ prefix
	bash scripts/download_tlc_data.sh "$$(cd $(TF_DIR) && terraform output -raw lake_bucket)"
