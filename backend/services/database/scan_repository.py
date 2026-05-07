"""
Scan repository — async MongoDB/PostgreSQL persistence layer.
"""
from typing import Optional
from datetime import datetime


class ScanRepository:
    """
    Handles all persistence for scanned object data.
    Uses an in-memory store for development; swap for MongoDB in production.
    """
    _store: dict[str, dict] = {}

    async def save_scan(self, scan_data: dict, user_id: str) -> str:
        scan_data["user_id"] = user_id
        scan_data["saved_at"] = datetime.utcnow().isoformat()
        self._store[scan_data["id"]] = scan_data
        return scan_data["id"]

    async def get_scan(self, object_id: str) -> Optional[dict]:
        return self._store.get(object_id)

    async def get_user_scans(
        self,
        user_id: str,
        limit: int = 20,
        offset: int = 0,
    ) -> list[dict]:
        user_scans = [
            s for s in self._store.values()
            if s.get("user_id") == user_id
        ]
        user_scans.sort(key=lambda x: x.get("scanned_at", ""), reverse=True)
        return user_scans[offset : offset + limit]

    async def update_damage_report(self, object_id: str, damage_report: dict) -> None:
        if object_id in self._store:
            self._store[object_id]["damage_report"] = damage_report

    async def update_model_url(self, object_id: str, model_url: str) -> None:
        if object_id in self._store:
            self._store[object_id]["model_3d_url"] = model_url

    async def delete_scan(self, object_id: str, user_id: str) -> None:
        scan = self._store.get(object_id)
        if scan and scan.get("user_id") == user_id:
            del self._store[object_id]

    async def search_scans(
        self,
        user_id: str,
        query: str,
        category: Optional[str] = None,
    ) -> list[dict]:
        results = []
        for scan in self._store.values():
            if scan.get("user_id") != user_id:
                continue
            name_match = query.lower() in scan.get("name", "").lower()
            cat_match = category is None or scan.get("category") == category
            if name_match and cat_match:
                results.append(scan)
        return results
