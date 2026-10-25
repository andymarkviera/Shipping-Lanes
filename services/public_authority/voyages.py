"""Trusted-server container contracts; invoked inside the account/lease transaction.

Port IDs attest an authoritative docking check by the game server, not client input.
No peer-facing route is exposed here. Never wire this to an unrestricted RPC.
"""
import copy
import uuid

PORTS = ('port_brindle_quay', 'port_slatewater_works')
OFFERS = {
    f'container_seed_v1_{route}_{index}': dict(
        offer_id=f'container_seed_v1_{route}_{index}', origin=PORTS[route],
        destination=PORTS[1-route], quantity=index+1, reward_minor=(index+1)*25000)
    for route in range(2) for index in range(3)
}
KIND = 'container_voyage_v1'
OPERATIONS = ('voyage_accept', 'voyage_load', 'voyage_deliver', 'voyage_cancel')


def batch(job):
    return dict(id='cargo_'+job['id'], definition='cargo_test_container', state='aboard',
                ship=job['ship'], quantity=job['quantity'], unit='count',
                job_id=job['id'], origin=job['origin'], destination=job['destination'])


def transition(profile, request, now_ms, treasury):
    """Return a candidate only: caller commits receipt, profile and money together."""
    data = copy.deepcopy(profile)
    jobs = [j for j in data['jobs'] if j.get('kind') == KIND]
    active = [j for j in jobs if j['state'] in ('loading', 'loaded')]
    if len(active) > 1:
        return 'INCONSISTENT_VOYAGE', profile, 0, None
    op = request['op']
    job = active[0] if active else None
    if op == 'voyage_accept':
        offer = OFFERS.get(request['offer_id'])
        if not offer: return 'UNKNOWN_OFFER', profile, 0, None
        if request['port_id'] != offer['origin']: return 'WRONG_PORT', profile, 0, None
        if job: return 'JOB_ALREADY_ACTIVE', profile, 0, None
        if data['ship']['definition'] != 'ship_starter_container_01': return 'WRONG_SHIP', profile, 0, None
        if any(j['offer_id'] == offer['offer_id'] and j['state'] in ('delivered', 'abandoned') for j in jobs):
            return 'OFFER_CLOSED', profile, 0, None
        if len(jobs) >= 1000: return 'HISTORY_LIMIT', profile, 0, None
        used = sum(c.get('quantity', 1) for c in data['cargo'])
        if used + offer['quantity'] > 6: return 'HOLD_FULL', profile, 0, None
        job = dict(offer, id=str(uuid.uuid5(uuid.UUID(request['account']), 'voyage_'+request['action_id'])),
                   kind=KIND, state='loading', ship=data['ship']['id'],
                   accepted_ms=now_ms, ready_ms=now_ms+offer['quantity']*5000)
        data['jobs'].append(job)
        return 'JOB_ACCEPTED', data, 0, job
    if not job or job['id'] != request['job_id']: return 'JOB_NOT_ACTIVE', profile, 0, None
    if job['ship'] != data['ship']['id']: return 'WRONG_SHIP', profile, 0, None
    expected = batch(job)
    if op == 'voyage_load':
        if job['state'] != 'loading': return 'ALREADY_LOADED', profile, 0, None
        if request['port_id'] != job['origin']: return 'WRONG_PORT', profile, 0, None
        if now_ms < job['ready_ms']: return 'LOADING_PENDING', profile, 0, None
        if sum(c.get('quantity', 1) for c in data['cargo']) + job['quantity'] > 6: return 'HOLD_FULL', profile, 0, None
        if any(c['id'] == expected['id'] for c in data['cargo']): return 'INCONSISTENT_CARGO', profile, 0, None
        data['cargo'].append(expected)
        job['state'] = 'loaded'
        return 'CARGO_LOADED', data, 0, job
    if op == 'voyage_deliver':
        if job['state'] != 'loaded': return 'CARGO_NOT_LOADED', profile, 0, None
        if request['port_id'] != job['destination']: return 'WRONG_PORT', profile, 0, None
        if data['cargo'].count(expected) != 1: return 'INCONSISTENT_CARGO', profile, 0, None
        if treasury < job['reward_minor']: return 'INSUFFICIENT_RESOURCES', profile, 0, None
        data['cargo'].remove(expected)
        data['delivered'].append(expected['id'])
        job['state'] = 'delivered'
        return 'VOYAGE_DELIVERED', data, job['reward_minor'], job
    if op == 'voyage_cancel':
        if job['state'] == 'loaded':
            if not request['abandon']: return 'CONFIRM_ABANDON', profile, 0, None
            if data['cargo'].count(expected) != 1: return 'INCONSISTENT_CARGO', profile, 0, None
            data['cargo'].remove(expected)
            job['state'] = 'abandoned'
        else:
            job['state'] = 'cancelled'
        return 'JOB_CLOSED', data, 0, job
    return 'BAD_REQUEST', profile, 0, None
