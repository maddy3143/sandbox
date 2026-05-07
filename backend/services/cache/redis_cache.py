"""Redis cache initialisation and helpers."""
import logging
logger = logging.getLogger(__name__)

_cache: dict = {}


async def init_cache():
    logger.info("Cache layer initialised (in-memory dev mode).")


async def get(key: str):
    return _cache.get(key)


async def set(key: str, value, ttl: int = 3600):
    _cache[key] = value


async def delete(key: str):
    _cache.pop(key, None)
