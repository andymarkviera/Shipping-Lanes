"""Approved public game servers only; verified HTTPS and no private fallback."""
from services.oil_market.client import PublicClient as Transport
from .shared import OPERATIONS


class PublicClient(Transport):
    operations = OPERATIONS
    mutations = ('refinery_submit', 'refinery_withdraw')
    unavailable_code = 'REFINERY_UNAVAILABLE'
