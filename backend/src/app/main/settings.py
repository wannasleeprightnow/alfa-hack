"""Environment-aware application settings."""

from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Settings loaded from environment variables and optional local .env file."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: Literal["development", "test", "production"] = "development"
    log_level: str = "INFO"
    api_prefix: str = Field(default="/api", pattern=r"^/[a-zA-Z0-9/_-]*$")

    @property
    def expose_api_docs(self) -> bool:
        """Return whether interactive API documentation is enabled."""
        return self.app_env != "production"
