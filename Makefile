COMPOSE = docker compose
ENV_FILE = --env-file .env
BASE = -f compose.yaml
DEV = $(BASE) -f infra/compose/compose.dev.yaml
TEST = $(BASE) -f infra/compose/compose.test.yaml
PROD = $(BASE) -f infra/compose/compose.prod.yaml
IMAGES = $(BASE) -f infra/compose/compose.images.yaml
STAGING_IMAGES = $(IMAGES) -f infra/compose/compose.staging.yaml
PROD_IMAGES = $(IMAGES) -f infra/compose/compose.prod.yaml
STAGING_PROJECT = -p alfa-hack-staging
IMAGE_PREFIX ?= ghcr.io/wannasleeprightnow
IMAGE_TAG ?=

.PHONY: help setup dev dev-down logs logs-test logs-prod test test-backend test-frontend prod prod-images prod-down prod-cert-init prod-cert-renew staging-images check-image-tag check-staging-mode check-production-mode backend-test frontend-test frontend-build backend-lint frontend-lint backend-quality frontend-quality format-check lint

help: ## Show available commands
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "%-22s %s\n", $$1, $$2}'

setup: ## Create local environment file from the example
	@test -f .env || cp .env.example .env

dev: setup ## Run the development stack (HTTP)
	$(COMPOSE) $(ENV_FILE) $(DEV) up --build

dev-down: ## Stop the development stack
	$(COMPOSE) $(ENV_FILE) $(DEV) down

logs: setup ## Follow development stack logs; optionally set SERVICE=backend|frontend|nginx
	$(COMPOSE) $(ENV_FILE) $(DEV) logs --follow $(SERVICE)

logs-test: setup ## Follow test stack logs; optionally set SERVICE=backend|frontend|nginx
	$(COMPOSE) $(ENV_FILE) $(TEST) logs --follow $(SERVICE)

logs-prod: setup ## Follow production stack logs; optionally set SERVICE=backend|frontend|nginx
	$(COMPOSE) $(ENV_FILE) $(PROD) logs --follow $(SERVICE)

test: setup ## Run backend and frontend checks in the test environment
	$(MAKE) backend-test
	$(MAKE) frontend-test
	$(COMPOSE) $(ENV_FILE) $(TEST) config --quiet

test-backend: backend-test ## Alias for backend tests

backend-test: ## Run backend unit/API tests with uv
	cd backend && uv run --group dev pytest

test-frontend: frontend-test ## Alias for frontend tests

frontend-test: ## Run frontend tests
	cd frontend && npm ci && npm test -- --run && npm run typecheck && npm run build

frontend-build: ## Build frontend production assets
	cd frontend && npm ci && npm run build

lint: ## Run backend and frontend linters
	$(MAKE) backend-lint
	$(MAKE) frontend-lint

backend-lint: ## Run the backend linter
	cd backend && uv run --group dev ruff check .

frontend-lint: ## Run the frontend linter
	cd frontend && npm ci && npm run lint

format-check: ## Check backend and frontend formatting
	cd backend && uv run --group dev ruff format --check .
	cd frontend && npm ci && npm run format:check

backend-quality: ## Run backend linting, formatting, and tests
	cd backend && uv run --group dev ruff check .
	cd backend && uv run --group dev ruff format --check .
	cd backend && uv run --group dev pytest

frontend-quality: ## Run frontend formatting, linting, type checks, tests, and build
	cd frontend && npm ci && npm run format:check && npm run lint && npm run typecheck && npm test -- --run && npm run build

prod: setup ## Run the production stack (requires domain and certificate)
	@domain="$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^CERTBOT_DOMAIN=//p')"; \
	 test -n "$$domain" && test "$$domain" != "example.com" && \
	 test -s "letsencrypt/live/$$domain/fullchain.pem" && \
	 test -s "letsencrypt/live/$$domain/privkey.pem" || \
	 (echo 'Configure CERTBOT_DOMAIN and run make prod-cert-init first' >&2; exit 1)
	$(COMPOSE) $(ENV_FILE) $(PROD) up --build -d

check-image-tag:
	@printf '%s\n' "$(IMAGE_TAG)" | grep -Eq '^[0-9a-f]{40}$$' || (echo 'Set IMAGE_TAG to a 40-character lowercase commit SHA' >&2; exit 1)

check-staging-mode:
	@test "$$(cat .deployment-mode 2>/dev/null)" = "staging" || (echo 'Set .deployment-mode to staging before deploying staging' >&2; exit 1)

check-production-mode:
	@test "$$(cat .deployment-mode 2>/dev/null)" = "production" || (echo 'Set .deployment-mode to production before deploying production' >&2; exit 1)

staging-images: setup check-image-tag check-staging-mode ## Run staging from published GHCR images
	@containers="$$($(COMPOSE) $(ENV_FILE) $(PROD_IMAGES) ps -q)" || exit 1; test -z "$$containers" || (echo 'Stop production before deploying staging' >&2; exit 1)
	IMAGE_PREFIX="$(IMAGE_PREFIX)" IMAGE_TAG="$(IMAGE_TAG)" $(COMPOSE) $(STAGING_PROJECT) $(ENV_FILE) $(STAGING_IMAGES) up --pull always -d --remove-orphans --wait
	@printf '%s\n' "$(IMAGE_TAG)" > .staging-image-tag

prod-images: setup check-image-tag check-production-mode ## Run production from published GHCR images
	@containers="$$($(COMPOSE) $(STAGING_PROJECT) $(ENV_FILE) $(STAGING_IMAGES) ps -q)" || exit 1; test -z "$$containers" || (echo 'Stop staging before deploying production' >&2; exit 1)
	@domain="$$(IMAGE_PREFIX="$(IMAGE_PREFIX)" IMAGE_TAG="$(IMAGE_TAG)" $(COMPOSE) $(ENV_FILE) $(PROD_IMAGES) config --environment | sed -n 's/^CERTBOT_DOMAIN=//p')"; \
	 test -n "$$domain" && test "$$domain" != "example.com" && \
	 test -s "letsencrypt/live/$$domain/fullchain.pem" && \
	 test -s "letsencrypt/live/$$domain/privkey.pem" || \
	 (echo 'Configure CERTBOT_DOMAIN and run make prod-cert-init first' >&2; exit 1)
	IMAGE_PREFIX="$(IMAGE_PREFIX)" IMAGE_TAG="$(IMAGE_TAG)" $(COMPOSE) $(ENV_FILE) $(PROD_IMAGES) up --pull always -d --remove-orphans --wait
	@printf '%s\n' "$(IMAGE_TAG)" > .production-image-tag

prod-down: ## Stop the production stack without deleting certificate data
	$(COMPOSE) $(ENV_FILE) $(PROD) down

prod-cert-init: setup ## Obtain the initial Let's Encrypt certificate and enable HTTPS
	@domain="$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^CERTBOT_DOMAIN=//p')"; \
	 email="$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^LETSENCRYPT_EMAIL=//p')"; \
	 test -n "$$domain" && test "$$domain" != "example.com" && \
	 test -n "$$email" && test "$$email" != "admin@example.com" || \
	 (echo 'Set a real CERTBOT_DOMAIN and LETSENCRYPT_EMAIL in .env first' >&2; exit 1)
	$(COMPOSE) $(ENV_FILE) $(BASE) -f infra/compose/compose.prod.yaml -f infra/compose/compose.prod-bootstrap.yaml up -d backend frontend nginx
	$(COMPOSE) $(ENV_FILE) $(PROD) --profile certificates run --rm --no-deps certbot certonly --webroot -w /var/www/certbot --email "$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^LETSENCRYPT_EMAIL=//p')" -d "$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^CERTBOT_DOMAIN=//p')" --agree-tos --no-eff-email
	$(COMPOSE) $(ENV_FILE) $(PROD) up -d --force-recreate nginx

prod-cert-renew: ## Renew Let's Encrypt certificates and reload Nginx
	$(COMPOSE) $(ENV_FILE) $(PROD) --profile certificates run --rm --no-deps certbot renew --webroot -w /var/www/certbot
	$(COMPOSE) $(ENV_FILE) $(PROD) exec nginx nginx -s reload
