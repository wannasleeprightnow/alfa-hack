"""Health endpoint."""

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(tags=["health"])


class HealthResponse(BaseModel):
    """Successful health-check response."""

    status: str


@router.get("/health")
def health() -> HealthResponse:
    """Report that the API process is accepting requests."""
    return HealthResponse(status="ok")
