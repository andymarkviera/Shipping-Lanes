"""Trusted impact settlement and paid ship recovery; no peer-supplied damage."""
import copy
import math

FEE_MINOR = 25000
MIN_RECOVERY_FUEL = 100.0
SLOTS = tuple(dict(latitude=math.degrees(-350/100000), longitude=math.degrees(-x/100000), heading=0.0)
              for x in (0,150,-150,300,-300,450,-450,600))
OPERATIONS = ('impact', 'recover')


def pending(profile):
    return profile.get('recovery', {}).get('state') == 'pending'


def transition(profile, request, wallet):
    def reject(code): return code, profile, 0, None
    data = copy.deepcopy(profile)
    if request['op'] == 'impact':
        if pending(data): return reject('RECOVERY_REQUIRED')
        condition = max(0, data['ship'].get('condition_bp', 10000) - request['damage_bp'])
        data['ship'].update(condition_bp=condition, fuel_liters=request['fuel_liters'], position=request['position'])
        if condition > 0: return 'HULL_DAMAGED', data, 0, None
        paid = min(wallet, FEE_MINOR)
        debt = FEE_MINOR-paid
        data['recovery_debt_minor'] = data.get('recovery_debt_minor', 0)+debt
        data['recovery'] = dict(id=request['action_id'], state='pending', fee_minor=FEE_MINOR,
                               paid_minor=paid, debt_added_minor=debt,
                               lost_cargo=[c['id'] for c in data['cargo']])
        data['cargo'] = []
        for job in data['jobs']:
            if job.get('state') in ('active', 'loading', 'loaded'):
                job['state'] = 'failed'
                job['failure'] = 'ship_sank'
        return 'SHIP_SUNK', data, -paid, None
    if not pending(data) or data['recovery']['id'] != request['incident_id']:
        return reject('NO_RECOVERY')
    data['ship'].update(condition_bp=10000, position=dict(SLOTS[request['slot']]),
                        fuel_liters=max(MIN_RECOVERY_FUEL, data['ship']['fuel_liters']))
    data['recovery'].update(state='recovered', slot=request['slot'])
    return 'SHIP_RECOVERED', data, 0, None


def repay(profile, gross):
    """Half of earned income repays the saved recovery balance, bounded by debt."""
    repayment = min(profile.get('recovery_debt_minor', 0), max(1, gross//2)) if gross > 0 else 0
    if repayment: profile['recovery_debt_minor'] -= repayment
    return gross-repayment, repayment
