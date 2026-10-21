-- Disposable adapter proof schema, never a migration for real accounts.
CREATE SCHEMA economy;
CREATE TABLE economy.accounts (
    realm text NOT NULL CHECK (realm = 'public_fixture'),
    actor text NOT NULL CHECK (actor IN ('game', 'alice', 'bob')),
    money bigint NOT NULL CHECK (money BETWEEN 0 AND 9000000000000),
    cargo bigint NOT NULL CHECK (cargo BETWEEN 0 AND 9000000000000),
    revision bigint NOT NULL DEFAULT 0 CHECK (revision BETWEEN 0 AND 9000000000000),
    PRIMARY KEY (realm, actor)
);
CREATE TABLE economy.receipts (
    realm text NOT NULL,
    actor text NOT NULL,
    action_id text NOT NULL,
    fingerprint text NOT NULL,
    request jsonb NOT NULL,
    result jsonb NOT NULL,
    PRIMARY KEY (realm, actor, action_id),
    FOREIGN KEY (realm, actor) REFERENCES economy.accounts
);
CREATE TABLE economy.journal (
    realm text NOT NULL,
    actor text NOT NULL,
    action_id text NOT NULL,
    debit text NOT NULL,
    credit text NOT NULL,
    amount bigint NOT NULL CHECK (amount BETWEEN 1 AND 9000000000000),
    quantity bigint NOT NULL CHECK (quantity BETWEEN 0 AND 9000000000000),
    PRIMARY KEY (realm, actor, action_id),
    FOREIGN KEY (realm, actor, action_id) REFERENCES economy.receipts,
    FOREIGN KEY (realm, debit) REFERENCES economy.accounts(realm, actor),
    FOREIGN KEY (realm, credit) REFERENCES economy.accounts(realm, actor),
    CHECK (debit <> credit AND (debit = 'game' OR credit = 'game'))
);
INSERT INTO economy.accounts VALUES
    ('public_fixture','game',1000000,100,0),
    ('public_fixture','alice',20000,0,0),
    ('public_fixture','bob',20000,0,0);
CREATE SCHEMA private_fixture;
CREATE TABLE private_fixture.sentinel (money bigint NOT NULL);
INSERT INTO private_fixture.sentinel VALUES (777);
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA economy TO fixture_service;
GRANT SELECT, UPDATE ON economy.accounts TO fixture_service;
GRANT SELECT, INSERT ON economy.receipts, economy.journal TO fixture_service;
