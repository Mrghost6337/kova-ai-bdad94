"""SQLite mirror of ``services/db/migrations/001_kova_training.sql`` for the preview.

The real database is Neon Postgres with RLS keyed on the JWT ``sub`` claim. Here
every query is scoped by ``owner_id`` explicitly, which is exactly what the RLS
policies enforce in production, so the preview behaves like one authenticated
user at a time.
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from uuid import uuid4

DATA_DIR = Path(__file__).resolve().parent / ".data"
DB_PATH = DATA_DIR / "kova-preview.sqlite3"
EXPORT_DIR = DATA_DIR / "workout-exports"

# Mirrors WorkoutStore.seededHistory in ios/KOVAAi/Services/WorkoutStore.swift
SEEDED_SESSIONS: list[tuple[int, str, str, int, int, int, int]] = [
    (0, "pull", "Pull performance", 62, 15_480, 8, 3),
    (1, "legs", "Legs performance", 68, 18_920, 8, 4),
    (2, "push", "Push performance", 59, 14_760, 7, 2),
    (4, "upper", "Upper performance", 54, 12_980, 7, 3),
    (5, "legs", "Legs performance", 65, 18_210, 8, 4),
    (6, "pull", "Pull performance", 57, 13_860, 7, 2),
]

SCHEMA = """
CREATE TABLE IF NOT EXISTS preview_users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS preview_sessions (
    token TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES preview_users(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS coaching_profiles (
    owner_id TEXT PRIMARY KEY,
    goal TEXT NOT NULL CHECK (goal IN ('hypertrophy', 'strength')),
    days_per_week INTEGER NOT NULL CHECK (days_per_week BETWEEN 2 AND 7),
    equipment TEXT NOT NULL,
    reminder_hour INTEGER NOT NULL DEFAULT 18,
    reminder_minute INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS training_plans (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL,
    title TEXT NOT NULL,
    focus TEXT NOT NULL CHECK (focus IN ('push', 'pull', 'legs', 'upper')),
    estimated_minutes INTEGER NOT NULL CHECK (estimated_minutes BETWEEN 15 AND 180),
    intensity_note TEXT NOT NULL,
    exercises TEXT NOT NULL,
    rationale TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('active', 'completed', 'skipped')) DEFAULT 'active',
    created_at TEXT NOT NULL,
    completed_at TEXT
);
CREATE TABLE IF NOT EXISTS workout_logs (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL,
    plan_id TEXT NOT NULL REFERENCES training_plans(id) ON DELETE RESTRICT,
    plan_title TEXT NOT NULL,
    focus TEXT NOT NULL CHECK (focus IN ('push', 'pull', 'legs', 'upper')),
    completed_at TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes BETWEEN 1 AND 360),
    volume_kg INTEGER NOT NULL CHECK (volume_kg >= 0),
    rpe INTEGER NOT NULL CHECK (rpe BETWEEN 1 AND 10),
    soreness INTEGER NOT NULL CHECK (soreness BETWEEN 1 AND 5),
    completed_sets INTEGER NOT NULL CHECK (completed_sets > 0),
    prescribed_sets INTEGER NOT NULL CHECK (prescribed_sets > 0),
    CHECK (completed_sets <= prescribed_sets)
);
"""


def now() -> datetime:
    return datetime.now(UTC)


def iso(moment: datetime) -> str:
    return moment.astimezone(UTC).isoformat().replace("+00:00", "Z")


def connect() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DB_PATH, timeout=10)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


def hash_password(password: str, salt: str | None = None) -> str:
    salt = salt or secrets.token_hex(8)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 120_000).hex()
    return f"pbkdf2${salt}${digest}"


def verify_password(password: str, stored: str) -> bool:
    try:
        _, salt, _ = stored.split("$")
    except ValueError:
        return False
    return secrets.compare_digest(hash_password(password, salt), stored)


def init_schema() -> None:
    with connect() as connection:
        connection.executescript(SCHEMA)


# --------------------------------------------------------------------------- accounts


def create_account(email: str, password: str) -> tuple[str, str]:
    owner_id = str(uuid4())
    token = secrets.token_urlsafe(24)
    with connect() as connection:
        connection.execute(
            "INSERT INTO preview_users (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)",
            (owner_id, email.lower(), hash_password(password), iso(now())),
        )
        connection.execute(
            "INSERT INTO preview_sessions (token, owner_id, created_at) VALUES (?, ?, ?)",
            (token, owner_id, iso(now())),
        )
        connection.commit()
    seed_demo_state(owner_id)
    return owner_id, token


def sign_in(email: str, password: str) -> tuple[str, str] | None:
    with connect() as connection:
        row = connection.execute(
            "SELECT id, password_hash FROM preview_users WHERE email = ?", (email.lower(),)
        ).fetchone()
        if row is None or not verify_password(password, row["password_hash"]):
            return None
        token = secrets.token_urlsafe(24)
        connection.execute(
            "INSERT INTO preview_sessions (token, owner_id, created_at) VALUES (?, ?, ?)",
            (token, row["id"], iso(now())),
        )
        connection.commit()
    return row["id"], token


def resolve_token(token: str | None) -> tuple[str | None, str | None]:
    """Returns ``(owner_id, email)`` for a preview session token."""
    if not token:
        return None, None
    with connect() as connection:
        row = connection.execute(
            "SELECT u.id, u.email FROM preview_sessions s JOIN preview_users u ON u.id = s.owner_id WHERE s.token = ?",
            (token,),
        ).fetchone()
    return (row["id"], row["email"]) if row else (None, None)


def revoke_token(token: str | None) -> None:
    if not token:
        return
    with connect() as connection:
        connection.execute("DELETE FROM preview_sessions WHERE token = ?", (token,))
        connection.commit()


def delete_account(owner_id: str, password: str) -> bool:
    with connect() as connection:
        row = connection.execute(
            "SELECT password_hash FROM preview_users WHERE id = ?", (owner_id,)
        ).fetchone()
        if row is None or not verify_password(password, row["password_hash"]):
            return False
        connection.execute("DELETE FROM workout_logs WHERE owner_id = ?", (owner_id,))
        connection.execute("DELETE FROM training_plans WHERE owner_id = ?", (owner_id,))
        connection.execute("DELETE FROM coaching_profiles WHERE owner_id = ?", (owner_id,))
        connection.execute("DELETE FROM preview_sessions WHERE owner_id = ?", (owner_id,))
        connection.execute("DELETE FROM preview_users WHERE id = ?", (owner_id,))
        connection.commit()
    return True


def reset_demo_state(owner_id: str) -> None:
    with connect() as connection:
        connection.execute("DELETE FROM workout_logs WHERE owner_id = ?", (owner_id,))
        connection.execute("DELETE FROM training_plans WHERE owner_id = ?", (owner_id,))
        connection.execute("DELETE FROM coaching_profiles WHERE owner_id = ?", (owner_id,))
        connection.commit()
    seed_demo_state(owner_id)


# --------------------------------------------------------------------------- training data


def seed_demo_state(owner_id: str) -> None:
    """Seed the same demo history the Swift store ships with on first launch."""
    from backend_bridge import WORKOUTS  # local import avoids a cycle at module load

    with connect() as connection:
        existing = connection.execute(
            "SELECT count(*) AS n FROM training_plans WHERE owner_id = ?", (owner_id,)
        ).fetchone()["n"]
        if existing:
            return
        for offset, focus, title, minutes, volume, rpe, soreness in SEEDED_SESSIONS:
            completed_at = now() - timedelta(days=offset)
            plan_id = str(uuid4())
            connection.execute(
                """INSERT INTO training_plans
                   (id, owner_id, title, focus, estimated_minutes, intensity_note, exercises, rationale, state, created_at, completed_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'completed', ?, ?)""",
                (
                    plan_id,
                    owner_id,
                    title,
                    focus,
                    minutes,
                    "Progression ready",
                    json.dumps(WORKOUTS[focus]),
                    "Completed session.",
                    iso(completed_at - timedelta(minutes=minutes)),
                    iso(completed_at),
                ),
            )
            connection.execute(
                """INSERT INTO workout_logs
                   (id, owner_id, plan_id, plan_title, focus, completed_at, duration_minutes, volume_kg, rpe, soreness, completed_sets, prescribed_sets)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    str(uuid4()),
                    owner_id,
                    plan_id,
                    title,
                    focus,
                    iso(completed_at),
                    minutes,
                    volume,
                    rpe,
                    soreness,
                    sum(item["sets"] for item in WORKOUTS[focus]),
                    sum(item["sets"] for item in WORKOUTS[focus]),
                ),
            )
        connection.commit()


def insert_plan(
    owner_id: str,
    focus: str,
    rationale: str,
    estimated_minutes: int = 58,
    intensity_note: str = "Progression ready",
    state: str = "active",
) -> dict[str, Any]:
    from backend_bridge import WORKOUTS

    plan_id = str(uuid4())
    created_at = iso(now())
    with connect() as connection:
        connection.execute(
            """INSERT INTO training_plans
               (id, owner_id, title, focus, estimated_minutes, intensity_note, exercises, rationale, state, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                plan_id,
                owner_id,
                f"{focus.title()} performance",
                focus,
                estimated_minutes,
                intensity_note,
                json.dumps(WORKOUTS[focus]),
                rationale,
                state,
                created_at,
            ),
        )
        connection.commit()
        row = connection.execute("SELECT * FROM training_plans WHERE id = ?", (plan_id,)).fetchone()
    return plan_row_to_dict(row)


def active_plan_for(owner_id: str) -> dict[str, Any]:
    with connect() as connection:
        row = connection.execute(
            """SELECT * FROM training_plans WHERE owner_id = ? AND state = 'active'
               ORDER BY created_at DESC LIMIT 1""",
            (owner_id,),
        ).fetchone()
    if row is not None:
        return plan_row_to_dict(row)
    return insert_plan(owner_id, "push", "Your first progression session is ready.")


def plan_row_to_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "title": row["title"],
        "focus": row["focus"],
        "estimated_minutes": row["estimated_minutes"],
        "intensity_note": row["intensity_note"],
        "exercises": json.loads(row["exercises"]),
        "rationale": row["rationale"],
        "state": row["state"],
        "created_at": row["created_at"],
        "completed_at": row["completed_at"],
    }


def log_row_to_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "plan_id": row["plan_id"],
        "plan_title": row["plan_title"],
        "focus": row["focus"],
        "completed_at": row["completed_at"],
        "duration_minutes": row["duration_minutes"],
        "volume_kg": row["volume_kg"],
        "rpe": row["rpe"],
        "soreness": row["soreness"],
        "completed_sets": row["completed_sets"],
        "prescribed_sets": row["prescribed_sets"],
    }


class PlanNotFound(Exception):
    pass


class TooManySets(Exception):
    pass


def complete_workout(owner_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Mirror of ``POST /api/v1/workout-completions`` in backend/app/routes/training.py."""
    from backend_bridge import NEXT_FOCUS

    completed_at = payload.get("completed_at") or iso(now())
    with connect() as connection:
        plan = connection.execute(
            "SELECT * FROM training_plans WHERE id = ? AND owner_id = ? AND state = 'active'",
            (str(payload["plan_id"]), owner_id),
        ).fetchone()
        if plan is None:
            raise PlanNotFound("Active workout plan was not found")
        exercises = json.loads(plan["exercises"])
        total_sets = sum(item["sets"] for item in exercises)
        if payload["completed_sets"] > total_sets:
            raise TooManySets("completed_sets exceeds the prescribed workout")

        log_id = str(uuid4())
        connection.execute(
            """INSERT INTO workout_logs
               (id, owner_id, plan_id, plan_title, focus, completed_at, duration_minutes, volume_kg, rpe, soreness, completed_sets, prescribed_sets)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                log_id,
                owner_id,
                plan["id"],
                plan["title"],
                plan["focus"],
                completed_at,
                payload["duration_minutes"],
                payload["volume_kg"],
                payload["rpe"],
                payload["soreness"],
                payload["completed_sets"],
                total_sets,
            ),
        )
        connection.execute(
            "UPDATE training_plans SET state = 'completed', completed_at = ? WHERE id = ?",
            (completed_at, plan["id"]),
        )
        log_row = connection.execute("SELECT * FROM workout_logs WHERE id = ?", (log_id,)).fetchone()
        connection.commit()

    next_focus = NEXT_FOCUS[plan["focus"]]
    recovery = payload["rpe"] >= 9 or payload["soreness"] >= 4
    rationale = (
        "Recovery-adjusted volume after your latest effort."
        if recovery
        else "Progression is ready after a well-managed session."
    )
    next_plan = insert_plan(
        owner_id,
        next_focus,
        rationale,
        estimated_minutes=42 if recovery else 58,
        intensity_note="Recovery-adjusted" if recovery else "Progression ready",
    )
    return {"completion": log_row_to_dict(log_row), "next_plan": next_plan}


def adjust_active_plan(
    owner_id: str,
    focus: str,
    estimated_minutes: int,
    intensity_note: str,
    rationale: str,
) -> dict[str, Any]:
    """Preview-extensie: maakt een lokale 'swap focus'/'regenerate volume' duurzaam.

    In de Swift-app bouwen ``swapRecommendation`` en ``regenerateRecommendation``
    een nieuw plan met een vers UUID zonder de backend te vertellen; een latere
    workout-completion wijst dan naar een plan dat de server niet kent. De preview
    vervangt het actieve plan hier expliciet (oud plan → 'skipped', zoals de
    partial unique index ``training_plans_one_active_per_owner`` toestaat).
    """
    with connect() as connection:
        connection.execute(
            "UPDATE training_plans SET state = 'skipped' WHERE owner_id = ? AND state = 'active'",
            (owner_id,),
        )
        connection.commit()
    return insert_plan(
        owner_id,
        focus,
        rationale,
        estimated_minutes=estimated_minutes,
        intensity_note=intensity_note,
    )


def workout_history(owner_id: str, limit: int = 20) -> list[dict[str, Any]]:
    safe_limit = min(max(limit, 1), 100)
    with connect() as connection:
        rows = connection.execute(
            "SELECT * FROM workout_logs WHERE owner_id = ? ORDER BY completed_at DESC LIMIT ?",
            (owner_id, safe_limit),
        ).fetchall()
    return [log_row_to_dict(row) for row in rows]


def progress_summary(owner_id: str) -> dict[str, Any]:
    """Mirror of ``GET /api/v1/progress-summary`` (recursive streak CTE → Python)."""
    with connect() as connection:
        logs = connection.execute(
            "SELECT completed_at, volume_kg FROM workout_logs WHERE owner_id = ?", (owner_id,)
        ).fetchall()
    weekly_sessions = 0
    weekly_volume = 0
    latest: datetime | None = None
    cutoff = now() - timedelta(days=7)
    days: set[str] = set()
    for log in logs:
        moment = datetime.fromisoformat(log["completed_at"].replace("Z", "+00:00"))
        days.add(moment.astimezone(UTC).date().isoformat())
        if moment >= cutoff:
            weekly_sessions += 1
            weekly_volume += log["volume_kg"]
        if latest is None or moment > latest:
            latest = moment

    streak = 0
    day = now().date()
    while day.isoformat() in days:
        streak += 1
        day -= timedelta(days=1)

    return {
        "weekly_sessions": weekly_sessions,
        "weekly_volume_kg": weekly_volume,
        "latest_completion": iso(latest) if latest else None,
        "current_streak": streak,
    }


def read_profile(owner_id: str) -> dict[str, Any] | None:
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM coaching_profiles WHERE owner_id = ?", (owner_id,)
        ).fetchone()
    if row is None:
        return None
    return {
        "goal": row["goal"],
        "days_per_week": row["days_per_week"],
        "equipment": row["equipment"],
        "reminder_hour": row["reminder_hour"],
        "reminder_minute": row["reminder_minute"],
        "updated_at": row["updated_at"],
    }


def write_profile(
    owner_id: str,
    goal: str,
    days_per_week: int,
    equipment: str,
    reminder_hour: int | None = None,
    reminder_minute: int | None = None,
) -> dict[str, Any]:
    with connect() as connection:
        current = read_profile(owner_id)
        hour = reminder_hour if reminder_hour is not None else (current or {}).get("reminder_hour", 18)
        minute = (
            reminder_minute
            if reminder_minute is not None
            else (current or {}).get("reminder_minute", 0)
        )
        connection.execute(
            """INSERT INTO coaching_profiles (owner_id, goal, days_per_week, equipment, reminder_hour, reminder_minute, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(owner_id) DO UPDATE SET
                 goal = excluded.goal,
                 days_per_week = excluded.days_per_week,
                 equipment = excluded.equipment,
                 reminder_hour = excluded.reminder_hour,
                 reminder_minute = excluded.reminder_minute,
                 updated_at = excluded.updated_at""",
            (owner_id, goal, days_per_week, equipment, hour, minute, iso(now())),
        )
        connection.commit()
    profile = read_profile(owner_id)
    assert profile is not None
    return profile


# --------------------------------------------------------------------------- storage mirror


def export_training_summary(owner_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Mirror of the R2 ``workout-exports`` bucket upload + list round-trip."""
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"kova-training-summary-{now():%Y-%m-%d-%H-%M-%S}.json"
    scoped_dir = EXPORT_DIR / owner_id
    scoped_dir.mkdir(parents=True, exist_ok=True)
    (scoped_dir / filename).write_text(json.dumps(payload, indent=2), encoding="utf-8")
    listed = sorted(path.name for path in scoped_dir.glob("*.json"))
    return {"id": filename, "filename": filename, "bucket": "workout-exports", "objects": listed}


def account_email(owner_id: str) -> str | None:
    with connect() as connection:
        row = connection.execute("SELECT email FROM preview_users WHERE id = ?", (owner_id,)).fetchone()
    return row["email"] if row else None


def preview_facts() -> dict[str, Any]:
    with connect() as connection:
        counts = {
            "users": connection.execute("SELECT count(*) FROM preview_users").fetchone()[0],
            "plans": connection.execute("SELECT count(*) FROM training_plans").fetchone()[0],
            "logs": connection.execute("SELECT count(*) FROM workout_logs").fetchone()[0],
        }
    return {
        "database": str(DB_PATH.relative_to(DB_PATH.parents[1])) if DB_PATH.exists() else "not created",
        "size_bytes": os.path.getsize(DB_PATH) if DB_PATH.exists() else 0,
        **counts,
    }
