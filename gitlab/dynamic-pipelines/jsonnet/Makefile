help:
	@printf "Usage: make [target] [VARIABLE=value]\nTargets:\n"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

create-component-es-pipeline: ## Create elasticsearch component pipeline
	@$(if $(TF_COMPONENT),,$(error Must set TF_COMPONENT))
	@$(if $(ENABLED_JOBS),,$(error Must set ENABLED_JOBS))
	@ENV_BASE_DIR=environments elasticsearch/.ci/scripts/generate-component-pipeline.sh
	@cat $(TF_COMPONENT)/generated-component-pipeline.yml

create-components-pipeline: ## Create components pipeline
	@$(if $(TF_COMPONENT),,$(error Must set TF_COMPONENT e.g. rds))
	@$(if $(REGION),,$(error Must set REGION e.g. eu-west-1))
	@$(if $(ENV),,$(error Must set ENV e.g. sandbox))
	@$(if $(ENABLED_JOBS),,$(error Must set ENABLED_JOBS e.g. plan,apply))
	@ENV_BASE_DIR=environments CI_PROJECT_DIR=$(shell pwd) .gitlab/scripts/build-child-pipeline.sh
