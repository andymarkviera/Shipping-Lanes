-- Additive Step 78. Independent of game-server leases, processes and scenery.
CREATE TABLE IF NOT EXISTS public_authority.refineries (
 refinery_id text PRIMARY KEY, state jsonb NOT NULL
);
