#!/bin/sh
# Usage: GIGLE_AI_ENDPOINT=<engine url> ./run-local.sh   (then open http://localhost:8000/builder.html)
cd "$(dirname "$0")"
export GIGLE_SERVE_STATIC=1 GIGLE_ALLOWED_ORIGINS=http://localhost:8000
export GIGLE_PERSONA="${GIGLE_PERSONA:-$(cat persona.example.txt)}"
exec .venv/bin/uvicorn server.gigle_server:app --port 8000
