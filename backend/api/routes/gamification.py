"""
Gamification routes — XP, levels, achievements, challenges, leaderboard.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from api.middleware.auth import get_current_user

router = APIRouter()

_XP_TABLE = {
    "scan_object": 50,
    "complete_repair": 150,
    "use_xray_mode": 30,
    "use_ar_measurement": 25,
    "collaborate_session": 75,
    "complete_challenge": 200,
    "daily_login": 10,
    "first_scan": 100,
}

_LEVEL_THRESHOLDS = [
    0, 100, 250, 500, 1000, 1750, 2750, 4000, 5500, 7500,
    10000, 13000, 16500, 20500, 25000,
]

_RANK_NAMES = [
    "Novice", "Explorer", "Tinkerer", "Mechanic", "Engineer",
    "Tech Specialist", "Senior Engineer", "Expert Technician",
    "Master Mechanic", "Elite Engineer", "Principal Engineer",
    "Distinguished Engineer", "Chief Technician", "Senior Architect",
    "Grand Master Engineer",
]

_ACHIEVEMENTS = [
    {"id": "first_scan", "name": "First Scan", "description": "Scan your first object", "xp": 100, "icon": "camera_alt", "category": "scanning"},
    {"id": "master_mechanic", "name": "Master Mechanic", "description": "Complete 10 repair guides", "xp": 500, "icon": "build", "category": "repair"},
    {"id": "electronics_surgeon", "name": "Electronics Surgeon", "description": "Scan 20 electronic devices", "xp": 400, "icon": "memory", "category": "scanning"},
    {"id": "engine_expert", "name": "Engine Expert", "description": "Scan and analyze an engine", "xp": 350, "icon": "settings", "category": "scanning"},
    {"id": "xray_vision", "name": "X-Ray Vision", "description": "Use X-Ray mode 25 times", "xp": 250, "icon": "blur_on", "category": "features"},
    {"id": "collaborator", "name": "Collaborator", "description": "Complete 5 collaboration sessions", "xp": 300, "icon": "people", "category": "social"},
    {"id": "speed_demon", "name": "Speed Demon", "description": "Complete 3 scans in under 5 minutes", "xp": 200, "icon": "flash_on", "category": "scanning"},
    {"id": "perfectionist", "name": "Perfectionist", "description": "Achieve 100% health score on 10 objects", "xp": 450, "icon": "star", "category": "diagnostics"},
    {"id": "reverse_engineer", "name": "Reverse Engineer", "description": "Generate blueprints for 5 objects", "xp": 600, "icon": "architecture", "category": "advanced"},
    {"id": "marketplace_maven", "name": "Parts Maven", "description": "Order 10 compatible parts", "xp": 300, "icon": "shopping_bag", "category": "marketplace"},
]


class AwardXPRequest(BaseModel):
    action: str
    object_id: Optional[str] = None


@router.get("/achievements")
async def get_achievements(current_user=Depends(get_current_user)):
    """Return all achievements with unlock status for current user."""
    # In production, query DB for user's unlocked achievements
    mock_unlocked = {"first_scan", "master_mechanic", "electronics_surgeon", "engine_expert", "xray_vision"}

    return {
        "achievements": [
            {**a, "unlocked": a["id"] in mock_unlocked}
            for a in _ACHIEVEMENTS
        ],
        "total": len(_ACHIEVEMENTS),
        "unlocked_count": len(mock_unlocked),
    }


@router.get("/stats")
async def get_user_stats(current_user=Depends(get_current_user)):
    """Get full gamification profile for current user."""
    xp = 2840
    level = _xp_to_level(xp)

    return {
        "user_id": current_user.id,
        "xp": xp,
        "level": level,
        "rank_name": _RANK_NAMES[min(level - 1, len(_RANK_NAMES) - 1)],
        "xp_to_next_level": _XP_TABLE.get("next_level", _LEVEL_THRESHOLDS[min(level, 14)]) - xp,
        "next_level_threshold": _LEVEL_THRESHOLDS[min(level, 14)],
        "total_scans": 47,
        "total_repairs": 23,
        "total_collaborations": 8,
        "badges_earned": 5,
        "streak_days": 12,
        "favorite_category": "Electronics",
        "joined_date": "2024-01-15T00:00:00Z",
    }


@router.get("/challenges")
async def get_challenges(current_user=Depends(get_current_user)):
    """Get active and upcoming challenges."""
    return {
        "daily": [
            {"id": "d1", "title": "Scan 2 Objects Today", "progress": 1, "total": 2, "xp": 80, "expires_hours": 18},
            {"id": "d2", "title": "Use AI Assistant 3 Times", "progress": 2, "total": 3, "xp": 60, "expires_hours": 18},
        ],
        "weekly": [
            {"id": "w1", "title": "Scan 5 Electronics", "progress": 3, "total": 5, "xp": 200, "expires_days": 4},
            {"id": "w2", "title": "Complete 3 Repair Guides", "progress": 1, "total": 3, "xp": 350, "expires_days": 4},
            {"id": "w3", "title": "Use X-Ray Mode × 10", "progress": 7, "total": 10, "xp": 150, "expires_days": 4},
        ],
        "monthly": [
            {"id": "m1", "title": "Scan 20 Unique Object Categories", "progress": 8, "total": 20, "xp": 1000, "expires_days": 22},
        ],
    }


@router.post("/award-xp")
async def award_xp(request: AwardXPRequest, current_user=Depends(get_current_user)):
    """Award XP for completing an in-app action."""
    xp_earned = _XP_TABLE.get(request.action, 10)
    return {
        "action": request.action,
        "xp_earned": xp_earned,
        "total_xp": 2840 + xp_earned,
        "level_up": False,
    }


@router.get("/leaderboard")
async def get_leaderboard(
    scope: str = "global",
    limit: int = 20,
    current_user=Depends(get_current_user),
):
    """Get global or friend leaderboard."""
    mock_board = [
        {"rank": 1, "username": "TechMaster_Pro", "xp": 18420, "level": 14, "scans": 312},
        {"rank": 2, "username": "EngineerX9", "xp": 15230, "level": 13, "scans": 278},
        {"rank": 3, "username": "ARMechanic", "xp": 12890, "level": 12, "scans": 201},
        {"rank": 4, "username": "DigitalTwinFan", "xp": 9870, "level": 11, "scans": 156},
        {"rank": 5, "username": "FixItAll", "xp": 7650, "level": 10, "scans": 134},
        {"rank": 12, "username": "You", "xp": 2840, "level": 7, "scans": 47, "is_current_user": True},
    ]
    return {"scope": scope, "entries": mock_board[:limit]}


def _xp_to_level(xp: int) -> int:
    for i, threshold in enumerate(reversed(_LEVEL_THRESHOLDS)):
        if xp >= threshold:
            return len(_LEVEL_THRESHOLDS) - i
    return 1
