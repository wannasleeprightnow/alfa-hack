"""Dishka providers and container setup for the application."""

from dishka import Provider, Scope, provide

from app.main.settings import Settings


class SettingsProvider(Provider):
    """Provide application settings for the lifetime of the application."""

    def __init__(self, settings: Settings | None = None) -> None:
        super().__init__()
        self._settings = settings

    @provide(scope=Scope.APP)
    def provide_settings(self) -> Settings:
        """Resolve settings once per application, with an optional test override."""
        if self._settings is None:
            self._settings = Settings()
        return self._settings
