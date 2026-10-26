"""Real HTTPS/SQL refueling: atomicity, replay, capacity and authority boundaries."""
import json
from concurrent.futures import ThreadPoolExecutor
from voyage_probe import VoyageProof
from probe import CHECKS, check

class Fuel(VoyageProof):
    def request(self, grant, action, **kw):
        return self.command(grant, 'refuel', action, port_id='port_brindle_quay', liters=kw.pop('liters', 10), unit_price_minor=kw.pop('unit_price_minor',25), **kw)

    def exercise(self):
        a=self.session('fuel-a'); b=self.session('fuel-b')
        original=self.call('server-a',self.owned(a,'inspect'))
        req=self.request(a,'purchase',liters=25)
        with ThreadPoolExecutor(2) as pool:
            results=list(pool.map(lambda _:self.call('server-a',req),range(2)))
        check(all(r['ok'] for r in results) and sum(bool(r.get('duplicate')) for r in results)==1,'concurrent repeated purchase charges once')
        current=self.call('server-a',self.owned(a,'inspect'))
        check(current['money']==19375 and current['profile']['ship']['fuel_liters']==825,'25 L and exact debit committed together')
        check(current['profile']['cargo']==original['profile']['cargo'],'propulsion purchase creates no cargo')
        check(self.call('server-a',dict(req,liters=26))['code']=='ID_CONFLICT','purchase ID cannot change quantity')
        check(self.call('server-a',dict(req,action_id='stale'))['code']=='STALE_REVISION','new ID with old revision cannot repeat purchase')
        for i,q in enumerate([0,-1,1001,1.5,True]):
            invalid=dict(self.request(a,'bad_'+str(i)),liters=q)
            check(self.call('server-a',invalid)['code']=='BAD_QUANTITY','invalid quantity rejected '+str(q))
        for code,changes in [('QUOTE_CHANGED',{'unit_price_minor':0}),('NO_REFUEL_SERVICE',{'port_id':'ocean'}),('TANK_SPACE',{'liters':176})]:
            req=self.request(a,code)
            req.update(changes)
            check(self.call('server-a',req)['code']==code,'reject '+code)
        check(self.call('server-a',dict(self.request(a,'extra'),price=0))['code']=='BAD_REQUEST','caller cannot add arbitrary price fields')
        req=self.request(a,'full',liters=175)
        check(self.call('server-a',req)['ok'],'fill exact remaining tank space')
        check(self.call('server-a',self.request(a,'overflow',liters=1))['code']=='TANK_SPACE','full tank cannot charge or overfill')
        current=self.call('server-a',self.owned(a,'inspect'))
        check(current['money']==15000 and current['profile']['ship']['fuel_liters']==1000,'full tank has exact conserved balance')
        # Insufficient funds fixture uses normal checkpoint to empty the tank.
        cur=self.call('server-a',self.owned(b,'inspect'))
        check(self.call('server-a',self.owned(b,'checkpoint',expected_revision=cur['revision'],position=cur['profile']['ship']['position'],fuel_liters=0))['ok'],'empty propulsion fixture saved')
        check(self.call('server-a',self.request(b,'poor',liters=1000))['code']=='INSUFFICIENT_FUNDS','insufficient credits cannot partially charge or fill')
        cur=self.call('server-a',self.owned(b,'inspect'))
        check(cur['money']==20000 and cur['profile']['ship']['fuel_liters']==0,'rejected purchase changes neither balance nor fuel')
        stale=dict(self.request(b,'stale_owner'),generation=b['generation']+1)
        check(self.call('server-a',stale)['code']=='STALE_AUTHORITY','wrong authority cannot refuel')
        self.start_service()
        check(self.call('server-a',self.owned(a,'inspect'))==current,'service restart preserves full tank and wallet')
        with self.authority.connect() as db:
            rows=db.execute('SELECT amount FROM public_authority.journal WHERE account=%s',(a['account'],)).fetchall()
        check(sum(r['amount'] for r in rows)==-5000 and len(rows)==2,'only successful fuel purchases enter journal')

    def crashes(self):
        for stage in ['after_profile_write','before_commit','after_commit']:
            a=self.session('refuel-crash-'+stage)
            req=self.request(a,'crash_'+stage,liters=40)
            self.start_service(dict(stage=stage,action_id=req['action_id']))
            try:self.call('server-a',req)
            except Exception:
                self.process.wait(timeout=8)
                check(self.process.returncode==91 and (self.run/'fault-marker').read_text()==stage,'real service terminated at '+stage)
            else:raise AssertionError('fault not triggered')
            self.start_service()
            cur=self.call('server-a',self.owned(a,'inspect')); committed=stage=='after_commit'
            check(cur['money']==(19000 if committed else 20000) and cur['profile']['ship']['fuel_liters']==(840 if committed else 800),'fuel and debit atomic at '+stage)
            result=self.call('server-a',req)
            check(result['ok'] and bool(result.get('duplicate'))==committed,'uncertain purchase recovers exactly once at '+stage)
            check(self.call('server-a',req).get('duplicate'),'further purchase replay is harmless')

if __name__=='__main__':
    proof=Fuel()
    try:
        proof.setup();proof.exercise();proof.crashes()
        (proof.run/'refuel-summary.json').write_text(json.dumps(dict(passed=True,checks=CHECKS),indent=2),encoding='utf-8')
        print('PUBLIC_REFUEL_PASS',len(CHECKS),'Evidence:',proof.run,flush=True)
    finally:proof.close()
