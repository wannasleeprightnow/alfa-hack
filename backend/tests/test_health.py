"""Health endpoint integration tests."""

from http import HTTPStatus

from fastapi.testclient import TestClient

from app.main.app import create_app
from app.main.settings import Settings


def test_health_endpoint_returns_ok() -> None:
    """Return an OK health response for the test application."""
    with TestClient(create_app(Settings(app_env="test"))) as client:
        response = client.get("/api/health")

        assert response.status_code == HTTPStatus.OK
        assert response.json() == {"status": "ok"}


def test_api_docs_are_disabled_in_production() -> None:
    """Hide generated documentation when the application runs in production."""
    with TestClient(create_app(Settings(app_env="production"))) as client:
        assert client.get("/api/docs").status_code == HTTPStatus.NOT_FOUND
        assert client.get("/api/openapi.json").status_code == HTTPStatus.NOT_FOUND


def test_settings_are_resolved_from_dishka_container() -> None:
    """Expose an injected settings override through the DI container."""
    settings = Settings(app_env="test", log_level="DEBUG")
    app = create_app(settings)

    with TestClient(app):
        resolved_settings = app.state.dishka_container.get(Settings)

    assert resolved_settings is settings
