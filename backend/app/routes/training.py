from datetime import UTC, datetime
from typing import Any
from uuid import UUID
import json

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.concurrency import run_in_threadpool

from app.database import database_connection
from app.schemas import ProfileUpdatePayload, WorkoutCompletionPayload
from app.tenx_auth import current_user

router = APIRouter(prefix="/api/v1", tags=["training"])

WORKOUTS: dict[str, list[dict[str, Any]]] = {
    "push": [{"name": "Barbell bench press", "sets": 4, "reps": "6–8", "load": "80 kg", "rest_seconds": 120}, {"name": "Incline dumbbell press", "sets": 3, "reps": "8–10", "load": "30 kg", "rest_seconds": 90}, {"name": "Cable lateral raise", "sets": 3, "reps": "12–15", "load": "12.5 kg", "rest_seconds": 60}, {"name": "Rope pressdown", "sets": 3, "reps": "10–12", "load": "32.5 kg", "rest_seconds": 60}],
    "pull": [{"name": "Weighted pull-up", "sets": 4, "reps": "6–8", "load": "+15 kg", "rest_seconds": 120}, {"name": "Chest-supported row", "sets": 3, "reps": "8–10", "load": "60 kg", "rest_seconds": 90}, {"name": "Lat pulldown", "sets": 3, "reps": "10–12", "load": "64 kg", "rest_seconds": 75}, {"name": "Incline curl", "sets": 3, "reps": "10–12", "load": "16 kg", "rest_seconds": 60}],
    "legs": [{"name": "High-bar squat", "sets": 4, "reps": "5–7", "load": "105 kg", "rest_seconds": 150}, {"name": "Romanian deadlift", "sets": 3, "reps": "8–10", "load": "90 kg", "rest_seconds": 120}, {"name": "Leg press", "sets": 3, "reps": "10–12", "load": "180 kg", "rest_seconds": 90}, {"name": "Seated leg curl", "sets": 3, "reps": "10–12", "load": "55 kg", "rest_seconds": 75}],
    "upper": [{"name": "Dumbbell bench press", "sets": 3, "reps": "8–10", "load": "34 kg", "rest_seconds": 90}, {"name": "Neutral-grip pulldown", "sets": 3, "reps": "8–10", "load": "68 kg", "rest_seconds": 90}, {"name": "Machine shoulder press", "sets": 3, "reps": "10–12", "load": "50 kg", "rest_seconds": 75}, {"name": "Cable curl", "sets": 2, "reps": "12–15", "load": "25 kg", "rest_seconds": 60}],
}
NEXT_FOCUS = {"push": "pull", "pull": "legs", "legs": "upper", "upper": "push"}


def user_id(claims: dict[str, Any]) -> str:
    subject = claims.get("sub")
    if not isinstance(subject, str) or not subject:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authenticated user id is missing")
    return subject


def create_plan(owner_id: str, focus: str, rationale: str) -> dict[str, Any]:
    with database_connection() as connection, connection.cursor() as cursor:
        cursor.execute("INSERT INTO training_plans (owner_id, title, focus, estimated_minutes, intensity_note, exercises, rationale, state) VALUES (%s, %s, %s, %s, %s, %s::jsonb, %s, 'active') RETURNING id, title, focus, estimated_minutes, intensity_note, exercises, rationale, state, created_at", (owner_id, f"{focus.title()} performance", focus, 58, "Progression ready", json.dumps(WORKOUTS[focus]), rationale))
        plan = cursor.fetchone()
        connection.commit()
        return plan


def active_plan_for(owner_id: str) -> dict[str, Any]:
    with database_connection() as connection, connection.cursor() as cursor:
        cursor.execute("SELECT id, title, focus, estimated_minutes, intensity_note, exercises, rationale, state, created_at FROM training_plans WHERE owner_id = %s AND state = 'active' ORDER BY created_at DESC LIMIT 1", (owner_id,))
        plan = cursor.fetchone()
    return plan if plan is not None else create_plan(owner_id, "push", "Your first progression session is ready.")


@router.get("/active-plan")
async def get_active_plan(claims: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return await run_in_threadpool(active_plan_for, user_id(claims))


@router.put("/profile")
async def update_profile(payload: ProfileUpdatePayload, claims: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    owner_id = user_id(claims)

    def write_profile() -> dict[str, Any]:
        with database_connection() as connection, connection.cursor() as cursor:
            cursor.execute("INSERT INTO coaching_profiles (owner_id, goal, days_per_week, equipment) VALUES (%s, %s, %s, %s) ON CONFLICT (owner_id) DO UPDATE SET goal = EXCLUDED.goal, days_per_week = EXCLUDED.days_per_week, equipment = EXCLUDED.equipment, updated_at = now() RETURNING goal, days_per_week, equipment, updated_at", (owner_id, payload.goal, payload.days_per_week, payload.equipment))
            row = cursor.fetchone()
            connection.commit()
            return row

    return await run_in_threadpool(write_profile)


@router.post("/workout-completions", status_code=status.HTTP_201_CREATED)
async def complete_workout(payload: WorkoutCompletionPayload, claims: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    owner_id = user_id(claims)

    def save_completion() -> dict[str, Any]:
        completed_at = payload.completed_at or datetime.now(UTC)
        with database_connection() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT id, title, focus, exercises FROM training_plans WHERE id = %s AND owner_id = %s AND state = 'active' FOR UPDATE", (str(payload.plan_id), owner_id))
            plan = cursor.fetchone()
            if plan is None:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Active workout plan was not found")
            total_sets = sum(item["sets"] for item in plan["exercises"])
            if payload.completed_sets > total_sets:
                raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="completed_sets exceeds the prescribed workout")
            cursor.execute("INSERT INTO workout_logs (owner_id, plan_id, plan_title, focus, completed_at, duration_minutes, volume_kg, rpe, soreness, completed_sets, prescribed_sets) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id, completed_at, duration_minutes, volume_kg, rpe, soreness, completed_sets, prescribed_sets", (owner_id, str(payload.plan_id), plan["title"], plan["focus"], completed_at, payload.duration_minutes, payload.volume_kg, payload.rpe, payload.soreness, payload.completed_sets, total_sets))
            log = cursor.fetchone()
            cursor.execute("UPDATE training_plans SET state = 'completed', completed_at = %s WHERE id = %s", (completed_at, str(payload.plan_id)))
            next_focus = NEXT_FOCUS[plan["focus"]]
            recovery = payload.rpe >= 9 or payload.soreness >= 4
            rationale = "Recovery-adjusted volume after your latest effort." if recovery else "Progression is ready after a well-managed session."
            cursor.execute("INSERT INTO training_plans (owner_id, title, focus, estimated_minutes, intensity_note, exercises, rationale, state) VALUES (%s, %s, %s, %s, %s, %s::jsonb, %s, 'active') RETURNING id, title, focus, estimated_minutes, intensity_note, exercises, rationale, state, created_at", (owner_id, f"{next_focus.title()} performance", next_focus, 42 if recovery else 58, "Recovery-adjusted" if recovery else "Progression ready", json.dumps(WORKOUTS[next_focus]), rationale))
            next_plan = cursor.fetchone()
            connection.commit()
            return {"completion": log, "next_plan": next_plan}

    return await run_in_threadpool(save_completion)


@router.get("/workout-history")
async def workout_history(claims: dict[str, Any] = Depends(current_user), limit: int = 20) -> dict[str, Any]:
    safe_limit = min(max(limit, 1), 100)

    def fetch_history() -> dict[str, Any]:
        with database_connection() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT id, plan_id, plan_title, focus, completed_at, duration_minutes, volume_kg, rpe, soreness, completed_sets, prescribed_sets FROM workout_logs WHERE owner_id = %s ORDER BY completed_at DESC LIMIT %s", (user_id(claims), safe_limit))
            return {"items": cursor.fetchall()}

    return await run_in_threadpool(fetch_history)


@router.get("/progress-summary")
async def progress_summary(claims: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    def fetch_summary() -> dict[str, Any]:
        with database_connection() as connection, connection.cursor() as cursor:
            cursor.execute("SELECT count(*) FILTER (WHERE completed_at >= now() - interval '7 days')::int AS weekly_sessions, coalesce(sum(volume_kg) FILTER (WHERE completed_at >= now() - interval '7 days'), 0)::int AS weekly_volume_kg, coalesce(max(completed_at), NULL) AS latest_completion FROM workout_logs WHERE owner_id = %s", (user_id(claims),))
            totals = cursor.fetchone()
            cursor.execute("WITH RECURSIVE completed AS (SELECT DISTINCT completed_at::date AS day FROM workout_logs WHERE owner_id = %s), streak(day) AS (SELECT current_date WHERE EXISTS (SELECT 1 FROM completed WHERE day = current_date) UNION ALL SELECT streak.day - 1 FROM streak WHERE EXISTS (SELECT 1 FROM completed WHERE day = streak.day - 1)) SELECT count(*)::int AS current_streak FROM streak", (user_id(claims),))
            return {**totals, "current_streak": cursor.fetchone()["current_streak"]}

    return await run_in_threadpool(fetch_summary)
