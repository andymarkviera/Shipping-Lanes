"""Cash-basis voyage windows. Costs before acceptance are never invented or amortized.

Called once inside the existing receipt transaction, after recovery repayment.
All amounts are integer minor credits; unknown legacy history is explicitly partial.
"""
import copy
from voyages import KIND


def record(before, candidate, op, code, wallet, amount, repayment):
    current = candidate.get('voyage_accounting')
    old_job = next((j for j in before['jobs'] if j.get('kind') == KIND and j.get('state') in ('loading', 'loaded')), None)
    new_job = next((j for j in candidate['jobs'] if j.get('kind') == KIND and j.get('state') in ('loading', 'loaded')), None)
    if current is None and (code == 'JOB_ACCEPTED' or old_job):
        job = new_job if code == 'JOB_ACCEPTED' else old_job
        current = dict(job_id=job['id'], partial=code != 'JOB_ACCEPTED', wallet_start_minor=wallet,
                       gross_revenue_minor=0, acquisition_cost_minor=0, fuel_minor=0, repair_minor=0,
                       recovery_paid_minor=0, recovery_repaid_minor=0, other_cash_minor=0)
        candidate['voyage_accounting'] = current
    if current is None: return None
    gross = amount + repayment
    if op in ('voyage_deliver', 'deliver'):
        current['gross_revenue_minor'] += gross
    elif op in ('ship_purchase', 'purchase'):
        current['acquisition_cost_minor'] -= gross
    elif op == 'refuel': current['fuel_minor'] -= gross
    elif op == 'repair': current['repair_minor'] -= gross
    elif code == 'SHIP_SUNK': current['recovery_paid_minor'] -= gross
    else: current['other_cash_minor'] += gross
    current['recovery_repaid_minor'] += repayment
    current['wallet_end_minor'] = wallet + amount
    current['net_minor'] = (current['gross_revenue_minor'] - current['acquisition_cost_minor']
                            - current['fuel_minor'] - current['repair_minor'] - current['recovery_paid_minor']
                            - current['recovery_repaid_minor'] + current['other_cash_minor'])
    # Fail the transaction rather than publish an unreconciled report.
    if current['net_minor'] != current['wallet_end_minor'] - current['wallet_start_minor']:
        raise ValueError('Voyage cash ledger does not reconcile')
    if code in ('VOYAGE_DELIVERED', 'JOB_CLOSED', 'SHIP_SUNK'):
        current['outcome'] = code
        candidate['last_voyage_report'] = copy.deepcopy(current)
        candidate.pop('voyage_accounting')
        return candidate['last_voyage_report']
    return current
