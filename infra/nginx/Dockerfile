# syntax=docker/dockerfile:1
FROM nginx:1.29.0-alpine3.22
COPY configs /opt/nginx-configs
COPY docker-entrypoint.d/40-select-config.sh /docker-entrypoint.d/40-select-config.sh
RUN chmod 755 /docker-entrypoint.d/40-select-config.sh
EXPOSE 80 443
