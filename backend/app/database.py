"""
Database & Connection Pooler Layer for Imago / Yoetz Backend.

Architectural Role:
- Configures async SQLAlchemy engine with connection pooling.
- Designed to sit behind an external connection pooler (e.g., PgBouncer, Supabase Supavisor)
  on port 6543 or connect to a direct PostgreSQL instance.
- Multiplexes concurrent backend worker transactions into a bounded set of warm physical connections.
- Provides health checking probes for the Load Balancer layer.
"""

import os
import time
import logging
from typing import AsyncGenerator, Dict, Any, Optional
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    create_async_engine,
    async_sessionmaker,
    AsyncSession,
    AsyncEngine,
)
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import text

logger = logging.getLogger("imago.database")

# Base class for SQLAlchemy ORM models
class Base(DeclarativeBase):
    pass

# Retrieve connection strings from environment
# In production, DATABASE_URL points to the connection pooler (e.g. port 6543)
RAW_DATABASE_URL = os.getenv("DATABASE_URL", "").strip()

# Normalize URL to asyncpg driver if postgresql:// is provided
def get_async_database_url(url: str) -> Optional[str]:
    if not url:
        return None
    if url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql+asyncpg://", 1)
    elif url.startswith("postgresql://") and not url.startswith("postgresql+asyncpg://"):
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
    return url

ASYNC_DATABASE_URL = get_async_database_url(RAW_DATABASE_URL)

engine: Optional[AsyncEngine] = None
AsyncSessionLocal: Optional[async_sessionmaker[AsyncSession]] = None

if ASYNC_DATABASE_URL:
    try:
        # Connection Pool Configuration (Optimized for Transaction Poolers like PgBouncer / Supavisor)
        engine = create_async_engine(
            ASYNC_DATABASE_URL,
            echo=os.getenv("SQL_DEBUG", "false").lower() == "true",
            pool_size=int(os.getenv("DB_POOL_SIZE", "10")),         # Baseline warm connections per worker
            max_overflow=int(os.getenv("DB_MAX_OVERFLOW", "5")),    # Burst capacity for high concurrency
            pool_timeout=float(os.getenv("DB_POOL_TIMEOUT", "10.0")), # Fail fast if pool is saturated
            pool_recycle=int(os.getenv("DB_POOL_RECYCLE", "1800")), # Recycle connections every 30m
            pool_pre_ping=True,                                     # Verify connection health before query
        )
        AsyncSessionLocal = async_sessionmaker(
            bind=engine,
            class_=AsyncSession,
            autocommit=False,
            autoflush=False,
            expire_on_commit=False,
        )
        logger.info("Database connection pooler initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize database engine: {e}")
        engine = None
        AsyncSessionLocal = None
else:
    logger.info("No DATABASE_URL configured. Database pooling initialized in dormant mode.")

async def get_db_session() -> AsyncGenerator[Optional[AsyncSession], None]:
    """
    FastAPI dependency yielding a managed async database session.
    Automatically commits on success or rolls back on exceptions,
    returning the connection to the pool immediately upon completion.
    """
    if AsyncSessionLocal is None:
        yield None
        return

    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

async def check_db_health() -> Dict[str, Any]:
    """
    Executes a fast probe to verify connection pooler responsiveness
    for Load Balancer health checks and monitoring.
    """
    if engine is None:
        return {
            "status": "dormant",
            "message": "DATABASE_URL not configured (running in stateless RAG mode)",
            "pool": None,
        }

    start = time.perf_counter()
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        latency_ms = round((time.perf_counter() - start) * 1000, 2)

        pool = engine.pool
        return {
            "status": "healthy",
            "latency_ms": latency_ms,
            "pool": {
                "size": pool.size(),
                "checked_in": pool.checkedin(),
                "checked_out": pool.checkedout(),
                "overflow": pool.overflow(),
            },
        }
    except Exception as e:
        logger.warning(f"Database health check failed: {e}")
        return {
            "status": "unhealthy",
            "error": str(e),
            "pool": None,
        }

