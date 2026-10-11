COMPOSE = docker compose
ENV_FILE = --env-file .env
BASE = -f compose.yaml
DEV = $(BASE) -f compose.dev.yaml
TEST = $(BASE) -f compose.test.yaml
PROD = $(BASE) -f compose.prod.yaml

.PHONY: help setup dev dev-down logs logs-test logs-prod test test-backend test-frontend prod prod-down prod-cert-init prod-cert-renew backend-test frontend-test frontend-build lint

help: ## Show available commands
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "%-22s %s\n", $$1, $$2}'

setup: ## Create local environment file from the example
	@test -f .env || cp .env.example .envhttp://localhost/

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
	cd backend && uv run --group dev ruff check .
	cd frontend && npm ci && npm run lint

prod: setup ## Run the production stack (requires domain and certificate)
	@domain="$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^CERTBOT_DOMAIN=//p')"; \
	 test -n "$$domain" && test "$$domain" != "example.com" && \
	 test -s "letsencrypt/live/$$domain/fullchain.pem" && \
	 test -s "letsencrypt/live/$$domain/privkey.pem" || \
	 (echo 'Configure CERTBOT_DOMAIN and run make prod-cert-init first' >&2; exit 1)
	$(COMPOSE) $(ENV_FILE) $(PROD) up --build -d

prod-down: ## Stop the production stack without deleting certificate data
	$(COMPOSE) $(ENV_FILE) $(PROD) down

prod-cert-init: setup ## Obtain the initial Let's Encrypt certificate and enable HTTPS
	@domain="$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^CERTBOT_DOMAIN=//p')"; \
	 email="$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^LETSENCRYPT_EMAIL=//p')"; \
	 test -n "$$domain" && test "$$domain" != "example.com" && \
	 test -n "$$email" && test "$$email" != "admin@example.com" || \
	 (echo 'Set a real CERTBOT_DOMAIN and LETSENCRYPT_EMAIL in .env first' >&2; exit 1)
	$(COMPOSE) $(ENV_FILE) $(BASE) -f compose.prod.yaml -f compose.prod-bootstrap.yaml up -d backend frontend nginx
	$(COMPOSE) $(ENV_FILE) $(PROD) --profile certificates run --rm --no-deps certbot certonly --webroot -w /var/www/certbot --email "$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^LETSENCRYPT_EMAIL=//p')" -d "$$($(COMPOSE) $(ENV_FILE) $(PROD) config --environment | sed -n 's/^CERTBOT_DOMAIN=//p')" --agree-tos --no-eff-email
	$(COMPOSE) $(ENV_FILE) $(PROD) up -d --force-recreate nginx

prod-cert-renew: ## Renew Let's Encrypt certificates and reload Nginx
	$(COMPOSE) $(ENV_FILE) $(PROD) --profile certificates run --rm --no-deps certbot renew --webroot -w /var/www/certbot
	$(COMPOSE) $(ENV_FILE) $(PROD) exec nginx nginx -s reload
