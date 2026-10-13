# Alfa Hack

Hackathon starter repository with a FastAPI backend and a React + TypeScript frontend.

## Requirements

- Docker Engine and Docker Compose v2
- `uv` for local backend development
- Node.js 22 and npm for local frontend development
- GNU Make

## Quick start (Docker)

```bash
cp .env.example .env
make dev
```

Open <http://localhost:8080>. The API health endpoint is at <http://localhost:8080/api/health> and the interactive API docs are at <http://localhost:8080/api/docs>.

## Local development

Backend:

```bash
cd backend
uv sync --group dev
uv run fastapi dev
```

Frontend:

```bash
cd frontend
npm ci
npm run dev
```

## Environments

Compose files provide separate configurations:

- Development: `make dev` (HTTP, source reload, API docs enabled)
- Tests: `make test` (isolated test configuration; HTTP)
- Production: `make prod` (HTTP-to-HTTPS redirect and TLS; configure a domain first)

Production is configured for `418.buzz`: the frontend is served at `https://418.buzz/` and the API at `https://418.buzz/api/`. DNS for `418.buzz` must point to the production host, with inbound ports 80 and 443 reachable. Set `CERTBOT_DOMAIN=418.buzz` and a monitored `LETSENCRYPT_EMAIL` in `.env`, then follow the [TLS setup](#production-tls-with-lets-encrypt) instructions. Never commit `.env` or private keys.

## CI/CD and VPS deployments

GitHub Actions checks formatting, linting, types, tests, and production builds on pull requests
to and pushes to `develop` and `main`. Successful branch pushes publish immutable runtime images
to GitHub Container Registry (GHCR):

- `ghcr.io/wannasleeprightnow/alfa-hack-backend:<commit-sha>`
- `ghcr.io/wannasleeprightnow/alfa-hack-frontend:<commit-sha>`
- `ghcr.io/wannasleeprightnow/alfa-hack-nginx:<commit-sha>`

Only `develop` deploys automatically. After quality checks, deployment-script tests, and image
publication succeed, `Deploy 418.buzz` updates the production stack at `https://418.buzz/`.
It runs with `APP_ENV=production`; API documentation is disabled. A push to `main` publishes
images but never connects to the VPS. Integrate feature PRs with **Rebase and merge** into
`develop`; promotion to `main` is not required to update the domain.

### One-time VPS setup

1. Install Docker Engine and Docker Compose v2. Create a dedicated deployment account and
   `/opt/alfa-hack` (or another `VPS_DEPLOY_PATH`) containing this repository's Compose files and
   a protected `.env`. Membership in the `docker` group is root-equivalent; grant it only to this
   account.
2. Log the VPS into GHCR with a GitHub personal access token (classic) scoped to `read:packages`.
   Enter it through standard input, not a shell history or repository file:

   ```bash
   read -rs GHCR_PULL_TOKEN
   GHCR_USERNAME='your-github-username'
   printf '%s' "$GHCR_PULL_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin
   unset GHCR_PULL_TOKEN GHCR_USERNAME
   ```

   Alternatively, intentionally make the three GHCR packages public.
3. Configure `CERTBOT_DOMAIN=418.buzz` and a real `LETSENCRYPT_EMAIL` in the VPS `.env`,
   open ports 80/443, and provision the certificate with `make prod-cert-init` if needed.
   Create `/opt/alfa-hack/.deployment-mode` with the contents `production`. Existing installations
   with mode `staging` are migrated by the first successful deployment: images and certificates
   are checked first, then the staging Compose project is stopped and production starts.
   Other mode values block automatic deployment and can be used for maintenance.
4. In GitHub, create the `staging` environment, restrict it to the `develop` branch, and add
   these environment secrets: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, `VPS_KNOWN_HOSTS`, and
   `VPS_DEPLOY_PATH`. Generate `VPS_KNOWN_HOSTS` from a verified VPS host key; do not accept a
   host key during an Actions run.

The GitHub environment is still named `staging` to reuse the existing SSH secrets; the job
deploys production. It copies the four Compose files and streams the checked deployment script
over SSH. It never copies `.env`, certificates, GHCR credentials, or private keys to the runner.
Each deployment checks the frontend and `/api/health` over HTTPS on the VPS, then checks both
public URLs from the runner. The successful image SHA is recorded in `.production-image-tag`.
Deployment jobs are serialized; the existing `staging-deploy` concurrency group is retained
to serialize the transition with older workflow runs. The first transition and later container
updates can cause a brief interruption; this is not a zero-downtime deployment.

### Manual production update and rollback

Choose the full SHA from a successful `develop` image build. Wait for any active `Deploy 418.buzz`
job to finish (or cancel it and wait until it has stopped). Then switch the deployment lock and
stop staging; production owns ports 80 and 443 while it runs:

```bash
cd /opt/alfa-hack
printf 'production\n' > .deployment-mode
DEPLOY_SHA='replace-with-the-40-character-develop-commit-sha'
IMAGE_PREFIX=ghcr.io/wannasleeprightnow IMAGE_TAG="$DEPLOY_SHA" \
  docker compose -p alfa-hack-staging --env-file .env -f compose.yaml -f compose.images.yaml -f compose.staging.yaml down
IMAGE_PREFIX=ghcr.io/wannasleeprightnow IMAGE_TAG="$DEPLOY_SHA" make prod-images
curl --fail https://<domain>/api/health
```

Record the previous SHA before updating. To roll back, repeat the `make prod-images` command
with that SHA. Automatic rollback is not performed if startup or HTTPS validation fails;
inspect container logs and restore the previous image SHA manually. To return the host to staging,
pause automatic deployments first, then stop production with
`IMAGE_PREFIX=ghcr.io/wannasleeprightnow IMAGE_TAG="$(cat .production-image-tag)" docker compose --env-file .env -f compose.yaml -f compose.images.yaml -f compose.prod.yaml down`,
set `.deployment-mode` back to `staging`, and run
`make staging-images` with the SHA from the last successful `develop` workflow. Never run staging
and production simultaneously. Compose keeps the two stacks in separate projects, and the
Make targets refuse to start one while the other is running. The automatic workflow instead
performs the explicit staging-to-production transition described above.

## Production TLS with Let's Encrypt

1. Set `CERTBOT_DOMAIN=418.buzz` and set `LETSENCRYPT_EMAIL` to a monitored email address in `.env`.
2. Ensure the DNS A/AAAA records for `418.buzz` point to this production host and ports 80/443 are reachable from the internet.
3. Run `make prod-cert-init`. This starts the production stack with a temporary HTTP-only Nginx configuration, obtains the certificate using the HTTP-01 webroot challenge, and restarts Nginx with HTTPS enabled.
4. Start or update a locally built production stack with `make prod`, or use `make prod-images IMAGE_TAG=<develop-full-sha>` on the VPS to run the verified GHCR images. Later `develop` pushes update production automatically.
5. Schedule `make prod-cert-renew` (for example, daily via a host cron job). It renews eligible certificates and reloads Nginx.

Certificate data is stored in the ignored local `letsencrypt/` directory. Back it up securely; do not commit it. The ignored `certbot/` directory is used only for the HTTP-01 challenge webroot. For local testing, use `make test` and do not request real certificates.

## Backend architecture

`backend/src/app/` is arranged by DDD responsibility:

- `domain/`: domain model and rules
- `application/`: use cases and ports
- `infrastructure/`: implementations of external-system adapters
- `presentation/`: HTTP/API adapters
- `main/`: application composition and startup

Use Pydantic models for request/response DTOs and validation in `presentation/`. Keep domain entities and value objects as standard-library dataclasses in `domain/`; do not use Pydantic models as domain models.

Dishka manages dependencies; application settings are provided at `Scope.APP` and resolved from the container during app composition. For future handler dependencies, use `FromDishka[T]` with Dishka's `@inject_sync` FastAPI integration; do not use FastAPI `Depends`.

The starter includes only the health endpoint; business logic and persistence belong in future feature work.

## Git workflow

Use Gitflow branch names and merge direction:

- `main`: production-ready releases
- `develop`: integration branch
- `feature/<short-name>` branches from `develop`, merge back to `develop`
- `release/<version>` branches from `develop`, merge into `main` and back into `develop`
- `hotfix/<short-name>` branches from `main`, merge into `main` and `develop`

Keep feature branches focused and use pull requests with **Rebase and merge** for integration.
Currently, successful `develop` pushes deploy to `418.buzz`; `main` remains a release branch.

## Useful commands

Run `make help` to list project commands. Test commands do not require production secrets or certificates.
