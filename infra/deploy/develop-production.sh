#!/bin/sh
# Invoked over SSH with: sh -s -- DEPLOY_PATH IMAGE_PREFIX COMMIT_SHA
set -eu

deploy_path=$1
export IMAGE_PREFIX=$2 IMAGE_TAG=$3
case "$IMAGE_TAG" in *[!0-9a-f]*|'') echo 'Invalid image SHA' >&2; exit 1 ;; esac
test "${#IMAGE_TAG}" -eq 40
cd "$deploy_path"
test -f .env
mode=$(cat .deployment-mode)
case "$mode" in staging|production) ;; *) echo 'Unknown deployment mode' >&2; exit 1 ;; esac
command -v curl >/dev/null

production() {
  docker compose --env-file .env -f compose.yaml -f infra/compose/compose.images.yaml -f infra/compose/compose.prod.yaml "$@"
}
staging() {
  docker compose -p alfa-hack-staging --env-file .env -f compose.yaml -f infra/compose/compose.images.yaml -f infra/compose/compose.staging.yaml "$@"
}

# Validate TLS and download every image before stopping the old staging stack.
production config --quiet
domain=$(production config --environment | sed -n 's/^CERTBOT_DOMAIN=//p')
test "$domain" = '418.live' || { echo 'Set CERTBOT_DOMAIN=418.live in the VPS .env' >&2; exit 1; }
test -s "letsencrypt/live/$domain/fullchain.pem" && test -s "letsencrypt/live/$domain/privkey.pem" || {
  echo 'TLS certificate missing; provision it with make prod-cert-init before deployment' >&2
  exit 1
}
production pull
staging down
printf 'production\n' > .deployment-mode
production up --detach --remove-orphans --wait --wait-timeout 180

# Check the real HTTPS virtual host with certificate verification and no DNS dependency.
for endpoint in / /api/health; do
  curl --fail --silent --show-error --noproxy '*' --connect-timeout 5 --max-time 20 \
    --retry 3 --retry-delay 2 --retry-connrefused \
    --resolve "$domain:443:127.0.0.1" "https://$domain$endpoint" -o /dev/null
done
printf '%s\n' "$IMAGE_TAG" > .production-image-tag.tmp
mv .production-image-tag.tmp .production-image-tag
echo "Production deployed: $IMAGE_TAG at https://$domain/"
