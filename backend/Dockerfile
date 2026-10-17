# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:0.13.0 AS uv

FROM python:3.14-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONPATH=/app/src
WORKDIR /app
COPY --from=uv /uv /uvx /bin/

FROM base AS dependencies
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-install-project --no-dev

FROM dependencies AS development
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-install-project --group dev
COPY src ./src
COPY tests ./tests
ENV PATH="/app/.venv/bin:$PATH"
EXPOSE 8000
CMD ["uv", "run", "uvicorn", "app.main.app:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

FROM dependencies AS test
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-install-project --group dev
COPY src ./src
COPY tests ./tests
ENV PATH="/app/.venv/bin:$PATH" APP_ENV=test
CMD ["uv", "run", "--group", "dev", "pytest", "-q"]

FROM base AS runtime
ENV PATH="/app/.venv/bin:$PATH" \
    APP_ENV=production
RUN addgroup --system --gid 10001 app && adduser --system --uid 10001 --ingroup app app
COPY --from=dependencies --chown=10001:10001 /app/.venv /app/.venv
COPY --chown=10001:10001 src ./src
USER 10001:10001
EXPOSE 8000
CMD ["uvicorn", "app.main.app:app", "--host", "0.0.0.0", "--port", "8000"]
