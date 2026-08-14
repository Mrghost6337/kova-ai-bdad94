import sys
import types
from datetime import datetime
from uuid import uuid4

import pytest
from pydantic import ValidationError

mock_auth = types.ModuleType("app.tenx_auth")
mock_auth.current_user = lambda: {"sub": "test-user"}
sys.modules.setdefault("app.tenx_auth", mock_auth)

from app.routes.training import NEXT_FOCUS, WORKOUTS, router, user_id
from app.schemas import ExercisePayload, ProfileUpdatePayload, WorkoutCompletionPayload


def test_training_rotation_is_complete() -> None:
    assert NEXT_FOCUS == {"push": "pull", "pull": "legs", "legs": "upper", "upper": "push"}
    assert set(WORKOUTS) == set(NEXT_FOCUS)


def test_every_prescription_has_valid_exercises() -> None:
    for exercises in WORKOUTS.values():
        assert len(exercises) == 4
        for exercise in exercises:
            assert ExercisePayload.model_validate(exercise).sets > 0


def test_completion_rejects_implausible_set_count() -> None:
    with pytest.raises(ValidationError):
        WorkoutCompletionPayload(
            plan_id=uuid4(),
            duration_minutes=15,
            volume_kg=4_000,
            rpe=8,
            soreness=2,
            completed_sets=61,
            completed_at=datetime.now(),
        )


def test_profile_validation_rejects_invalid_cadence() -> None:
    with pytest.raises(ValidationError):
        ProfileUpdatePayload(goal="strength", days_per_week=1, equipment="Barbell")


def test_routes_match_the_declared_api_contract() -> None:
    route_methods = {(route.path, method) for route in router.routes for method in route.methods}
    assert ("/api/v1/active-plan", "GET") in route_methods
    assert ("/api/v1/profile", "PUT") in route_methods
    assert ("/api/v1/workout-completions", "POST") in route_methods
    assert ("/api/v1/workout-history", "GET") in route_methods
    assert ("/api/v1/progress-summary", "GET") in route_methods


def test_missing_subject_is_rejected() -> None:
    with pytest.raises(Exception) as error:
        user_id({})
    assert getattr(error.value, "status_code", None) == 401
