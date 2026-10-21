"""Admission boundary proof; durable gameplay leases remain a later gate."""
import hashlib, secrets, sqlite3, time, uuid
import psycopg

def digest(value):return hashlib.sha256(value.encode()).hexdigest()
class AdmissionRegistry:
    def __init__(self,database):
        self.database=database
        with psycopg.connect(**database) as db:
            db.execute("CREATE TABLE auth_accounts(id text PRIMARY KEY, issuer text NOT NULL, subject text NOT NULL, UNIQUE(issuer,subject))")
            db.execute("CREATE TABLE auth_servers(id text PRIMARY KEY, credential text NOT NULL, fingerprint text NOT NULL, expires bigint NOT NULL, approved boolean NOT NULL)")
            db.execute("CREATE TABLE auth_tickets(digest text PRIMARY KEY, account text NOT NULL REFERENCES auth_accounts(id), server text NOT NULL REFERENCES auth_servers(id), protocol integer NOT NULL, nonce text NOT NULL, expires bigint NOT NULL, used boolean NOT NULL DEFAULT false, fingerprint text NOT NULL)")
    def account(self,claims):
        with psycopg.connect(**self.database) as db:
            db.execute('INSERT INTO auth_accounts VALUES(%s,%s,%s) ON CONFLICT(issuer,subject) DO NOTHING',(str(uuid.uuid4()),claims['iss'],claims['sub']))
            return db.execute('SELECT id FROM auth_accounts WHERE issuer=%s AND subject=%s',(claims['iss'],claims['sub'])).fetchone()[0]
    def server(self,name,fingerprint):
        credential=secrets.token_urlsafe(32)
        with psycopg.connect(**self.database) as db:db.execute('INSERT INTO auth_servers VALUES(%s,%s,%s,%s,true)',(name,digest(credential),fingerprint,int(time.time())+120))
        return credential
    def issue(self,account,server,nonce,protocol=5,expires=None):
        ticket=secrets.token_urlsafe(32)
        with psycopg.connect(**self.database) as db:
            trusted=db.execute('SELECT approved,expires,fingerprint FROM auth_servers WHERE id=%s FOR SHARE',(server,)).fetchone()
            if not trusted or not trusted[0] or trusted[1]<=time.time():raise ValueError('server unavailable')
            db.execute('INSERT INTO auth_tickets(digest,account,server,protocol,nonce,expires,fingerprint) VALUES(%s,%s,%s,%s,%s,%s,%s)',(digest(ticket),account,server,protocol,nonce,int(time.time())+30 if expires is None else expires,trusted[2]))
        return ticket
    def redeem(self,ticket,server,credential,fingerprint,nonce,protocol=5):
        with psycopg.connect(**self.database) as db:
            trusted=db.execute('SELECT credential,fingerprint,expires,approved FROM auth_servers WHERE id=%s FOR SHARE',(server,)).fetchone()
            if not trusted or not trusted[3] or trusted[2]<=time.time() or not secrets.compare_digest(trusted[0],digest(credential)) or trusted[1]!=fingerprint:return None
            row=db.execute('SELECT account,server,protocol,nonce,expires,used,fingerprint FROM auth_tickets WHERE digest=%s FOR UPDATE',(digest(ticket),)).fetchone()
            if not row or row[5] or row[1]!=server or row[2]!=protocol or row[3]!=nonce or row[4]<=time.time() or row[6]!=fingerprint:return None
            db.execute('UPDATE auth_tickets SET used=true WHERE digest=%s',(digest(ticket),))
            return row[0]

class PrivateGuests:
    def __init__(self,path):
        self.path=path
        with sqlite3.connect(path) as db:db.execute('CREATE TABLE IF NOT EXISTS guests(world TEXT, player TEXT, fingerprint TEXT NOT NULL, credential TEXT NOT NULL, generation INTEGER NOT NULL, PRIMARY KEY(world,player))')
    def create(self,world,fingerprint):
        player=str(uuid.uuid4());credential=secrets.token_urlsafe(32)
        with sqlite3.connect(self.path) as db:db.execute('INSERT INTO guests VALUES(?,?,?,?,0)',(world,player,fingerprint,digest(credential)))
        return player,credential
    def reconnect(self,world,player,fingerprint,credential):
        with sqlite3.connect(self.path) as db:
            db.execute('BEGIN IMMEDIATE')
            row=db.execute('SELECT fingerprint,credential,generation FROM guests WHERE world=? AND player=?',(world,player)).fetchone()
            if not row or row[0]!=fingerprint or not secrets.compare_digest(row[1],digest(credential)):return None
            generation=row[2]+1
            db.execute('UPDATE guests SET generation=? WHERE world=? AND player=?',(generation,world,player))
            return generation
    def current(self,world,player,generation):
        with sqlite3.connect(self.path) as db:row=db.execute('SELECT generation FROM guests WHERE world=? AND player=?',(world,player)).fetchone()
        return row is not None and row[0]==generation
