# CoreGrid Mobile — setup, run and test shortcuts.
#
# Component ownership follows doc/software-requirements-specification.md §10
# (main CoreGrid SRS §12). Each test-<x> target runs only that component's tests:
#
#   A  features/assets, features/scan
#   B  features/maintenance, features/notifications
#   C  features/transfers
#   D  app shell, auth, dashboards, features/verification, features/workflows
#      (also owns the shared/ and top-level app tests)
#
# Run `make help` for the full list.

FLUTTER ?= flutter
ENV_FILE ?= .env.json
DEVICE ?=

TEST_A := test/features/assets test/features/scan
TEST_B := test/features/maintenance test/features/notifications
TEST_C := test/features/transfers
TEST_D := test/app test/shared test/widget_test.dart \
          test/features/dashboard test/features/verification test/features/workflows

DEVICE_FLAG := $(if $(DEVICE),-d $(DEVICE),)

.DEFAULT_GOAL := help
.PHONY: help setup env deps clean analyze format format-check \
        test test-A test-B test-C test-D coverage check run run-demo \
        build-apk build-demo

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

## --- Setup -----------------------------------------------------------------

setup: env deps ## First-time setup: create .env.json and fetch packages
	@$(FLUTTER) doctor

env: ## Create .env.json from .env.example if it doesn't exist
	@if [ -f $(ENV_FILE) ]; then \
		echo "$(ENV_FILE) already exists — leaving it alone."; \
	else \
		cp .env.example $(ENV_FILE); \
		echo "Created $(ENV_FILE) — fill in THUNDERID_CLIENT_ID (see doc/setup/thunderid-mobile-client.md)."; \
	fi

deps: ## Fetch Dart/Flutter packages
	$(FLUTTER) pub get

clean: ## Remove build outputs and re-fetch packages
	$(FLUTTER) clean
	$(FLUTTER) pub get

## --- Quality ---------------------------------------------------------------

analyze: ## Static analysis (must report zero issues)
	$(FLUTTER) analyze

format: ## Format all Dart sources
	dart format lib test

format-check: ## Fail if any Dart source isn't formatted
	dart format --output=none --set-exit-if-changed lib test

## --- Tests -----------------------------------------------------------------

test: ## Run the full test suite
	$(FLUTTER) test

test-A: ## Component A tests — assets, scan
	$(FLUTTER) test $(TEST_A)

test-B: ## Component B tests — maintenance, notifications
	$(FLUTTER) test $(TEST_B)

test-C: ## Component C tests — transfers
	$(FLUTTER) test $(TEST_C)

test-D: ## Component D tests — app shell, auth, dashboard, verification, workflows
	$(FLUTTER) test $(TEST_D)

coverage: ## Run all tests with coverage (writes coverage/lcov.info)
	$(FLUTTER) test --coverage

check: analyze test ## What CI runs: analyze + full test suite

## --- Run & build -----------------------------------------------------------

run: ## Run against local backend (DEVICE=<id> to pick a device)
	$(FLUTTER) run $(DEVICE_FLAG) --dart-define-from-file=$(ENV_FILE)

run-demo: ## Run against the demo environment (.env.demo.json)
	$(FLUTTER) run $(DEVICE_FLAG) --dart-define-from-file=.env.demo.json

build-apk: ## Release APK using ENV_FILE (see doc/setup/release-build.md)
	$(FLUTTER) build apk --release --dart-define-from-file=$(ENV_FILE)

build-demo: ## Release APK for the demo environment
	$(FLUTTER) build apk --release --dart-define-from-file=.env.demo.json
