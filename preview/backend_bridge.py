"""Bridge into the real FastAPI backend source in ``backend/app``.

The production backend talks to Neon Postgres through psycopg and authenticates
through 10x managed better-auth (``app.tenx_auth`` is generated at deploy time
and is not part of this repository). Neither is available inside the preview
sandbox, so we stub those two modules the same way ``backend/tests`` does and
then import the *real* route module.

That gives the preview the genuine training data and rotation rules
(``WORKOUTS``, ``NEXT_FOCUS``), the genuine Pydantic contracts
(``ProfileUpdatePayload``, ``WorkoutCompletionPayload``) and the genuine
``user_id(claims)`` helper, while persistence is mirrored onto SQLite by
``preview/store.py`` using the schema from ``services/db/migrations``.
"""

from __future__ import annotations

import sys
import types
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_ROOT = REPO_ROOT / "backend"


class PreviewDatabaseUnavailable(RuntimeError):
    """Raised if code tries to reach the production Postgres pool."""


def _database_connection(*_args: Any, **_kwargs: Any) -> Any:
    raise PreviewDatabaseUnavailable(
        "Postgres is not available in the preview sandbox; "
        "preview.store mirrors the SQL onto SQLite instead."
    )


def install_stubs() -> None:
    if str(BACKEND_ROOT) not in sys.path:
        sys.path.insert(0, str(BACKEND_ROOT))

    if "app.database" not in sys.modules:
        database_stub = types.ModuleType("app.database")
        database_stub.database_connection = _database_connection  # type: ignore[attr-defined]
        database_stub.connection_pool = _database_connection  # type: ignore[attr-defined]
        sys.modules["app.database"] = database_stub

    if "app.tenx_auth" not in sys.modules:
        auth_stub = types.ModuleType("app.tenx_auth")

        def current_user() -> dict[str, Any]:  # pragma: no cover - replaced at request time
            raise PreviewDatabaseUnavailable("Preview auth resolves tokens in preview.server")

        auth_stub.current_user = current_user  # type: ignore[attr-defined]
        sys.modules["app.tenx_auth"] = auth_stub


install_stubs()

from app.routes.training import NEXT_FOCUS, WORKOUTS, user_id  # noqa: E402
from app.schemas import ProfileUpdatePayload, WorkoutCompletionPayload  # noqa: E402

__all__ = [
    "NEXT_FOCUS",
    "WORKOUTS",
    "ProfileUpdatePayload",
    "WorkoutCompletionPayload",
    "PreviewDatabaseUnavailable",
    "user_id",
]
