"""
AI Assistant routes — voice & text Q&A about scanned objects.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from typing import Optional
import anthropic

from config.settings import settings
from services.database.scan_repository import ScanRepository
from api.middleware.auth import get_current_user

router = APIRouter()

_anthropic_client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

SYSTEM_PROMPT_TEMPLATE = """You are an expert AI Engineering Assistant embedded in an AR object scanning application.
You have full technical knowledge of the following scanned object:

Object: {name}
Brand: {brand}
Model: {model}
Category: {category}
Description: {description}
Components: {components}
Materials: {materials}
Measurements: {measurements}

Your role is to:
1. Answer technical questions about this specific object
2. Explain component functions in clear, accessible language
3. Provide step-by-step repair and maintenance guidance
4. Identify materials, manufacturing processes, and engineering principles
5. Suggest AR visualizations when helpful (respond with has_visualization: true and visualization_type)

Visualization types you can trigger: exploded_view, xray_scan, measurement_overlay, thermal_map, circuit_trace, airflow_simulation

Respond concisely and technically accurately. Use **bold** for key terms.
When explaining to beginners, use analogies. When explaining to experts, use technical terms."""


class ChatRequest(BaseModel):
    object_id: str
    message: str
    session_id: str
    expertise_level: str = "intermediate"  # beginner | intermediate | expert


class ChatResponse(BaseModel):
    response: str
    has_visualization: bool = False
    visualization_type: Optional[str] = None
    suggested_actions: list[str] = []
    confidence: float = 0.95


class VoiceQueryRequest(BaseModel):
    object_id: str
    session_id: str


@router.post("/chat", response_model=ChatResponse)
async def chat_with_assistant(
    request: ChatRequest,
    current_user=Depends(get_current_user),
):
    """
    Send a text message to the AI engineering assistant about a scanned object.
    Uses Claude with full object context injected.
    """
    scan = await ScanRepository().get_scan(request.object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Object not found")

    # Build component summary
    components_text = ", ".join(
        f"{c['name']} ({c['function']})"
        for c in scan.get("components", [])[:8]
    )

    system_prompt = SYSTEM_PROMPT_TEMPLATE.format(
        name=scan.get("name", "Unknown"),
        brand=scan.get("brand", "Unknown"),
        model=scan.get("model", "Unknown"),
        category=scan.get("category", "unknown"),
        description=scan.get("description", ""),
        components=components_text,
        materials=scan.get("material_analysis", {}).get("primary_material", "Unknown"),
        measurements=f"H:{scan.get('measurements', {}).get('height_cm', 0)}cm "
                     f"W:{scan.get('measurements', {}).get('width_cm', 0)}cm "
                     f"D:{scan.get('measurements', {}).get('depth_cm', 0)}cm",
    )

    message_content = request.message
    if request.expertise_level == "beginner":
        message_content += "\n\n[Explain in simple terms, use everyday analogies]"
    elif request.expertise_level == "expert":
        message_content += "\n\n[Provide full technical details, use engineering terminology]"

    response = _anthropic_client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=system_prompt,
        messages=[{"role": "user", "content": message_content}],
    )

    response_text = response.content[0].text

    # Detect visualization requests
    vis_keywords = {
        "exploded_view": ["disassemble", "explode", "parts", "components", "separated"],
        "xray_scan": ["inside", "internal", "x-ray", "xray", "see through"],
        "measurement_overlay": ["measure", "size", "dimension", "how big"],
        "thermal_map": ["heat", "temperature", "thermal", "hot"],
        "airflow_simulation": ["airflow", "cooling", "air", "fan"],
    }

    has_vis = False
    vis_type = None
    message_lower = request.message.lower()
    for vtype, keywords in vis_keywords.items():
        if any(kw in message_lower for kw in keywords):
            has_vis = True
            vis_type = vtype
            break

    return ChatResponse(
        response=response_text,
        has_visualization=has_vis,
        visualization_type=vis_type,
        suggested_actions=_generate_suggested_actions(request.message),
    )


@router.post("/voice")
async def voice_query(
    audio: UploadFile = File(...),
    object_id: str = "",
    session_id: str = "",
    current_user=Depends(get_current_user),
):
    """
    Process voice query — transcribe audio then route to chat endpoint.
    Uses OpenAI Whisper for transcription.
    """
    audio_bytes = await audio.read()

    # Transcribe with Whisper (placeholder — integrate actual Whisper call)
    transcribed_text = await _transcribe_audio(audio_bytes)

    if not transcribed_text:
        raise HTTPException(status_code=400, detail="Could not transcribe audio")

    # Route through chat
    chat_req = ChatRequest(
        object_id=object_id,
        message=transcribed_text,
        session_id=session_id,
    )
    return await chat_with_assistant(chat_req, current_user)


def _generate_suggested_actions(message: str) -> list[str]:
    message_lower = message.lower()
    actions = []
    if any(w in message_lower for w in ["repair", "fix", "replace"]):
        actions.append("Open repair guide")
    if any(w in message_lower for w in ["part", "buy", "purchase", "order"]):
        actions.append("Find compatible parts")
    if any(w in message_lower for w in ["inside", "internal", "xray"]):
        actions.append("View X-Ray mode")
    if any(w in message_lower for w in ["measure", "size", "dimension"]):
        actions.append("Open measurements")
    return actions[:3]


async def _transcribe_audio(audio_bytes: bytes) -> str:
    # Placeholder for Whisper integration
    return ""
