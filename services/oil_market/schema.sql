-- Additive Step 75 migration. No replacement/reset of profiles or existing saves.
CREATE TABLE IF NOT EXISTS public_authority.oil_market (
 id integer PRIMARY KEY CHECK(id=1), state jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS public_authority.oil_history (
 sequence bigint PRIMARY KEY CHECK(sequence>0), event jsonb NOT NULL
);
