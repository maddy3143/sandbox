"""
Repair Guide routes — step-by-step AI-generated repair procedures.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from services.database.scan_repository import ScanRepository
from api.middleware.auth import get_current_user

router = APIRouter()

# Repair guide knowledge base (in production, backed by vector DB + LLM generation)
_REPAIR_GUIDES: dict[str, dict] = {
    "battery": {
        "title": "Battery Replacement",
        "difficulty": "Intermediate",
        "duration_minutes": 30,
        "tools": ["Torx T5 screwdriver", "Plastic pry tool", "Spudger", "Magnetic tray"],
        "parts_needed": ["Compatible replacement battery"],
        "safety_warnings": [
            "Power off device completely before starting.",
            "Never puncture or bend lithium batteries — fire hazard.",
            "Work in a well-ventilated area.",
        ],
    },
    "ram": {
        "title": "RAM Upgrade",
        "difficulty": "Easy",
        "duration_minutes": 15,
        "tools": ["Torx T5 screwdriver", "Plastic pry tool", "Anti-static wrist strap"],
        "parts_needed": ["Compatible DDR4 SODIMM module"],
        "safety_warnings": [
            "Ground yourself to prevent static discharge.",
            "Handle RAM only by edges.",
        ],
    },
    "storage": {
        "title": "SSD Replacement",
        "difficulty": "Easy",
        "duration_minutes": 20,
        "tools": ["Torx T5 screwdriver", "Phillips #1 screwdriver", "Plastic pry tool"],
        "parts_needed": ["Compatible M.2 NVMe SSD"],
        "safety_warnings": [
            "Back up all data before replacing storage.",
            "Disconnect battery before proceeding.",
        ],
    },
    "display": {
        "title": "Display Panel Replacement",
        "difficulty": "Advanced",
        "duration_minutes": 60,
        "tools": ["Torx T5 screwdriver", "Phillips #1 screwdriver", "Plastic pry tools ×3", "Suction cup"],
        "parts_needed": ["Compatible 15.6\" FHD IPS panel"],
        "safety_warnings": [
            "LCD panels are fragile — handle with extreme care.",
            "Disconnect battery and display cable before starting.",
        ],
    },
}


class RepairStep(BaseModel):
    step: int
    title: str
    instruction: str
    tools: list[str]
    warning: Optional[str]
    highlight_component: str
    duration_seconds: int
    image_url: Optional[str] = None
    ar_overlay_config: Optional[dict] = None


class RepairGuideResponse(BaseModel):
    object_id: str
    repair_type: str
    title: str
    difficulty: str
    total_steps: int
    estimated_duration_minutes: int
    tools_required: list[str]
    parts_needed: list[str]
    safety_warnings: list[str]
    steps: list[RepairStep]


@router.get("/{object_id}/guide")
async def get_repair_guide(
    object_id: str,
    repair_type: str = "battery",
    current_user=Depends(get_current_user),
):
    """Return full step-by-step repair guide for specified repair type."""
    scan = await ScanRepository().get_scan(object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Object not found")

    if repair_type not in _REPAIR_GUIDES:
        raise HTTPException(status_code=404, detail=f"No guide for repair type: {repair_type}")

    guide_meta = _REPAIR_GUIDES[repair_type]
    steps = _build_repair_steps(repair_type, scan)

    return RepairGuideResponse(
        object_id=object_id,
        repair_type=repair_type,
        title=guide_meta["title"],
        difficulty=guide_meta["difficulty"],
        total_steps=len(steps),
        estimated_duration_minutes=guide_meta["duration_minutes"],
        tools_required=guide_meta["tools"],
        parts_needed=guide_meta["parts_needed"],
        safety_warnings=guide_meta["safety_warnings"],
        steps=steps,
    )


@router.get("/{object_id}/step/{step_id}")
async def get_repair_step(
    object_id: str,
    step_id: int,
    repair_type: str = "battery",
    current_user=Depends(get_current_user),
):
    """Return a single repair step with full AR overlay config."""
    steps = _build_repair_steps(repair_type, {})
    if step_id < 1 or step_id > len(steps):
        raise HTTPException(status_code=404, detail="Step not found")
    return steps[step_id - 1]


@router.post("/feedback")
async def submit_feedback(
    object_id: str,
    repair_type: str,
    rating: int,
    comment: str = "",
    current_user=Depends(get_current_user),
):
    """Submit repair guide feedback to improve AI quality."""
    return {"message": "Feedback submitted. Thank you!"}


def _build_repair_steps(repair_type: str, scan: dict) -> list[RepairStep]:
    base_steps = {
        "battery": [
            RepairStep(step=1, title="Power Off & Discharge", instruction="Shut down completely. Discharge battery below 30% to minimise risk.", tools=[], warning="Never work on a powered device.", highlight_component="Power Button", duration_seconds=60),
            RepairStep(step=2, title="Remove Bottom Cover", instruction="Remove all 8 Torx T5 screws from the bottom panel. Place in a magnetic tray.", tools=["Torx T5 screwdriver", "Magnetic tray"], warning="Note screw positions — lengths vary.", highlight_component="Bottom Cover", duration_seconds=180),
            RepairStep(step=3, title="Pry Open Cover", instruction="Insert plastic pry tool into seam near air vents. Work gently around perimeter.", tools=["Plastic pry tool", "Spudger"], warning="Never use metal tools — damages clips.", highlight_component="Bottom Cover", duration_seconds=120),
            RepairStep(step=4, title="Disconnect Battery", instruction="Locate the white ZIF connector near center-right of board. Pull the pull-tab to disconnect.", tools=["Spudger"], warning="⚡ CRITICAL: Disconnect battery before touching any other component.", highlight_component="Battery Connector", duration_seconds=60),
            RepairStep(step=5, title="Remove Battery Screws", instruction="Remove 2 Phillips #1 screws holding the battery bracket in place.", tools=["Phillips #1 screwdriver"], warning=None, highlight_component="Battery", duration_seconds=60),
            RepairStep(step=6, title="Lift Out Battery", instruction="Lift battery straight up. If adhesive-held, apply iOpener at 60°C along edges first.", tools=["iOpener", "Plastic card"], warning="Never puncture the battery — fire hazard.", highlight_component="Battery", duration_seconds=180),
            RepairStep(step=7, title="Install New Battery", instruction="Place new battery and reconnect ZIF connector until it clicks firmly.", tools=[], warning="Verify part number compatibility before purchase.", highlight_component="Battery", duration_seconds=120),
            RepairStep(step=8, title="Reassemble & Test", instruction="Snap cover back. Replace all 8 screws. Power on and verify battery in BIOS/Settings.", tools=["Torx T5 screwdriver"], warning=None, highlight_component="Bottom Cover", duration_seconds=240),
        ],
        "ram": [
            RepairStep(step=1, title="Remove Bottom Cover", instruction="Follow battery guide steps 1-3.", tools=["Torx T5 screwdriver", "Plastic pry tool"], warning="Disconnect battery first.", highlight_component="Bottom Cover", duration_seconds=300),
            RepairStep(step=2, title="Locate RAM Slot", instruction="RAM slot is center-board. One slot occupied by an 8GB module.", tools=[], warning=None, highlight_component="RAM Module", duration_seconds=30),
            RepairStep(step=3, title="Remove Existing RAM", instruction="Press both retention clips outward simultaneously. RAM pops to 45°. Slide out.", tools=[], warning="⚡ Ground yourself! Static kills RAM instantly.", highlight_component="RAM Module", duration_seconds=60),
            RepairStep(step=4, title="Insert New RAM", instruction="Insert at 45° aligning notch. Push down firmly until both clips click.", tools=[], warning="Handle only by edges — never touch gold contacts.", highlight_component="RAM Module", duration_seconds=60),
        ],
        "storage": [
            RepairStep(step=1, title="Remove Bottom Cover", instruction="Follow battery guide steps 1-3.", tools=["Torx T5 screwdriver", "Plastic pry tool"], warning="Disconnect battery first.", highlight_component="Bottom Cover", duration_seconds=300),
            RepairStep(step=2, title="Locate M.2 Slot", instruction="M.2 slot is near the center of the motherboard, marked M.2.", tools=[], warning=None, highlight_component="NVMe SSD", duration_seconds=30),
            RepairStep(step=3, title="Remove SSD Screw", instruction="Remove single Phillips #1 screw at the end of the SSD.", tools=["Phillips #1 screwdriver"], warning=None, highlight_component="NVMe SSD", duration_seconds=30),
            RepairStep(step=4, title="Remove SSD", instruction="Lift SSD at 30° and pull out of slot.", tools=[], warning="Handle by edges — avoid touching controller chips.", highlight_component="NVMe SSD", duration_seconds=30),
            RepairStep(step=5, title="Install New SSD", instruction="Insert new SSD at 30°. Press down flat and replace screw.", tools=["Phillips #1 screwdriver"], warning=None, highlight_component="NVMe SSD", duration_seconds=60),
        ],
    }
    return base_steps.get(repair_type, [])
