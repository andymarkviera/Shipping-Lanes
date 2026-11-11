"""Isolated real PostgreSQL/HTTPS cargo-fuel voyage and crash/retry checks."""
import concurrent.futures
import time
from check_oil_market import main
from services.refinery.client import PublicClient
from services.oil_market.client import PublicClient as OilClient
from services.refinery.processing import REFINERY_ID, PORT_ID
from services.refinery.cargo_fuel import SALE_PORT


def scenario(authority, clients, accounts, owners, start, stop, children, work, database_control):
    account = accounts[0]
    def req(op, **extra):
        return dict(realm='public', account=account, epoch=owners[0]['epoch'],
                    generation=owners[0]['generation'], refinery_id=REFINERY_ID, op=op, **extra)
    def execute(request): return PublicClient(**clients[0]).execute(request)
    def snap():
        result = execute(req('refinery_snapshot'))
        assert result['ok'], result
        return result
    with authority.connect() as db:
        db.execute("UPDATE public_authority.profiles SET profile=jsonb_set(profile,'{ship,fuel_liters}','321.5') WHERE account=%s", (account,))
    oil = OilClient(**clients[0])
    def oilreq(op, **extra): return {k:v for k,v in req(op, **extra).items() if k != 'refinery_id'}
    quote = oil.execute(oilreq('oil_quote', port_id=SALE_PORT, side='buy', barrels=1, lot_id=''))['quote']
    bought = oil.execute(oilreq('oil_accept', action_id='buy', expected_revision=0, quote_id=quote['id'], quote_version=quote['version'], port_id=SALE_PORT))
    assert bought['ok'], bought
    assert execute(req('refinery_submit', action_id='refine', expected_revision=1, lot_id=quote['id'], input_millibarrels=1000, port_id=PORT_ID))['ok']
    time.sleep(1.05)
    quote = execute(req('refinery_quote', millibarrels=700, port_id=PORT_ID))['quote']
    withdrawn = execute(req('refinery_withdraw', action_id='withdraw', expected_revision=2, quote_id=quote['id'], port_id=PORT_ID))
    assert withdrawn['ok'], withdrawn
    initial_wallet = snap()['money']
    def view():
        with authority.connect() as db:
            return (db.execute('SELECT * FROM public_authority.profiles WHERE account=%s',(account,)).fetchone(),
                    db.execute('SELECT state FROM public_authority.refineries').fetchone(),
                    db.execute('SELECT money FROM public_authority.game').fetchone())
    for op in ('refinery_load','refinery_sell'):
        extra = dict(collection_id='withdraw') if op=='refinery_load' else dict(lot_id='load')
        action = 'load' if op=='refinery_load' else 'sell'
        intent = req(op, action_id=action, expected_revision=snap()['revision'],
                     millibarrels=700, port_id=PORT_ID if op=='refinery_load' else SALE_PORT, **extra)
        before = view()
        for stage in ('before_commit','after_commit'):
            stop(0); start(0,dict(stage=stage,action_id=action))
            result=execute(intent)
            assert result.get('uncertain') and result['code']=='REFINERY_UNAVAILABLE',result
            children[0].wait(timeout=5)
            assert (work/'fault0').read_text()==stage
            if stage=='before_commit': assert view()==before
            start(0)
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results=list(pool.map(execute,[intent,intent]))
        assert all(r.get('duplicate') for r in results), results
        with authority.connect() as db:
            count=db.execute('SELECT count(*) AS n FROM public_authority.journal WHERE account=%s AND action_id=%s',(account,action)).fetchone()['n']
            assert count==1
        assert view()[0]['profile']['ship']['fuel_liters']==321.5
        # Other approved server still cannot spend this account's cargo/receipt.
        assert not PublicClient(**clients[1]).execute(intent)['ok']
        print('PASS public cargo fuel '+op+' before/after COMMIT death, replay and fencing',flush=True)
    assert snap()['money']==initial_wallet+224
    assert snap()['cargo_fuel']==[] and snap()['collections']==[]
    before=view()
    database_control('stop')
    assert execute(req('refinery_snapshot'))['code']=='REFINERY_UNAVAILABLE'
    database_control('start')
    assert view()==before
    assert execute(intent)['duplicate']
    source=dict(clients[0])
    assert authority.execute(source['server'],source['credential'],oilreq('release'))['ok']
    ticket=authority.issue_ticket(account,clients[1]['server'],'fuel-handoff')
    owners[0]=authority.execute(clients[1]['server'],clients[1]['credential'],dict(realm='public',op='admit',ticket=ticket,nonce='fuel-handoff'))
    assert owners[0]['ok']
    clients[0]=clients[1]
    assert execute(dict(intent,epoch=owners[0]['epoch'],generation=owners[0]['generation']))['duplicate']
    assert not PublicClient(**source).execute(intent)['ok']
    assert snap()['money']==initial_wallet+224
    print('PASS wallet +224, unchanged propulsion, database restart and account handoff',flush=True)


if __name__ == '__main__': main(scenario)
