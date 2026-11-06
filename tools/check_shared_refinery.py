"""Real PostgreSQL + two HTTPS replicas + two public-server processes + private host.

Reuse the isolated Step 75 cluster/TLS/lease fixture. Never points at a live DB.
Usage: python tools/check_shared_refinery.py --postgres-bin PATH --work PATH
"""
import concurrent.futures
import json
import os
from pathlib import Path
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from check_oil_market import main
from services.refinery.client import PublicClient
from services.oil_market.client import PublicClient as OilClient
from services.refinery.processing import REFINERY_ID, PORT_ID
from services.refinery.private import SharedPrivateStore
from services.oil_market.test_settlement import profile
from services.refinery import shared


def remote(config, request):
    return os.getpid(), PublicClient(**config).execute(request)


def private_host(path, account):
    store=SharedPrivateStore(path,'private:host')
    store.initialize(); store.provision(account,profile(),20000)
    def request(op,**extra):
        return dict(realm='private:host',account=account,epoch=1,generation=1,op=op,**extra)
    q=store.execute(account,request('oil_quote',port_id='port_brindle_quay',side='buy',barrels=5,lot_id=''))['quote']
    assert store.execute(account,request('oil_accept',action_id='buy',expected_revision=0,quote_id=q['id'],quote_version=q['version'],port_id=q['port']))['ok']
    assert store.refinery(account,request('refinery_submit',refinery_id=REFINERY_ID,action_id='input',expected_revision=1,lot_id=q['id'],input_millibarrels=5000,port_id=PORT_ID))['ok']
    for _ in range(5): store.advance(1000)
    return os.getpid(),store.refinery(account,request('refinery_snapshot',refinery_id=REFINERY_ID))


def scenario(authority, clients, accounts, owners, start, stop, children, work, database_control):
    def req(n, op, **extra):
        return dict(realm='public',account=accounts[n],epoch=owners[n]['epoch'],generation=owners[n]['generation'],
                    refinery_id=REFINERY_ID,op=op,**extra)
    def call(n, op, **extra):
        result=PublicClient(**clients[n]).execute(req(n,op,**extra))
        assert result['ok'],result
        return result
    def snap(n=0): return call(n,'refinery_snapshot')
    def submit(n, action, units=1000):
        return req(n,'refinery_submit',action_id=action,expected_revision=snap(n)['revision'],lot_id=lots[n],
                   input_millibarrels=units,port_id=PORT_ID)
    def withdraw(q,action):
        return req(0,'refinery_withdraw',action_id=action,expected_revision=snap()['revision'],quote_id=q['id'],port_id=PORT_ID)
    def finish(intent):
        result=PublicClient(**clients[0]).execute(intent); assert result['ok'],result
        time.sleep(1.05)
        assert snap()['jobs'][0]['status']=='complete'
    lots=[]
    for n in range(2):
        oil=OilClient(**clients[n])
        def oilreq(op,**extra):
            return {k:v for k,v in req(n,op,**extra).items() if k!='refinery_id'}
        q=oil.execute(oilreq('oil_quote',port_id='port_brindle_quay',side='buy',barrels=10,lot_id=''))['quote']
        result=oil.execute(oilreq('oil_accept',action_id='buy',expected_revision=0,quote_id=q['id'],quote_version=q['version'],port_id=q['port']))
        assert result['ok'],result
        lots.append(q['id'])
    # Initializers and scene/server absence must not replace stock identity.
    authority.initialize()
    finish(submit(0,'input'))
    assert snap()['owner']['stock_millibarrels']==700
    assert snap(1)['stock_millibarrels']==700 and snap(1)['owner']['stock_millibarrels']==0
    other_input=submit(1,'other-input')
    assert PublicClient(**clients[1]).execute(other_input)['ok']
    time.sleep(1.05)
    assert snap(1)['owner']['stock_millibarrels']==700
    assert snap()['stock_millibarrels']==1400
    assert not PublicClient(**clients[1]).execute(req(0,'refinery_snapshot'))['ok']
    with concurrent.futures.ProcessPoolExecutor(1) as pool:
        private_pid, private_stock=pool.submit(private_host,work/'private.sqlite',accounts[0]).result(timeout=10)
    assert private_pid!=os.getpid() and private_stock['stock_millibarrels']==3500
    assert snap()['stock_millibarrels']==1400
    assert PublicClient(**clients[0]).execute(dict(req(0,'refinery_snapshot'),realm='private:host'))['code']=='BAD_REQUEST'
    # Bypass transport validation to verify public authority rejects private data.
    assert authority.execute(clients[0]['server'],clients[0]['credential'],dict(req(0,'refinery_snapshot'),realm='private:host'))['code']=='WRONG_REALM'
    print('PASS two public servers share facility; private host and account stock isolated',flush=True)
    q=call(0,'refinery_quote',millibarrels=700,port_id=PORT_ID)['quote']
    foreign=req(1,'refinery_withdraw',action_id='foreign',expected_revision=snap(1)['revision'],quote_id=q['id'],port_id=PORT_ID)
    assert PublicClient(**clients[1]).execute(foreign)['code']=='UNKNOWN_QUOTE'
    intent=withdraw(q,'take')
    # Same approved game server via separate replicas/processes exercises the DB
    # lock. A different approved server is additionally fenced by the account lease.
    alternate=dict(clients[0],endpoint=clients[1]['endpoint'])
    with concurrent.futures.ProcessPoolExecutor(2) as pool:
        jobs=[pool.submit(remote,c,intent) for c in (clients[0],alternate)]
        results=[j.result(timeout=15) for j in jobs]
        assert len({r[0] for r in results})==2
        assert all(r[1]['ok'] for r in results),results
        assert sum(bool(r[1].get('duplicate')) for r in results)==1
    assert snap()['owner']['stock_millibarrels']==0
    print('PASS two process concurrent withdrawal: exactly one debit/collection',flush=True)
    finish(submit(0,'input-contention'))
    quotes=[call(0,'refinery_quote',millibarrels=700,port_id=PORT_ID)['quote'] for _ in range(2)]
    intents=[withdraw(q,'contend'+str(i)) for i,q in enumerate(quotes)]
    with concurrent.futures.ProcessPoolExecutor(2) as pool:
        jobs=[pool.submit(remote,c,r) for c,r in zip((clients[0],alternate),intents)]
        results=[j.result(timeout=15)[1] for j in jobs]
    assert sum(r['ok'] for r in results)==1,results
    loser=next(r for r,result in zip(intents,results) if not result['ok'])
    assert PublicClient(**clients[0]).execute(dict(loser,expected_revision=snap()['revision']))['code']=='INSUFFICIENT_STOCK'
    print('PASS distinct IDs/quotes cannot withdraw the same remaining stock',flush=True)
    for operation in ('submit','complete','withdraw'):
        for stage in ('before_commit','after_commit'):
            action=operation+'_'+stage
            if operation=='submit': intent=submit(0,action)
            elif operation=='complete':
                intent=submit(0,'prepare_'+action)
                assert PublicClient(**clients[0]).execute(intent)['ok']
                time.sleep(1.05)
                intent=req(0,'refinery_snapshot')
            else:
                finish(submit(0,'prepare_'+action))
                intent=withdraw(call(0,'refinery_quote',millibarrels=700,port_id=PORT_ID)['quote'],action)
            with authority.connect() as db:
                before=db.execute('SELECT state FROM public_authority.refineries').fetchone()['state']
            stop(0)
            selector=dict(stage=stage,operation='refinery_snapshot') if operation=='complete' else dict(stage=stage,action_id=action)
            start(0,selector)
            result=PublicClient(**clients[0]).execute(intent)
            assert result.get('code')=='REFINERY_UNAVAILABLE',result
            children[0].wait(timeout=5)
            assert (work/'fault0').read_text()==stage
            with authority.connect() as db:
                state=db.execute('SELECT state FROM public_authority.refineries').fetchone()['state']
                if stage=='before_commit': assert state==before
                if operation!='complete':
                    count=db.execute('SELECT count(*) AS n FROM public_authority.receipts WHERE account=%s AND action_id=%s',(accounts[0],action)).fetchone()['n']
                    assert count==int(stage=='after_commit')
            start(0)
            result=PublicClient(**clients[0]).execute(intent); assert result['ok'],result
            if operation!='complete': assert result.get('duplicate',False)==(stage=='after_commit')
            if operation=='submit': time.sleep(1.05)
            snap()
            print('PASS actual SQL service crash '+operation+' '+stage,flush=True)
    # Stop both services while processing; central elapsed-time deadline survives.
    intent=submit(0,'offline'); assert PublicClient(**clients[0]).execute(intent)['ok']
    stop(0); stop(1); time.sleep(1.05); start(0); start(1)
    first=snap(); second=snap()
    assert first['jobs'][0]['status']=='complete'
    assert first['owner']==second['owner']
    authority.initialize()
    assert snap()['owner']==first['owner']
    print('PASS all server lifetimes end; restart completes once without scenery',flush=True)
    database_control('stop')
    unavailable=PublicClient(**clients[0]).execute(req(0,'refinery_snapshot'))
    assert unavailable['code']=='REFINERY_UNAVAILABLE' and 'owner' not in unavailable,unavailable
    database_control('start')
    assert snap()['owner']==first['owner']
    print('PASS PostgreSQL outage fails closed; database restart preserves stock',flush=True)
    # Move the account to server B; old server cannot withdraw; receipt survives.
    stale=dict(intent)
    source=dict(clients[0])
    released=authority.execute(source['server'],source['credential'],{k:v for k,v in req(0,'release').items() if k!='refinery_id'})
    assert released['ok'],released
    ticket=authority.issue_ticket(accounts[0],clients[1]['server'],'handoff')
    owners[0]=authority.execute(clients[1]['server'],clients[1]['credential'],dict(realm='public',op='admit',ticket=ticket,nonce='handoff'))
    assert owners[0]['ok'],owners[0]
    clients[0]=clients[1]
    assert not PublicClient(**source).execute(stale)['ok']
    replay=dict(stale,epoch=owners[0]['epoch'],generation=owners[0]['generation'])
    assert PublicClient(**clients[0]).execute(replay)['duplicate']
    assert snap()['owner']==first['owner']
    with authority.connect() as db:
        state=db.execute('SELECT state FROM public_authority.refineries').fetchone()['state']; shared.validate(state,'public')
        total=db.execute('SELECT sum(money)+(SELECT money FROM public_authority.game WHERE id=1) AS total FROM public_authority.profiles').fetchone()['total']
        assert total==1040000,total
        assert len({(w['account'],w['action_id']) for w in state['withdrawals']})==len(state['withdrawals'])
        db.execute('DELETE FROM public_authority.refineries')
    from services.oil_market.model import MarketError
    try: authority.initialize()
    except MarketError as error: assert str(error)=='REFINERY_UNAVAILABLE'
    else: raise AssertionError('missing refinery reseeded')
    assert PublicClient(**clients[0]).execute(req(0,'refinery_snapshot'))['code']=='REFINERY_UNAVAILABLE'
    print('PASS handoff fencing/replay, conserved money, missing state fails closed',flush=True)
    print('Evidence:',work)


if __name__=='__main__': main(scenario)
