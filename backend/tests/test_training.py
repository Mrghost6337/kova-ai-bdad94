from datetime import datetime
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.routes.training import NEXT_FOCUS, WORKOUTS
from app.schemas import ExercisePayload, WorkoutCompletionPayload


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
        WorkoutCompletionPayload(plan_id=uuid4(), duration_minutes=15, volume_kg=4_000, rpe=8, soreness=2, completed_sets=61, completed_at=datetime.now())
