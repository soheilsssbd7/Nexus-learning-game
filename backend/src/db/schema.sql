CREATE TABLE players (
    player_id UUID PRIMARY KEY,
    display_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    schema_version INT NOT NULL DEFAULT 1
);

CREATE TABLE skill_ratings (
    id SERIAL PRIMARY KEY,
    player_id UUID REFERENCES players(player_id),
    skill_key TEXT NOT NULL,
    elo REAL NOT NULL,
    confidence REAL NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    last_seen TIMESTAMPTZ NOT NULL,
    UNIQUE (player_id, skill_key)
);

CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    player_id UUID REFERENCES players(player_id),
    event_type TEXT NOT NULL,
    level_id TEXT,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_player_id ON events(player_id);
CREATE INDEX idx_events_type ON events(event_type);
