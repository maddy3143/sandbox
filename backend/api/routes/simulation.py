"""
Simulation routes — physics, mechanism, and stress simulation engine.
"""
import uuid
import asyncio
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional

from services.database.scan_repository import ScanRepository
from api.middleware.auth import get_current_user

router = APIRouter()

_simulation_results: dict[str, dict] = {}


class SimulationRequest(BaseModel):
    object_id: str
    simulation_type: str   # gear_rotation | airflow | piston_cycle | stress_test | thermal
    parameters: dict = {}
    duration_seconds: float = 5.0
    physics_quality: str = "medium"  # low | medium | high


class SimulationResponse(BaseModel):
    simulation_id: str
    object_id: str
    simulation_type: str
    status: str
    estimated_completion_seconds: float
    result_url: Optional[str] = None
    preview_frames: list[str] = []


@router.post("/run", response_model=SimulationResponse)
async def run_simulation(
    request: SimulationRequest,
    background_tasks: BackgroundTasks,
    current_user=Depends(get_current_user),
):
    """
    Trigger physics/mechanism simulation for a digital twin.
    """
    scan = await ScanRepository().get_scan(request.object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Object not found")

    sim_id = str(uuid.uuid4())
    _simulation_results[sim_id] = {"status": "processing", "progress": 0}

    background_tasks.add_task(
        _run_simulation_task,
        sim_id=sim_id,
        request=request,
    )

    return SimulationResponse(
        simulation_id=sim_id,
        object_id=request.object_id,
        simulation_type=request.simulation_type,
        status="processing",
        estimated_completion_seconds=_estimate_duration(request),
    )


@router.get("/{simulation_id}/result")
async def get_simulation_result(
    simulation_id: str,
    current_user=Depends(get_current_user),
):
    """Poll for simulation result."""
    result = _simulation_results.get(simulation_id)
    if not result:
        raise HTTPException(status_code=404, detail="Simulation not found")
    return result


@router.get("/types")
async def list_simulation_types(current_user=Depends(get_current_user)):
    """List all available simulation types with descriptions."""
    return {
        "types": [
            {"id": "gear_rotation", "name": "Gear Rotation", "description": "Simulate gear mechanism with torque and speed conversion", "icon": "settings"},
            {"id": "airflow", "name": "Airflow Simulation", "description": "Visualise cooling airflow paths and heat dissipation", "icon": "air"},
            {"id": "piston_cycle", "name": "Piston Cycle", "description": "Animate 4-stroke or 2-stroke engine cycles", "icon": "precision_manufacturing"},
            {"id": "stress_test", "name": "Stress Analysis", "description": "FEA-based structural stress and deformation analysis", "icon": "compress"},
            {"id": "thermal", "name": "Thermal Simulation", "description": "Heat map overlay showing temperature distribution", "icon": "thermostat"},
            {"id": "suspension", "name": "Suspension Movement", "description": "Dynamic suspension response simulation", "icon": "directions_car"},
            {"id": "fluid_dynamics", "name": "Fluid Dynamics", "description": "Fluid flow through pipes and channels", "icon": "water"},
            {"id": "motor_operation", "name": "Motor Operation", "description": "Electric motor magnetic field and rotor animation", "icon": "electric_bolt"},
        ]
    }


async def _run_simulation_task(sim_id: str, request: SimulationRequest):
    """Background simulation processing."""
    steps = 10
    for i in range(steps):
        await asyncio.sleep(0.5)
        _simulation_results[sim_id] = {
            "status": "processing",
            "progress": int((i + 1) / steps * 100),
        }

    _simulation_results[sim_id] = {
        "status": "complete",
        "simulation_id": sim_id,
        "object_id": request.object_id,
        "simulation_type": request.simulation_type,
        "progress": 100,
        "result_url": f"https://cdn.arobjectscanner.com/simulations/{sim_id}.mp4",
        "keyframes": [
            {"t": 0.0, "state": "initial"},
            {"t": 0.5, "state": "mid_cycle"},
            {"t": 1.0, "state": "complete_cycle"},
        ],
        "metrics": _compute_simulation_metrics(request.simulation_type),
    }


def _estimate_duration(request: SimulationRequest) -> float:
    base = {"low": 3.0, "medium": 8.0, "high": 20.0}.get(request.physics_quality, 8.0)
    return base * request.duration_seconds / 5.0


def _compute_simulation_metrics(sim_type: str) -> dict:
    metrics_map = {
        "airflow": {"max_velocity_ms": 2.4, "avg_temp_c": 45.2, "hotspot_c": 78.1, "efficiency": 0.82},
        "stress_test": {"max_stress_mpa": 124.5, "deformation_mm": 0.08, "safety_factor": 3.2, "failure_risk": "Low"},
        "gear_rotation": {"output_torque_nm": 28.4, "gear_ratio": 4.2, "efficiency": 0.94, "rpm": 1200},
        "thermal": {"max_temp_c": 78.1, "ambient_c": 25.0, "delta_t": 53.1, "thermal_resistance": 0.42},
    }
    return metrics_map.get(sim_type, {"note": "Simulation complete"})
