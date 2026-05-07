"""
Integration tests for the scan API endpoints.
"""
import pytest
from httpx import AsyncClient
from fastapi.testclient import TestClient
import io
from PIL import Image

from main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def sample_image_bytes():
    """Generate a minimal valid JPEG for testing."""
    img = Image.new("RGB", (640, 480), color=(100, 150, 200))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_analyze_object(client, sample_image_bytes):
    response = client.post(
        "/v1/scan/analyze",
        files={"image": ("test.jpg", sample_image_bytes, "image/jpeg")},
        data={"metadata": "{}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "id" in data
    assert "name" in data
    assert "components" in data
    assert "measurements" in data
    assert data["confidence_score"] > 0


def test_analyze_invalid_format(client):
    response = client.post(
        "/v1/scan/analyze",
        files={"image": ("test.pdf", b"not an image", "application/pdf")},
        data={"metadata": "{}"},
    )
    assert response.status_code == 400


def test_scan_history_empty(client):
    response = client.get("/v1/scan/history")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_get_scan_not_found(client):
    response = client.get("/v1/scan/nonexistent-id")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_chat_with_assistant():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        # First create a scan
        img = Image.new("RGB", (640, 480))
        buf = io.BytesIO()
        img.save(buf, format="JPEG")

        scan_resp = await ac.post(
            "/v1/scan/analyze",
            files={"image": ("t.jpg", buf.getvalue(), "image/jpeg")},
            data={"metadata": "{}"},
        )
        assert scan_resp.status_code == 200
        object_id = scan_resp.json()["id"]

        chat_resp = await ac.post(
            "/v1/assistant/chat",
            json={
                "object_id": object_id,
                "message": "What does the motherboard do?",
                "session_id": "test-session-001",
            },
        )
        assert chat_resp.status_code == 200
        body = chat_resp.json()
        assert "response" in body
        assert len(body["response"]) > 20


def test_gamification_stats(client):
    response = client.get("/v1/gamification/stats")
    assert response.status_code == 200
    data = response.json()
    assert "xp" in data
    assert "level" in data
    assert data["level"] >= 1


def test_list_simulation_types(client):
    response = client.get("/v1/simulation/types")
    assert response.status_code == 200
    data = response.json()
    assert "types" in data
    assert len(data["types"]) >= 5


def test_marketplace_search(client):
    response = client.get(
        "/v1/marketplace/search",
        params={"object_id": "dummy-id", "condition": "new"},
    )
    assert response.status_code == 200
    parts = response.json()
    assert isinstance(parts, list)
    assert len(parts) >= 1
    assert "price_usd" in parts[0]
