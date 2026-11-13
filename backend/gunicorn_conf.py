"""
Production Gunicorn Configuration for Imago / Yoetz Backend.
Designed for high-concurrency multi-worker scaling behind Layer 7 Load Balancers (Cloudflare / Render / AWS ALB).
"""

import multiprocessing
import os

# Server socket
port = os.getenv("PORT", "8000")
bind = f"0.0.0.0:{port}"

# Worker processes
# Uses WEB_CONCURRENCY if set, otherwise scales with CPU cores (min 2, default 4)
default_workers = max(2, multiprocessing.cpu_count() * 2)
workers = int(os.getenv("WEB_CONCURRENCY", default_workers))
worker_class = "uvicorn.workers.UvicornWorker"

# Networking & timeouts
backlog = 2048
timeout = int(os.getenv("GUNICORN_TIMEOUT", "120"))
keepalive = int(os.getenv("GUNICORN_KEEPALIVE", "65"))

# Worker lifecycle
max_requests = 10000
max_requests_jitter = 1000

# Logging
accesslog = "-"
errorlog = "-"
loglevel = os.getenv("LOG_LEVEL", "info")

