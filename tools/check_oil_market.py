"""Isolated PostgreSQL + two HTTPS authorities + two public-server processes.

Requires psycopg/cryptography, openssl and a PostgreSQL bin directory. Creates its
OWN cluster under --work; never connects to, resets, or provisions a live database.
"""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT/'services/public_authority'))
from authority import Authority
from psycopg.types.json import Jsonb
from services.oil_market.client import PublicClient
from services.oil_market.test_settlement import profile


def port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def remote(config, requests):
    """Executed in a distinct trusted game-server process."""
    client = PublicClient(**config)
    return os.getpid(), [client.execute(r) for r in requests]


def economic_view(market):
    # Observation timestamps legitimately differ between serialized readers.
    return dict(market, ports={p: {k: v for k, v in row.items() if k != 'observed_at'}
                               for p, row in market['ports'].items()})


def main(scenario=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--postgres-bin', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    args = parser.parse_args()
    work = args.work.resolve()/('public-oil-'+uuid.uuid4().hex[:8]); work.mkdir(parents=True)
    bindir = args.postgres_bin.resolve()
    cluster = work/'cluster'
    def command(argv):
        with (work/'setup.log').open('a') as log:
            subprocess.run([str(x) for x in argv], stdout=log, stderr=subprocess.STDOUT, check=True)
    command([bindir/'initdb', '-D', cluster, '-A', 'trust', '--no-locale', '-E', 'UTF8', '-U', 'oil_test'])
    dbport = port()
    command([bindir/'pg_ctl', '-D', cluster, '-l', work/'postgres.log', '-o',
             f'-h 127.0.0.1 -p {dbport} -k {work}', '-w', 'start'])
    children = {}
    logs = []
    try:
        authority = Authority(dict(host='127.0.0.1', port=dbport, user='oil_test', dbname='postgres'))
        authority.initialize()
        # Re-running the additive migration must retain the exact durable owner.
        with authority.connect() as db:
            identity = db.execute('SELECT state FROM public_authority.oil_market').fetchone()['state']['market_id']
        authority.initialize()
        command(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                 '-keyout', work/'key.pem', '-out', work/'cert.pem', '-subj', '/CN=localhost',
                 '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1'])
        configs, clients, accounts, owners = [], [], [], []
        for n in range(2):
            server = 'oil_server_'+str(n)
            credential = authority.register_server(server, 'f'*64)
            account = authority.create_fixture_account('fixture', 'captain'+str(n))
            with authority.connect() as db:
                db.execute('UPDATE public_authority.profiles SET profile=%s WHERE account=%s', (Jsonb(profile()), account))
            ticket = authority.issue_ticket(account, server, 'nonce')
            owner = authority.execute(server, credential, dict(realm='public', op='admit', ticket=ticket, nonce='nonce'))
            assert owner['ok'], owner
            config = dict(database=authority.database, port=port(), certificate=str(work/'cert.pem'),
                          key=str(work/'key.pem'), ready=str(work/f'ready{n}'))
            configs.append(config)
            clients.append(dict(endpoint=f'https://localhost:{config["port"]}/v1/authority',
                                server=server, credential=credential, cafile=str(work/'cert.pem')))
            accounts.append(account); owners.append(owner)
        def start(n, fault=None):
            config = dict(configs[n])
            if fault: config.update(fault=fault, fault_marker=str(work/f'fault{n}'))
            path = work/f'service{n}.json'; path.write_text(json.dumps(config)); path.chmod(0o600)
            ready = Path(config['ready']); ready.unlink(missing_ok=True)
            log = (work/f'service{n}.log').open('a'); logs.append(log)
            children[n] = subprocess.Popen([sys.executable, str(ROOT/'services/public_authority/service.py'), str(path)], stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic()+10
            while not ready.exists():
                assert children[n].poll() is None, f'service {n} failed: {work}'
                assert time.monotonic()<deadline, 'service readiness timeout'
                time.sleep(.05)
        def stop(n):
            if children[n].poll() is None:
                children[n].terminate(); children[n].wait(timeout=10)
        def req(n, op, **extra):
            return dict(realm='public', op=op, account=accounts[n], epoch=owners[n]['epoch'], generation=owners[n]['generation'], **extra)
        def accept(n, q, action, revision):
            return req(n, 'oil_accept', action_id=action, expected_revision=revision,
                       quote_id=q['id'], quote_version=q['version'], port_id=q['port'])
        start(0); start(1)
        if scenario is not None:
            def database_control(mode):
                if mode == 'stop':
                    command([bindir/'pg_ctl', '-D', cluster, '-m', 'fast', '-w', 'stop'])
                else:
                    command([bindir/'pg_ctl', '-D', cluster, '-l', work/'postgres.log', '-o',
                             f'-h 127.0.0.1 -p {dbport} -k {work}', '-w', 'start'])
            scenario(authority, clients, accounts, owners, start, stop, children, work, database_control)
            return
        with concurrent.futures.ProcessPoolExecutor(max_workers=2) as pool:
            def pair(requests):
                jobs=[pool.submit(remote, clients[n], requests[n]) for n in range(2)]
                results=[j.result(timeout=20) for j in jobs]
                assert results[0][0] != results[1][0], 'two distinct server processes required'
                return [r[1] for r in results]
            snapshots = pair([[req(n, 'oil_snapshot')] for n in range(2)])
            assert economic_view(snapshots[0][0]['market']) == economic_view(snapshots[1][0]['market'])
            assert snapshots[0][0]['market']['market_id'] == identity
            quoted = pair([[req(n, 'oil_quote', port_id='port_brindle_quay', side='buy', barrels=50, lot_id='')] for n in range(2)])
            quotes=[quoted[n][0]['quote'] for n in range(2)]
            # A quote cannot be consumed by another authenticated account/server.
            foreign=remote(clients[1],[accept(1,quotes[0],'foreign',0)])[1][0]
            assert foreign['code']=='UNKNOWN_QUOTE', foreign
            intents=[accept(n, quotes[n], 'buy'+str(n), 0) for n in range(2)]
            results=pair([[intents[n]]*8 for n in range(2)])
            for group in results:
                assert all(r['ok'] for r in group), group
                assert sum(not r.get('duplicate',False) for r in group)==1
            snapshots=pair([[req(n,'oil_snapshot')] for n in range(2)])
            assert economic_view(snapshots[0][0]['market']) == economic_view(snapshots[1][0]['market'])
            assert snapshots[0][0]['market']['ports']['port_brindle_quay']['pressure_barrels']==100
            print('PASS two public server processes: ordered shared market and concurrent retry settlement', flush=True)
            # Rebind after disconnect; old generation fenced, same durable receipt recovered.
            stale=dict(intents[0])
            ticket=authority.issue_ticket(accounts[0],clients[0]['server'],'reconnect')
            owners[0]=authority.execute(clients[0]['server'],clients[0]['credential'],dict(realm='public',op='admit',ticket=ticket,nonce='reconnect'))
            assert remote(clients[0],[stale])[1][0]['code']=='STALE_AUTHORITY'
            replay=accept(0,quotes[0],'buy0',0)
            assert remote(clients[0],[replay])[1][0]['duplicate']
            print('PASS disconnect/rebind fences stale generation and replays once',flush=True)
            rejected=authority.execute(clients[0]['server'],clients[0]['credential'],
                req(0,'deliver',action_id='not_generic_cargo',expected_revision=1,cargo_id=quotes[0]['id']))
            assert rejected['code']=='CARGO_NOT_OWNED',rejected
            revision=1
            for stage in ('after_profile_write','after_market_write','before_commit','after_commit'):
                quote=remote(clients[0],[req(0,'oil_quote',port_id='port_slatewater_works',side='sell',barrels=1,lot_id=quotes[0]['id'])])[1][0]['quote']
                intent=accept(0,quote,stage,revision)
                stop(0); start(0,dict(stage=stage,action_id=stage))
                uncertain=remote(clients[0],[intent])[1][0]
                assert uncertain['code']=='MARKET_UNAVAILABLE' and uncertain['uncertain'],uncertain
                children[0].wait(timeout=5)
                assert (work/'fault0').read_text()==stage
                with authority.connect() as db:
                    count=db.execute('SELECT count(*) AS n FROM public_authority.receipts WHERE account=%s AND action_id=%s',(accounts[0],stage)).fetchone()['n']
                    assert count==int(stage=='after_commit')
                start(0)
                recovered=remote(clients[0],[intent,intent])[1]
                assert all(r['ok'] for r in recovered),recovered
                assert recovered[1]['duplicate'] and recovered[0].get('duplicate',False)==(stage=='after_commit')
                revision+=1
                print('PASS owned service crash '+stage+' atomic recovery',flush=True)
            quote=remote(clients[0],[req(0,'oil_quote',port_id='port_slatewater_works',side='sell',barrels=1,lot_id=quotes[0]['id'])])[1][0]['quote']
            intent=accept(0,quote,'concurrent_same_quote',revision)
            second_endpoint=dict(clients[0],endpoint=clients[1]['endpoint'])
            jobs=[pool.submit(remote,c,[intent]) for c in (clients[0],second_endpoint)]
            contested=[job.result(timeout=10)[1][0] for job in jobs]
            assert all(r['ok'] for r in contested),contested
            assert sum(bool(r.get('duplicate')) for r in contested)==1
            print('PASS concurrent same-account/quote acceptance through two service processes',flush=True)
            command([bindir/'pg_ctl','-D',cluster,'-m','fast','-w','stop'])
            unavailable=pair([[req(n,'oil_snapshot')] for n in range(2)])
            assert all(g[0]['code']=='MARKET_UNAVAILABLE' for g in unavailable)
            command([bindir/'pg_ctl','-D',cluster,'-l',work/'postgres.log','-o',f'-h 127.0.0.1 -p {dbport} -k {work}','-w','start'])
            print('PASS temporary database outage fails closed and reconnects',flush=True)
            stop(0); stop(1)
            unavailable=pair([[req(n,'oil_snapshot')] for n in range(2)])
            assert all(g[0]['code']=='MARKET_UNAVAILABLE' and 'market' not in g[0] for g in unavailable)
            start(0); start(1)
            recovered=pair([[req(n,'oil_snapshot')] for n in range(2)])
            assert economic_view(recovered[0][0]['market'])==economic_view(recovered[1][0]['market'])
            print('PASS temporary service outage: no invented prices, shared restart recovery',flush=True)
            for n in range(2):
                view = recovered[n][0]
                lot = view['lots'][0]
                assert lot['sold_cost_minor'] + lot['remaining_cost_minor'] == lot['acquisition_cost_minor']
                assert lot['remaining_barrels'] == (45 if n == 0 else 50)
                assert view['last_receipt']['quote']['id'] == (quote['id'] if n == 0 else quotes[1]['id'])
                assert view['last_receipt']['wallet_minor'] == view['money']
                assert all(p['observed_at'] == view['server_time'] for p in view['market']['ports'].values())
            print('PASS per-account lot costs, wallet, last receipt and per-port timestamps survive SQL/service restart', flush=True)
            # Same action after handoff to the other approved game server.
            source=clients[0]
            authority.execute(source['server'],source['credential'],req(0,'release'))
            ticket=authority.issue_ticket(accounts[0],clients[1]['server'],'handoff')
            rebound=authority.execute(clients[1]['server'],clients[1]['credential'],dict(realm='public',op='admit',ticket=ticket,nonce='handoff'))
            moved=dict(replay,epoch=rebound['epoch'],generation=rebound['generation'])
            assert remote(clients[1],[moved])[1][0]['duplicate']
            print('PASS server handoff recovers original durable receipt',flush=True)
        with authority.connect() as db:
            rows=db.execute('SELECT sequence,event FROM public_authority.oil_history ORDER BY sequence').fetchall()
            assert [r['sequence'] for r in rows]==list(range(1,len(rows)+1))
            assert all(a['event']['version']==b['event']['before_version'] for a,b in zip(rows,rows[1:]))
            assert db.execute('SELECT count(*) AS n FROM public_authority.journal').fetchone()['n']==7
            assert db.execute('SELECT count(*) AS n FROM public_authority.receipts').fetchone()['n']==8
            assert db.execute('SELECT sum(money)+(SELECT money FROM public_authority.game WHERE id=1) AS total FROM public_authority.profiles').fetchone()['total']==1040000
            state=db.execute('SELECT state FROM public_authority.oil_market').fetchone()['state']
            assert state['sequence']==len(rows)
        print('PASS contiguous history, seven settlements plus one rejected receipt, conserved money',flush=True)
        # Removing canonical state is corruption, not permission to reinitialize.
        with authority.connect() as db:
            db.execute('DELETE FROM public_authority.oil_market')
        from services.oil_market.model import MarketError
        try:
            authority.initialize()
            raise AssertionError('missing durable market was reseeded')
        except MarketError as error:
            assert str(error)=='MARKET_UNAVAILABLE'
        print('PASS missing durable singleton cannot be silently reseeded',flush=True)
        print('Evidence:',work)
    finally:
        for child in children.values():
            if child.poll() is None: child.terminate(); child.wait(timeout=10)
        for log in logs: log.close()
        if (cluster/'postmaster.pid').exists():
            command([bindir/'pg_ctl','-D',cluster,'-m','fast','-w','stop'])

if __name__=='__main__': main()
