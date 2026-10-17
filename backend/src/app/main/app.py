"""Application composition root and startup."""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import TYPE_CHECKING

from dishka import make_container
from dishka.integrations.fastapi import FastapiProvider, setup_dishka
from fastapi import FastAPI

from app.main.container import SettingsProvider
from app.main.settings import Settings
from app.presentation.http.health import router as health_router

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator


def create_app(settings: Settings | None = None) -> FastAPI:
    """Create the API application using the selected environment settings."""
    container = make_container(SettingsProvider(settings), FastapiProvider())
    resolved_settings = container.get(Settings)
    docs_enabled = resolved_settings.expose_api_docs

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncGenerator[None]:
        try:
            yield
        finally:
            container.close()

    app = FastAPI(
        title="Alfa Hack API",
        version="0.1.0",
        docs_url=f"{resolved_settings.api_prefix}/docs" if docs_enabled else None,
        redoc_url=f"{resolved_settings.api_prefix}/redoc" if docs_enabled else None,
        openapi_url=f"{resolved_settings.api_prefix}/openapi.json" if docs_enabled else None,
        lifespan=lifespan,
    )
    app.include_router(health_router, prefix=resolved_settings.api_prefix)
    setup_dishka(container=container, app=app)
    return app


app = create_app()

__all__ = ["app", "create_app"]
