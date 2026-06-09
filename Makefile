TF_DIRS := aws/base_env aws/k8s_addons aws/tenant_resources

tffmt: ## format terraform scripts
	terraform fmt --recursive

check-diff:
	@echo =======uncommitted changes========
	@git diff
	@echo ============= end ================
	@if [ -n "$$(git diff --name-only)" ]; then \
		echo "Error: There are uncommitted changes"; \
		exit 1; \
	fi

tffmt-ci: tffmt check-diff

init-all:
	@set -e; \
	for d in $(TF_DIRS); do \
		(echo "$$d" && cd $$d && terraform init -upgrade -backend=false); \
	done

validate-all: init-all
	@set -e; \
	for d in $(TF_DIRS); do \
		(echo "$$d" && cd $$d && terraform validate); \
	done
