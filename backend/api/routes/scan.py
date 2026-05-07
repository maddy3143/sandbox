"""
Scan routes — handle object image upload and AI analysis pipeline.
"""
import uuid
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Form
from fastapi.responses import JSONResponse
from typing import Optional
import json

from ..schemas.scan_schemas import ScanResponse, ScanHistoryResponse
from services.ai.object_recognizer import ObjectRecognizer
from services.ai.material_analyzer import MaterialAnalyzer
from services.ai.measurement_estimator import MeasurementEstimator
from services.ai.digital_twin_generator import DigitalTwinGenerator
from services.storage.s3_service import S3Service
from services.database.scan_repository import ScanRepository
from api.middleware.auth import get_current_user

router = APIRouter()


@router.post("/analyze", response_model=ScanResponse)
async def analyze_object(
    image: UploadFile = File(...),
    metadata: str = Form(default="{}"),
    current_user=Depends(get_current_user),
):
    """
    Full AI analysis pipeline:
    1. Object recognition (YOLOv8 + Google Vision)
    2. Material classification
    3. Measurement estimation (depth + reference)
    4. Component segmentation
    5. Digital twin generation trigger
    6. Knowledge database lookup
    """
    object_id = str(uuid.uuid4())
    meta = json.loads(metadata)

    # Validate file type
    if image.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(status_code=400, detail="Unsupported image format")

    # Save image to S3
    image_bytes = await image.read()
    image_url = await S3Service().upload_image(
        image_bytes=image_bytes,
        object_id=object_id,
        content_type=image.content_type,
    )

    # Run AI pipeline (concurrently where possible)
    recognizer = ObjectRecognizer()
    recognition_result = await recognizer.recognize(image_bytes, meta)

    material_analyzer = MaterialAnalyzer()
    material_result = await material_analyzer.analyze(image_bytes)

    measurement_estimator = MeasurementEstimator()
    measurements = await measurement_estimator.estimate(
        image_bytes,
        reference_size_cm=meta.get("reference_size_cm"),
    )

    # Fetch technical specs from knowledge base
    specs = await recognizer.fetch_specs(
        recognition_result["product_name"],
        recognition_result["brand"],
    )

    # Build full response
    scan_data = {
        "id": object_id,
        "name": recognition_result.get("product_name", "Unknown Object"),
        "brand": recognition_result.get("brand", "Unknown"),
        "model": recognition_result.get("model", "Unknown"),
        "estimated_year": recognition_result.get("year", "Unknown"),
        "category": recognition_result.get("category", "unknown"),
        "description": recognition_result.get("description", ""),
        "probable_use_case": recognition_result.get("use_case", ""),
        "confidence_score": recognition_result.get("confidence", 0.0),
        "image_path": image_url,
        "thumbnail_url": image_url,
        "model_3d_url": None,  # Will be populated after twin generation
        "measurements": measurements,
        "components": recognition_result.get("components", []),
        "material_analysis": material_result,
        "damage_report": None,
        "scanned_at": recognition_result.get("scanned_at"),
        "status": "complete",
        "technical_specs": specs,
    }

    # Persist to database
    await ScanRepository().save_scan(scan_data, user_id=current_user.id)

    # Trigger async digital twin generation
    twin_generator = DigitalTwinGenerator()
    await twin_generator.trigger_generation(object_id=object_id, image_url=image_url)

    return JSONResponse(content=scan_data)


@router.get("/history", response_model=list[ScanHistoryResponse])
async def get_scan_history(
    limit: int = 20,
    offset: int = 0,
    current_user=Depends(get_current_user),
):
    """Retrieve paginated scan history for the current user."""
    scans = await ScanRepository().get_user_scans(
        user_id=current_user.id,
        limit=limit,
        offset=offset,
    )
    return scans


@router.get("/{object_id}", response_model=ScanResponse)
async def get_scan(object_id: str, current_user=Depends(get_current_user)):
    """Get a specific scanned object by ID."""
    scan = await ScanRepository().get_scan(object_id)
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    return scan


@router.delete("/{object_id}")
async def delete_scan(object_id: str, current_user=Depends(get_current_user)):
    """Delete a scanned object."""
    await ScanRepository().delete_scan(object_id, user_id=current_user.id)
    return {"message": "Deleted successfully"}
