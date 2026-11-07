"""Gigle-AI gateway: routes /api/gigle/* to the Gigle-AI engine and streams replies as SSE.

Env:
  GIGLE_AI_ENDPOINT           Gigle-AI engine chat endpoint (required), e.g. http://localhost:9000/v1/chat
  GIGLE_AI_API_KEY       Bearer token for the engine (optional)
  GIGLE_ALLOWED_ORIGINS  comma-separated CORS origins (default: https://jenniferlogic.com)
  GIGLE_TIMEOUT          upstream timeout seconds (default 60)
Run: uvicorn server.gigle_server:app --port 8000
"""
import json
import os

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field

app = FastAPI(title="Jennifer Logic - Gigle-AI gateway")
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("GIGLE_ALLOWED_ORIGINS", "https://jenniferlogic.com").split(","),
    allow_methods=["POST", "GET"],
    allow_headers=["Content-Type"],
)

MAX_ATTACHMENT_CHARS = 8_000_000


class Message(BaseModel):
    role: str = Field(pattern="^(user|assistant|system)$")
    content: str = Field(max_length=20000)


class Attachment(BaseModel):
    mime: str = Field(pattern=r"^(image|audio|video)/[\w.+-]+$")
    data: str = Field(max_length=MAX_ATTACHMENT_CHARS)


class ChatRequest(BaseModel):
    messages: list[Message] = Field(min_length=1, max_length=40)
    attachments: list[Attachment] = Field(default_factory=list, max_length=4)
    stream: bool = True


def sse(obj) -> bytes:
    return f"data: {json.dumps(obj)}\n\n".encode()


@app.get("/api/gigle/health")
async def health():
    return {"engine": "Gigle-AI", "configured": bool(os.getenv("GIGLE_AI_ENDPOINT"))}


@app.post("/api/gigle/chat")
async def chat(req: ChatRequest):
    url = os.getenv("GIGLE_AI_ENDPOINT")
    if not url:
        return JSONResponse({"error": "GIGLE_AI_ENDPOINT is not configured on the server"}, status_code=503)
    headers = {"Content-Type": "application/json"}
    if os.getenv("GIGLE_AI_API_KEY"):
        headers["Authorization"] = "Bearer " + os.environ["GIGLE_AI_API_KEY"]
    timeout = float(os.getenv("GIGLE_TIMEOUT", "60"))

    async def stream():
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                async with client.stream("POST", url, headers=headers, json=req.model_dump()) as r:
                    if r.status_code >= 400:
                        yield sse({"error": f"engine returned HTTP {r.status_code}"})
                        return
                    if "text/event-stream" in r.headers.get("content-type", ""):
                        async for line in r.aiter_lines():
                            if line.startswith("data:"):
                                yield (line + "\n\n").encode()
                    else:
                        body = json.loads((await r.aread()) or b"{}")
                        text = body.get("text") or body.get("reply") or body.get("content") or ""
                        yield sse({"text": text})
            yield b"data: [DONE]\n\n"
        except (httpx.HTTPError, ValueError) as e:
            yield sse({"error": f"engine unavailable: {type(e).__name__}"})

    return StreamingResponse(
        stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
