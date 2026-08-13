CREATE TABLE coaching_profiles (
    owner_id TEXT PRIMARY KEY DEFAULT (coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')),
    goal TEXT NOT NULL CHECK (goal IN ('hypertrophy', 'strength')),
    days_per_week SMALLINT NOT NULL CHECK (days_per_week BETWEEN 2 AND 7),
    equipment TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE training_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id TEXT NOT NULL DEFAULT (coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')),
    title TEXT NOT NULL,
    focus TEXT NOT NULL CHECK (focus IN ('push', 'pull', 'legs', 'upper')),
    estimated_minutes SMALLINT NOT NULL CHECK (estimated_minutes BETWEEN 15 AND 180),
    intensity_note TEXT NOT NULL,
    exercises JSONB NOT NULL,
    rationale TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('active', 'completed', 'skipped')) DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX training_plans_one_active_per_owner ON training_plans (owner_id) WHERE state = 'active';

CREATE TABLE workout_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id TEXT NOT NULL DEFAULT (coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')),
    plan_id UUID NOT NULL REFERENCES training_plans(id) ON DELETE RESTRICT,
    plan_title TEXT NOT NULL,
    focus TEXT NOT NULL CHECK (focus IN ('push', 'pull', 'legs', 'upper')),
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    duration_minutes SMALLINT NOT NULL CHECK (duration_minutes BETWEEN 1 AND 360),
    volume_kg INTEGER NOT NULL CHECK (volume_kg >= 0),
    rpe SMALLINT NOT NULL CHECK (rpe BETWEEN 1 AND 10),
    soreness SMALLINT NOT NULL CHECK (soreness BETWEEN 1 AND 5),
    completed_sets SMALLINT NOT NULL CHECK (completed_sets > 0),
    prescribed_sets SMALLINT NOT NULL CHECK (prescribed_sets > 0),
    CHECK (completed_sets <= prescribed_sets)
);

CREATE INDEX workout_logs_owner_completed_at_idx ON workout_logs (owner_id, completed_at DESC);

ALTER TABLE coaching_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY coaching_profiles_owner_only ON coaching_profiles FOR ALL USING (owner_id = coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')) WITH CHECK (owner_id = coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'));
CREATE POLICY training_plans_owner_only ON training_plans FOR ALL USING (owner_id = coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')) WITH CHECK (owner_id = coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'));
CREATE POLICY workout_logs_owner_only ON workout_logs FOR ALL USING (owner_id = coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')) WITH CHECK (owner_id = coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'));
