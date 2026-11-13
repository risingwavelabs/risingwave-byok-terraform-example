TF ?= terraform
HEAP_MODULES := aws/modules/heap_storage aws/modules/s3_csi_driver aws/tests/byok_config

TF_DIRS := aws/base_env aws/k8s_addons aws/tenant_resources

tffmt: ## format $(TF) scripts
	$(TF) fmt --recursive

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
		(echo "$$d" && cd $$d && $(TF) init -upgrade -backend=false); \
	done

validate-all: init-all
	@set -e; \
	for d in $(TF_DIRS); do \
		(echo "$$d" && cd $$d && $(TF) validate); \
	done

.PHONY: help test-heap lint-heap
help:
	@echo "tffmt: format Terraform; validate-all: initialize and validate all stages"
	@echo "test-heap: offline heap module tests (Terraform >= 1.7); lint-heap: formatting and validation"

# All tests use mocked providers; no credentials or backend access required.
test-heap:
	@set -e; for d in $(HEAP_MODULES); do \
		$(TF) -chdir=$$d init -backend=false -input=false; \
		$(TF) -chdir=$$d test; \
	done

lint-heap:
	$(TF) fmt -check -recursive
	@set -e; for d in $(HEAP_MODULES); do \
		$(TF) -chdir=$$d validate; \
	done
