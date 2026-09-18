"""Live preview server for the KOVA Ai iOS app.

Serves a browser rendering of the SwiftUI screens (``preview/web``) plus a local
API that mirrors the five routes declared in ``tenx.yaml`` for
``backend/app/routes/training.py``. Request/response validation reuses the real
Pydantic schemas from ``backend/app/schemas.py``.

Run:  preview/.venv/bin/python preview/server.py   (binds 0.0.0.0:8080)
"""

from __future__ import annotations

import hashlib
import json
import sys
import time
from pathlib import Path
from typing import Any, Literal

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

PREVIEW_ROOT = Path(__file__).resolve().parent
if str(PREVIEW_ROOT) not in sys.path:
    sys.path.insert(0, str(PREVIEW_ROOT))

import store  # noqa: E402
from backend_bridge import (  # noqa: E402
    NEXT_FOCUS,
    WORKOUTS,
    ProfileUpdatePayload,
    WorkoutCompletionPayload,
    user_id,
)

WEB_DIR = PREVIEW_ROOT / "web"
HOST = "0.0.0.0"
PORT = int(__import__("os").environ.get("PREVIEW_PORT", "8080"))

app = FastAPI(title="KOVA Ai — live preview", version="1.0", docs_url="/api/docs", openapi_url="/api/openapi.json")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

store.init_schema()


# --------------------------------------------------------------------- auth plumbing


class SignUpPayload(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=8, max_length=128)


class SignInPayload(SignUpPayload):
    pass


class DeleteAccountPayload(BaseModel):
    password: str = Field(min_length=1, max_length=128)


class ReminderPayload(BaseModel):
    reminder_hour: int = Field(ge=0, le=23)
    reminder_minute: int = Field(ge=0, le=59)


def bearer_token(request: Request) -> str | None:
    header = request.headers.get("authorization") or ""
    if header.lower().startswith("bearer "):
        return header[7:].strip()
    return None


def current_claims(request: Request) -> dict[str, Any]:
    """Preview stand-in for the generated ``app.tenx_auth.current_user``."""
    owner_id, _email = store.resolve_token(bearer_token(request))
    if owner_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sign in to continue with your saved coaching plan.",
        )
    return {"sub": owner_id}


def current_owner(claims: dict[str, Any] = Depends(current_claims)) -> str:
    return user_id(claims)  # real helper from backend/app/routes/training.py


# --------------------------------------------------------------------- preview meta


def web_fingerprint() -> str:
    digest = hashlib.sha256()
    for path in sorted(WEB_DIR.rglob("*")):
        if path.is_file():
            digest.update(str(path.relative_to(WEB_DIR)).encode())
            digest.update(path.read_bytes())
    return digest.hexdigest()[:16]


@app.get("/preview/version")
async def preview_version() -> dict[str, Any]:
    return {"version": web_fingerprint(), "time": time.time()}


@app.get("/preview/facts")
async def preview_facts() -> dict[str, Any]:
    return {
        "backend": {
            "prescriptions": {focus: len(exercises) for focus, exercises in WORKOUTS.items()},
            "rotation": NEXT_FOCUS,
            "routes": [
                "GET  /api/v1/active-plan",
                "PUT  /api/v1/profile",
                "POST /api/v1/workout-completions",
                "GET  /api/v1/workout-history",
                "GET  /api/v1/progress-summary",
            ],
        },
        "storage": store.preview_facts(),
    }


@app.post("/preview/reset")
async def reset_preview(owner_id: str = Depends(current_owner)) -> dict[str, Any]:
    store.reset_demo_state(owner_id)
    return {"ok": True, "active_plan": store.active_plan_for(owner_id)}


# --------------------------------------------------------------------- preview auth
# Stand-in for 10x managed better-auth (email + password, iosTokenBridge).


@app.post("/preview/auth/signup")
async def signup(payload: SignUpPayload) -> dict[str, Any]:
    email = payload.email.strip().lower()
    try:
        owner_id, token = store.create_account(email, payload.password)
    except Exception:  # sqlite3.IntegrityError on duplicate email
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="An account with this email already exists.")
    return {"token": token, "user": {"id": owner_id, "email": email}}


@app.post("/preview/auth/signin")
async def signin(payload: SignInPayload) -> dict[str, Any]:
    result = store.sign_in(payload.email.strip(), payload.password)
    if result is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password.")
    owner_id, token = result
    return {"token": token, "user": {"id": owner_id, "email": payload.email.strip().lower()}}


@app.get("/preview/auth/session")
async def session(request: Request) -> dict[str, Any]:
    owner_id, email = store.resolve_token(bearer_token(request))
    if owner_id is None:
        return {"authenticated": False, "user": None}
    return {"authenticated": True, "user": {"id": owner_id, "email": email}}


@app.post("/preview/auth/signout")
async def signout(request: Request) -> dict[str, Any]:
    store.revoke_token(bearer_token(request))
    return {"ok": True}


@app.post("/preview/auth/delete")
async def delete_account(payload: DeleteAccountPayload, owner_id: str = Depends(current_owner)) -> dict[str, Any]:
    if not store.delete_account(owner_id, payload.password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Password does not match this account.")
    return {"ok": True}


# --------------------------------------------------------------------- training API
# Same paths, methods and payloads the Swift client calls (see tenx.yaml routes).


@app.get("/api/v1/active-plan")
async def get_active_plan(owner_id: str = Depends(current_owner)) -> dict[str, Any]:
    return store.active_plan_for(owner_id)


@app.put("/api/v1/profile")
async def update_profile(payload: ProfileUpdatePayload, owner_id: str = Depends(current_owner)) -> dict[str, Any]:
    return store.write_profile(owner_id, payload.goal, payload.days_per_week, payload.equipment)


@app.get("/api/v1/coaching-profile")
async def get_coaching_profile(owner_id: str = Depends(current_owner)) -> dict[str, Any]:
    """Mirror of the Swift ``TenxData.select(table: "coaching_profiles")`` call.

    A brand-new account has no row yet, exactly like the production data API:
    the client then keeps the profile it collected during onboarding.
    """
    profile = store.read_profile(owner_id)
    return {"items": [profile] if profile else []}


class PlanAdjustmentPayload(BaseModel):
    focus: Literal["push", "pull", "legs", "upper"]
    estimated_minutes: int = Field(ge=15, le=180)
    intensity_note: str = Field(min_length=2, max_length=80)
    rationale: str = Field(min_length=2, max_length=280)


@app.put("/api/v1/active-plan")
async def adjust_active_plan(
    payload: PlanAdjustmentPayload, owner_id: str = Depends(current_owner)
) -> dict[str, Any]:
    """Preview extension backing TodayView's 'Swap or regenerate' dialog."""
    return store.adjust_active_plan(
        owner_id,
        payload.focus,
        payload.estimated_minutes,
        payload.intensity_note,
        payload.rationale,
    )


@app.put("/api/v1/reminder")
async def update_reminder(payload: ReminderPayload, owner_id: str = Depends(current_owner)) -> dict[str, Any]:
    """Preview extension: the reminder lives in UserDefaults on device."""
    profile = store.read_profile(owner_id) or store.write_profile(owner_id, "hypertrophy", 4, "Full gym")
    return store.write_profile(
        owner_id,
        profile["goal"],
        profile["days_per_week"],
        profile["equipment"],
        payload.reminder_hour,
        payload.reminder_minute,
    )


@app.post("/api/v1/workout-completions", status_code=status.HTTP_201_CREATED)
async def complete_workout(
    payload: WorkoutCompletionPayload, owner_id: str = Depends(current_owner)
) -> dict[str, Any]:
    body = json.loads(payload.model_dump_json())
    try:
        return store.complete_workout(owner_id, body)
    except store.PlanNotFound:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Active workout plan was not found")
    except store.TooManySets:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="completed_sets exceeds the prescribed workout",
        )


@app.get("/api/v1/workout-history")
async def get_workout_history(limit: int = 20, owner_id: str = Depends(current_owner)) -> dict[str, Any]:
    return {"items": store.workout_history(owner_id, limit)}


@app.get("/api/v1/progress-summary")
async def get_progress_summary(owner_id: str = Depends(current_owner)) -> dict[str, Any]:
    return store.progress_summary(owner_id)


@app.post("/api/v1/storage/exports")
async def export_summary(request: Request, owner_id: str = Depends(current_owner)) -> dict[str, Any]:
    """Mirror of the Swift ``TenxStorage.upload`` + ``listObjects`` round-trip."""
    try:
        payload = await request.json()
    except Exception:
        payload = {}
    summary = {
        "profile": payload.get("profile"),
        "workouts": payload.get("workouts"),
        "progress_summary": store.progress_summary(owner_id),
        "exported_at": store.iso(store.now()),
    }
    return store.export_training_summary(owner_id, summary)


@app.exception_handler(HTTPException)
async def http_exception_handler(_request: Request, exc: HTTPException) -> JSONResponse:
    """Always answer JSON so the preview UI can surface ``backendError`` like the app does."""
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="web")


def main() -> None:
    import uvicorn

    uvicorn.run(app, host=HOST, port=PORT, log_level="info", access_log=False)


if __name__ == "__main__":
    main()
