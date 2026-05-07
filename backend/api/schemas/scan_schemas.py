"""Pydantic schemas for scan API responses."""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class MeasurementsSchema(BaseModel):
    height_cm: float
    width_cm: float
    depth_cm: float
    diameter_cm: Optional[float] = None
    weight_kg: float
    surface_area_cm2: float
    volume_cm3: float
    confidence_score: float


class ComponentSchema(BaseModel):
    id: str
    name: str
    description: str
    function: str
    material: str
    bounding_box: list[float]
    is_removable: bool
    connected_to: list[str]
    repair_note: Optional[str] = None
    image_url: Optional[str] = None


class MaterialAnalysisSchema(BaseModel):
    primary_material: str
    secondary_material: Optional[str] = None
    surface_finish: str
    estimated_weight_kg: float
    durability_score: float
    heat_resistance: str
    corrosion_resistance: str
    manufacturing_process: Optional[str] = None


class DamageReportSchema(BaseModel):
    damage_detected: bool
    damage_types: list[str]
    severity: str
    affected_area_percentage: float
    health_score: int
    repair_urgency: str
    recommendations: list[str]
    estimated_repair_cost_usd: float


class ScanResponse(BaseModel):
    id: str
    name: str
    brand: str
    model: str
    estimated_year: str
    category: str
    description: str
    probable_use_case: str
    confidence_score: float
    image_path: str
    thumbnail_url: Optional[str] = None
    model_3d_url: Optional[str] = None
    measurements: MeasurementsSchema
    components: list[ComponentSchema]
    material_analysis: MaterialAnalysisSchema
    damage_report: Optional[DamageReportSchema] = None
    scanned_at: str
    status: str


class ScanHistoryResponse(BaseModel):
    id: str
    name: str
    category: str
    thumbnail_url: Optional[str] = None
    confidence_score: float
    scanned_at: str
    status: str
