"""Database initialisation."""
import logging
logger = logging.getLogger(__name__)


async def init_db():
    logger.info("Database layer initialised (in-memory dev mode).")
