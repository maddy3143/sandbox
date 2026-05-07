from .scan import router as scan_router
from .twin import router as twin_router
from .assistant import router as assistant_router
from .repair import router as repair_router
from .diagnostics import router as diagnostics_router
from .marketplace import router as marketplace_router
from .collaboration import router as collaboration_router
from .gamification import router as gamification_router
from .simulation import router as simulation_router

__all__ = [
    "scan_router",
    "twin_router",
    "assistant_router",
    "repair_router",
    "diagnostics_router",
    "marketplace_router",
    "collaboration_router",
    "gamification_router",
    "simulation_router",
]
