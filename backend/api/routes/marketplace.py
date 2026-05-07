"""
Marketplace routes — compatible parts search, price comparison, technicians.
"""
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from typing import Optional

from services.database.scan_repository import ScanRepository
from api.middleware.auth import get_current_user

router = APIRouter()


class Part(BaseModel):
    id: str
    name: str
    brand: str
    part_number: str
    compatibility: str
    compatibility_score: float
    price_usd: float
    rating: float
    review_count: int
    availability: str
    condition: str
    vendor: str
    vendor_url: str
    shipping_days: int
    image_url: Optional[str] = None


class Technician(BaseModel):
    id: str
    name: str
    specialty: str
    rating: float
    review_count: int
    distance_km: float
    price_range: str
    available: bool
    address: str
    phone: Optional[str]
    certified_brands: list[str]


@router.get("/search", response_model=list[Part])
async def search_parts(
    object_id: str,
    q: Optional[str] = None,
    category: Optional[str] = None,
    max_price: Optional[float] = None,
    condition: str = "new",
    current_user=Depends(get_current_user),
):
    """Search for compatible parts for a scanned object."""
    scan = await ScanRepository().get_scan(object_id)
    parts = _mock_compatible_parts(
        scan.get("name", "") if scan else "",
        category=category,
        query=q,
        max_price=max_price,
        condition=condition,
    )
    return parts


@router.get("/compatible/{object_id}", response_model=list[Part])
async def get_compatible_parts(
    object_id: str,
    limit: int = Query(20, le=50),
    current_user=Depends(get_current_user),
):
    """Get auto-detected compatible parts for a specific object."""
    scan = await ScanRepository().get_scan(object_id)
    object_name = scan.get("name", "") if scan else ""
    return _mock_compatible_parts(object_name, limit=limit)


@router.get("/technicians", response_model=list[Technician])
async def get_nearby_technicians(
    latitude: float = 0.0,
    longitude: float = 0.0,
    radius_km: float = 20.0,
    specialty: Optional[str] = None,
    current_user=Depends(get_current_user),
):
    """Find nearby certified repair technicians."""
    return [
        Technician(
            id="tech_001",
            name="TechPro Repairs",
            specialty="Electronics & Laptops",
            rating=4.9,
            review_count=234,
            distance_km=1.2,
            price_range="$$",
            available=True,
            address="123 Main St, Downtown",
            phone="+1-555-0101",
            certified_brands=["Dell", "HP", "Lenovo"],
        ),
        Technician(
            id="tech_002",
            name="QuickFix Center",
            specialty="All Brands Consumer Electronics",
            rating=4.6,
            review_count=891,
            distance_km=2.8,
            price_range="$",
            available=True,
            address="456 Tech Ave",
            phone="+1-555-0202",
            certified_brands=["Apple", "Samsung", "Dell", "HP"],
        ),
        Technician(
            id="tech_003",
            name="Dell Authorized Service",
            specialty="Dell Products",
            rating=4.8,
            review_count=1205,
            distance_km=5.1,
            price_range="$$$",
            available=False,
            address="789 Corporate Blvd",
            phone="+1-555-0303",
            certified_brands=["Dell"],
        ),
    ]


@router.get("/price-compare/{object_id}")
async def compare_prices(
    object_id: str,
    part_name: str,
    current_user=Depends(get_current_user),
):
    """Compare prices across multiple vendors for a specific part."""
    return {
        "part_name": part_name,
        "vendors": [
            {"store": "Amazon", "price": 49.99, "delivery_days": 2, "url": "#"},
            {"store": "eBay", "price": 38.50, "delivery_days": 5, "url": "#"},
            {"store": "iFixit", "price": 54.99, "delivery_days": 1, "url": "#"},
            {"store": "Newegg", "price": 44.99, "delivery_days": 3, "url": "#"},
            {"store": "Dell Official", "price": 79.99, "delivery_days": 1, "url": "#"},
        ],
        "recommendation": "Best value: eBay at $38.50 with 98.3% positive seller feedback.",
        "lowest_price": 38.50,
        "highest_price": 79.99,
    }


def _mock_compatible_parts(
    object_name: str,
    category: Optional[str] = None,
    query: Optional[str] = None,
    max_price: Optional[float] = None,
    condition: str = "new",
    limit: int = 10,
) -> list[Part]:
    parts = [
        Part(id="part_001", name="Dell WDX0R Battery 40Wh 3-Cell", brand="Dell", part_number="WDX0R", compatibility="100% compatible", compatibility_score=1.0, price_usd=49.99, rating=4.8, review_count=1204, availability="In Stock", condition="new", vendor="Amazon", vendor_url="#", shipping_days=2),
        Part(id="part_002", name="8GB DDR4 2666MHz SODIMM", brand="Kingston", part_number="KVR26S19S6/8", compatibility="98% compatible", compatibility_score=0.98, price_usd=32.99, rating=4.6, review_count=892, availability="In Stock", condition="new", vendor="Newegg", vendor_url="#", shipping_days=3),
        Part(id="part_003", name="512GB M.2 PCIe NVMe SSD", brand="Samsung", part_number="MZ-V8P500", compatibility="100% compatible", compatibility_score=1.0, price_usd=79.99, rating=4.9, review_count=2341, availability="In Stock", condition="new", vendor="Amazon", vendor_url="#", shipping_days=1),
        Part(id="part_004", name="15.6\" FHD IPS Display Panel", brand="BOE", part_number="NV156FHM-N48", compatibility="95% compatible", compatibility_score=0.95, price_usd=124.99, rating=4.4, review_count=456, availability="Ships in 3-5 days", condition="new", vendor="AliExpress", vendor_url="#", shipping_days=10),
        Part(id="part_005", name="Dell Laptop Keyboard US Layout", brand="Dell", part_number="0KTFN0", compatibility="100% compatible", compatibility_score=1.0, price_usd=28.99, rating=4.7, review_count=678, availability="In Stock", condition="oem", vendor="eBay", vendor_url="#", shipping_days=4),
    ]
    if max_price:
        parts = [p for p in parts if p.price_usd <= max_price]
    if condition != "all":
        parts = [p for p in parts if p.condition == condition]
    return parts[:limit]
