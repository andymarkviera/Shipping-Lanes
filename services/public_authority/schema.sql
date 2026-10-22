-- Versioned isolated public authority adapter. No private-world imports.
CREATE SCHEMA public_authority;
CREATE TABLE public_authority.version (version integer PRIMARY KEY CHECK(version=1));
INSERT INTO public_authority.version VALUES(1);
CREATE TABLE public_authority.servers (
 id text PRIMARY KEY, credential_hash text NOT NULL, fingerprint text NOT NULL,
 approved boolean NOT NULL, expires timestamptz NOT NULL
);
CREATE TABLE public_authority.profiles (
 account text PRIMARY KEY, issuer text NOT NULL, subject text NOT NULL,
 money bigint NOT NULL CHECK(money BETWEEN 0 AND 9000000000000),
 revision bigint NOT NULL CHECK(revision>=0), profile jsonb NOT NULL,
 UNIQUE(issuer,subject)
);
CREATE TABLE public_authority.leases (
 account text PRIMARY KEY REFERENCES public_authority.profiles(account),
 owner text REFERENCES public_authority.servers(id), epoch bigint NOT NULL DEFAULT 0,
 generation bigint NOT NULL DEFAULT 0, phase text NOT NULL CHECK(phase IN ('VACANT','ACTIVE','QUIESCING','SEALED')),
 expires timestamptz NOT NULL DEFAULT '1970-01-01T00:00:00Z', transfer_id text
);
CREATE TABLE public_authority.tickets (
 digest text PRIMARY KEY, account text NOT NULL REFERENCES public_authority.profiles(account),
 server text NOT NULL REFERENCES public_authority.servers(id), fingerprint text NOT NULL,
 nonce text NOT NULL, protocol integer NOT NULL CHECK(protocol=7), expires timestamptz NOT NULL,
 used boolean NOT NULL DEFAULT false
);
CREATE TABLE public_authority.transfers (
 id text PRIMARY KEY, account text NOT NULL REFERENCES public_authority.profiles(account),
 source text NOT NULL REFERENCES public_authority.servers(id), source_epoch bigint NOT NULL,
 destination text NOT NULL REFERENCES public_authority.servers(id),
 phase text NOT NULL CHECK(phase IN ('PREPARED','SEALED','CLAIMED','CANCELLED','ABANDONED')),
 expires timestamptz NOT NULL, snapshot jsonb, claim_ticket text, outcome jsonb
);
CREATE TABLE public_authority.receipts (
 account text NOT NULL REFERENCES public_authority.profiles(account), action_id text NOT NULL,
 fingerprint text NOT NULL, result jsonb NOT NULL, PRIMARY KEY(account,action_id)
);
CREATE TABLE public_authority.game (
 id integer PRIMARY KEY CHECK(id=1), money bigint NOT NULL CHECK(money>=0), stock integer NOT NULL CHECK(stock>=0)
);
INSERT INTO public_authority.game VALUES(1,1000000,100);
CREATE TABLE public_authority.journal (
 account text NOT NULL, action_id text NOT NULL, amount bigint NOT NULL,
 PRIMARY KEY(account,action_id), FOREIGN KEY(account,action_id) REFERENCES public_authority.receipts(account,action_id)
);
