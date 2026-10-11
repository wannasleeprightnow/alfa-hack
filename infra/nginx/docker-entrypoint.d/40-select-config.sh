#!/bin/sh
set -eu

mode="${NGINX_MODE:-production}"
case "$mode" in
  development|test)
    config="$mode.conf"
    ;;
  production)
    if [ "${NGINX_BOOTSTRAP:-false}" = "true" ] || [ -z "${CERTBOT_DOMAIN:-}" ] || \
       [ ! -s "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" ] || \
       [ ! -s "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/privkey.pem" ]; then
      config="production-bootstrap.conf"
    else
      config="production.conf"
    fi
    ;;
  *)
    echo "Unsupported NGINX_MODE: ${mode}" >&2
    exit 1
    ;;
esac

if [ "$config" = "production.conf" ]; then
  envsubst '${CERTBOT_DOMAIN}' < "/opt/nginx-configs/${config}" > /etc/nginx/conf.d/default.conf
else
  cp "/opt/nginx-configs/${config}" /etc/nginx/conf.d/default.conf
fi
