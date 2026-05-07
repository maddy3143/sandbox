"""
Collaboration routes — real-time AR session management via WebSocket.
"""
import uuid
import json
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from api.middleware.auth import get_current_user

router = APIRouter()

# In-memory session store (use Redis in production)
_sessions: dict[str, dict] = {}
_session_connections: dict[str, list[WebSocket]] = {}


class CreateSessionRequest(BaseModel):
    object_id: str
    session_name: Optional[str] = None
    max_participants: int = 10


class SessionResponse(BaseModel):
    session_id: str
    session_code: str
    object_id: str
    host_id: str
    created_at: str
    participants: list[dict]
    status: str


@router.post("/session", response_model=SessionResponse)
async def create_session(
    request: CreateSessionRequest,
    current_user=Depends(get_current_user),
):
    """Create a new collaboration session."""
    session_id = str(uuid.uuid4())
    session_code = _generate_session_code()

    session = {
        "session_id": session_id,
        "session_code": session_code,
        "object_id": request.object_id,
        "host_id": current_user.id,
        "session_name": request.session_name or f"Session {session_code}",
        "max_participants": request.max_participants,
        "created_at": datetime.utcnow().isoformat(),
        "participants": [
            {"user_id": current_user.id, "role": "host", "joined_at": datetime.utcnow().isoformat()}
        ],
        "status": "active",
    }

    _sessions[session_id] = session
    _session_connections[session_id] = []

    return SessionResponse(**session)


@router.post("/session/{session_id}/join")
async def join_session(session_id: str, current_user=Depends(get_current_user)):
    """Join an existing collaboration session."""
    session = _sessions.get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session["status"] != "active":
        raise HTTPException(status_code=400, detail="Session is not active")

    participant = {
        "user_id": current_user.id,
        "role": "participant",
        "joined_at": datetime.utcnow().isoformat(),
    }

    if not any(p["user_id"] == current_user.id for p in session["participants"]):
        session["participants"].append(participant)

    return {"message": "Joined successfully", "session": session}


@router.post("/session/{session_id}/leave")
async def leave_session(session_id: str, current_user=Depends(get_current_user)):
    """Leave a collaboration session."""
    session = _sessions.get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    session["participants"] = [
        p for p in session["participants"] if p["user_id"] != current_user.id
    ]

    if session["host_id"] == current_user.id:
        session["status"] = "ended"

    return {"message": "Left session successfully"}


@router.get("/session/{session_id}")
async def get_session(session_id: str, current_user=Depends(get_current_user)):
    """Get session details."""
    session = _sessions.get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.websocket("/session/{session_id}/ws")
async def session_websocket(websocket: WebSocket, session_id: str):
    """
    WebSocket endpoint for real-time collaboration events.
    Messages: { type, payload } where type is one of:
      - ar_action: AR pointer / annotation update
      - component_highlight: highlight a specific component
      - voice_message: voice chat signal
      - cursor_move: user cursor position
      - annotation_add: add AR annotation
    """
    await websocket.accept()

    if session_id not in _session_connections:
        _session_connections[session_id] = []
    _session_connections[session_id].append(websocket)

    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            # Broadcast to all participants
            await _broadcast(session_id, message, exclude=websocket)
    except WebSocketDisconnect:
        _session_connections[session_id].remove(websocket)


async def _broadcast(session_id: str, message: dict, exclude: Optional[WebSocket] = None):
    connections = _session_connections.get(session_id, [])
    dead = []
    for ws in connections:
        if ws is exclude:
            continue
        try:
            await ws.send_text(json.dumps(message))
        except Exception:
            dead.append(ws)
    for ws in dead:
        connections.remove(ws)


def _generate_session_code() -> str:
    import random, string
    prefix = "AR"
    parts = ["".join(random.choices(string.ascii_uppercase + string.digits, k=4)) for _ in range(2)]
    return f"{prefix}-{'-'.join(parts)}"
