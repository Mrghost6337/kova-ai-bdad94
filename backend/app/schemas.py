from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

Focus = Literal["push", "pull", "legs", "upper"]
Goal = Literal["hypertrophy", "strength"]


class ExercisePayload(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    sets: int = Field(ge=1, le=12)
    reps: str = Field(min_length=1, max_length=24)
    load: str = Field(min_length=1, max_length=32)
    rest_seconds: int = Field(ge=30, le=600)


class ProfileUpdatePayload(BaseModel):
    goal: Goal
    days_per_week: int = Field(ge=2, le=7)
    equipment: str = Field(min_length=2, max_length=80)


class WorkoutCompletionPayload(BaseModel):
    plan_id: UUID
    duration_minutes: int = Field(ge=1, le=360)
    volume_kg: int = Field(ge=0, le=250_000)
    rpe: int = Field(ge=1, le=10)
    soreness: int = Field(ge=1, le=5)
    completed_sets: int = Field(ge=1, le=100)
    completed_at: datetime | None = None

    @model_validator(mode="after")
    def validate_completion(self) -> "WorkoutCompletionPayload":
        if self.completed_sets > 60 and self.duration_minutes < 20:
            raise ValueError("completed_sets is not plausible for a session under 20 minutes")
        return self
