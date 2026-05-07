"""
Digital Twin routes — 3D model generation and component inspection.
"""
import asyncio
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional

from services.database.scan_repository import ScanRepository
from services.ai.digital_twin_generator import DigitalTwinGenerator
from api.middleware.auth import get_current_user

router = APIRouter()


class TwinGenerationRequest(BaseModel):
    object_id: str
    quality: str = "high"      # low | medium | high | ultra
    style: str = "realistic"   # realistic | wireframe | holographic


class TwinResponse(BaseModel):
    object_id: str
    model_url: Optional[str]
    thumbnail_url: Optional[str]
    component_count: int
    poly_count: int
    texture_resolution: str
    generation_status: str
    render_quality: str


class ComponentDetailResponse(BaseModel):
    id: str
    name: str
    description: str
    function: str
    material: str
    bounding_box: list[float]
    is_removable: bool
    connected_to: list[str]
    health_score: int
    repair_note: Optional[str]


@router.post("/generate", response_model=TwinResponse)
async def generate_twin(
    request: TwinGenerationRequest,
    background_tasks: BackgroundTasks,
    current_user=Depends(get_current_user),
):
    """
    Trigger 3D digital twin generation.
    Uses NeRF or Gaussian Splatting based on quality setting.
    """
    scan = await ScanRepository().get_scan(request.object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Object not found")

    generator = DigitalTwinGenerator()

    # Kick off generation in background for high-quality modes
    if request.quality in ("high", "ultra"):
        background_tasks.add_task(
            generator.generate_nerf,
            object_id=request.object_id,
            image_url=scan.get("image_path", ""),
            quality=request.quality,
        )
        poly_count = 148 if request.quality == "ultra" else 48
    else:
        await generator.generate_fast(
            object_id=request.object_id,
            category=scan.get("category", "unknown"),
        )
        poly_count = 12

    return TwinResponse(
        object_id=request.object_id,
        model_url=scan.get("model_3d_url"),
        thumbnail_url=scan.get("thumbnail_url"),
        component_count=len(scan.get("components", [])),
        poly_count=poly_count,
        texture_resolution="4096x4096" if request.quality == "ultra" else "2048x2048",
        generation_status="processing" if request.quality in ("high", "ultra") else "complete",
        render_quality=request.quality.upper(),
    )


@router.get("/{object_id}/model")
async def get_model(object_id: str, current_user=Depends(get_current_user)):
    """Get 3D model URL for a digital twin."""
    scan = await ScanRepository().get_scan(object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Object not found")

    return {
        "object_id": object_id,
        "model_url": scan.get("model_3d_url"),
        "format": "glb",
        "status": "ready" if scan.get("model_3d_url") else "processing",
    }


@router.get("/{object_id}/components", response_model=list[ComponentDetailResponse])
async def get_components(object_id: str, current_user=Depends(get_current_user)):
    """Get all identified components for a digital twin."""
    scan = await ScanRepository().get_scan(object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Object not found")

    components = scan.get("components", [])
    return [ComponentDetailResponse(**c, health_score=95) for c in components]


@router.get("/{object_id}/exploded")
async def get_exploded_view(object_id: str, current_user=Depends(get_current_user)):
    """Get exploded view configuration with part offsets."""
    scan = await ScanRepository().get_scan(object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Object not found")

    components = scan.get("components", [])
    exploded_config = []
    for i, comp in enumerate(components):
        exploded_config.append({
            "component_id": comp["id"],
            "name": comp["name"],
            "explode_offset": [0, (i - len(components) / 2) * 0.15, 0],
            "explode_rotation": [0, 0, 0],
            "assembly_step": i + 1,
        })

    return {
        "object_id": object_id,
        "total_steps": len(components),
        "components": exploded_config,
    }


@router.get("/{object_id}/assembly")
async def get_assembly_steps(object_id: str, current_user=Depends(get_current_user)):
    """Get ordered assembly/disassembly steps."""
    scan = await ScanRepository().get_scan(object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Object not found")

    return {
        "object_id": object_id,
        "steps": [
            {
                "step": i + 1,
                "component_id": comp["id"],
                "action": f"Remove {comp['name']}",
                "tools": ["Torx T5 screwdriver"],
                "duration_seconds": 120,
                "caution": comp.get("repair_note"),
            }
            for i, comp in enumerate(scan.get("components", []))
            if comp.get("is_removable", False)
        ],
    }


@router.get("/{object_id}/xray")
async def get_xray_model(object_id: str, current_user=Depends(get_current_user)):
    """Get X-ray / internal structure visualization data."""
    scan = await ScanRepository().get_scan(object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Object not found")

    return {
        "object_id": object_id,
        "internal_layers": [
            {
                "name": "Circuit Board",
                "depth": 0.3,
                "color": "#00F5FF",
                "components": ["Motherboard", "CPU", "RAM", "GPU"],
            },
            {
                "name": "Power System",
                "depth": 0.7,
                "color": "#00FF88",
                "components": ["Battery", "Power Regulator", "Charging IC"],
            },
            {
                "name": "Thermal",
                "depth": 0.5,
                "color": "#FF6B00",
                "components": ["Heatsink", "Thermal Paste", "Cooling Fan"],
            },
            {
                "name": "Storage",
                "depth": 0.4,
                "color": "#8B00FF",
                "components": ["NVMe SSD", "SD Card Reader"],
            },
        ],
    }
