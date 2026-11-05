"""Step 74 in-memory simulation contract, not a settlement or network service.

Only the trusted market owner supplies time and records successfully simulated
trades. Step 75 must make this transition atomic with durable account settlement.
"""
from dataclasses import dataclass, field
from threading import RLock
from types import MappingProxyType
from uuid import uuid4


class MarketError(ValueError):
    """Stable explicit rejection code in str(error)."""


def integer(value, low, high):
    return type(value) is int and low <= value <= high


@dataclass(frozen=True)
class Config:
    cadence_seconds: int = 60
    quote_seconds: int = 20
    base_minor: int = 150
    floor_minor: int = 25
    ceiling_minor: int = 500
    supply_limit_barrels: int = 10000
    recovery_barrels_per_tick: int = 100
    supply_effect_minor: int = 40
    volume_effect_minor: int = 10
    max_trade_barrels: int = 200
    max_open_quotes: int = 4096
    port_offsets: dict = field(default_factory=lambda: {
        'port_brindle_quay': -25, 'port_slatewater_works': 25})

    def __post_init__(self):
        for name in ('cadence_seconds', 'quote_seconds', 'base_minor',
                     'floor_minor', 'ceiling_minor', 'supply_limit_barrels',
                     'recovery_barrels_per_tick', 'max_trade_barrels', 'max_open_quotes'):
            if not integer(getattr(self, name), 1, 10**9):
                raise MarketError('INVALID_CONFIG')
        if not self.floor_minor <= self.base_minor <= self.ceiling_minor:
            raise MarketError('INVALID_CONFIG')
        for name in ('supply_effect_minor', 'volume_effect_minor'):
            if not integer(getattr(self, name), 0, 10**9):
                raise MarketError('INVALID_CONFIG')
        if not isinstance(self.port_offsets, dict) or not 1 <= len(self.port_offsets) <= 256:
            raise MarketError('INVALID_CONFIG')
        if any(not isinstance(k, str) or not 1 <= len(k) <= 128 or
               not integer(v, -10**9, 10**9) for k, v in self.port_offsets.items()):
            raise MarketError('INVALID_CONFIG')
        object.__setattr__(self, 'port_offsets', MappingProxyType(dict(self.port_offsets)))


@dataclass(frozen=True)
class Quote:
    id: str
    market_id: str
    version: int
    port: str
    side: str  # captain buys / sells
    barrels: int
    unit_minor: int
    total_minor: int
    issued_at: int
    expires_at: int


class Market:
    """One owner per market; server IDs never select or seed public prices.

    Instances are simulation fixtures. Do not instantiate one per public server.
    No account, inventory, database, external feed, or wall-clock dependency.
    """

    def __init__(self, realm, config=None, *, start=0):
        if realm != 'public' and not (isinstance(realm, str) and
                                      realm.startswith('private:') and 8 < len(realm) <= 128):
            raise MarketError('INVALID_REALM')
        if not integer(start, 0, 2**63 - 1):
            raise MarketError('INVALID_TIME')
        self.realm = realm
        if config is not None and not isinstance(config, Config):
            raise MarketError('INVALID_CONFIG')
        self.config = config if config is not None else Config()
        self.market_id = realm + ':' + uuid4().hex
        self._time = start
        self._tick = start // self.config.cadence_seconds
        self._version = 0
        self._pressure = dict.fromkeys(self.config.port_offsets, 0)
        self._quotes = {}
        self._lock = RLock()

    def _advance(self, now):
        if not integer(now, self._time, 2**63 - 1):
            raise MarketError('INVALID_TIME')
        tick = now // self.config.cadence_seconds
        elapsed = tick - self._tick
        if elapsed:
            recovery = elapsed * self.config.recovery_barrels_per_tick
            for port, value in self._pressure.items():
                self._pressure[port] = max(0, value - recovery) if value >= 0 else min(0, value + recovery)
            self._version += elapsed
            self._tick = tick
        self._time = now
        self._quotes = {k: q for k, q in self._quotes.items() if q.expires_at > now}

    def _price(self, port, side, barrels):
        c = self.config
        # Symmetric integer truncation; bounded pressure cannot grow indefinitely.
        pressure = self._pressure[port]
        effect = abs(pressure) * c.supply_effect_minor // c.supply_limit_barrels
        if pressure < 0:
            effect = -effect
        volume = barrels * c.volume_effect_minor // c.max_trade_barrels
        return max(c.floor_minor, min(c.ceiling_minor, c.base_minor +
                   c.port_offsets[port] + effect + (volume if side == 'buy' else -volume)))

    def snapshot(self, now):
        with self._lock:
            self._advance(now)
            return dict(market_id=self.market_id, version=self._version, tick=self._tick,
                        ports={p: dict(pressure_barrels=v, reference_minor=self._price(p, 'buy', 0))
                               for p, v in self._pressure.items()})

    def quote(self, port, side, barrels, now):
        with self._lock:
            if not isinstance(port, str) or not isinstance(side, str) or port not in self._pressure or side not in ('buy', 'sell'):
                raise MarketError('INVALID_MARKET_REQUEST')
            if not integer(barrels, 1, self.config.max_trade_barrels):
                raise MarketError('INVALID_QUANTITY')
            self._advance(now)
            if len(self._quotes) >= self.config.max_open_quotes:
                raise MarketError('QUOTE_LIMIT')
            price = self._price(port, side, barrels)
            q = Quote(uuid4().hex, self.market_id, self._version, port, side, barrels,
                      price, price * barrels, now, now + self.config.quote_seconds)
            self._quotes[q.id] = q
            return q

    def record_simulated_trade(self, quote, now):
        """Consume an issued quote and change pressure, with no economic settlement.

        Fixed terms survive cadence/other trades until expiry. Durable retries and
        account settlement deliberately belong to Step 75, not this fixture.
        """
        with self._lock:
            if not isinstance(quote, Quote) or quote.market_id != self.market_id:
                raise MarketError('WRONG_MARKET')
            self._advance(now)
            if now >= quote.expires_at:
                raise MarketError('QUOTE_EXPIRED')
            original = self._quotes.get(quote.id) if isinstance(quote.id, str) else None
            if original != quote or any(type(getattr(quote, field)) is not type(getattr(original, field))
                                        for field in Quote.__dataclass_fields__):
                raise MarketError('UNKNOWN_OR_CHANGED_QUOTE')
            del self._quotes[quote.id]
            delta = quote.barrels if quote.side == 'buy' else -quote.barrels
            limit = self.config.supply_limit_barrels
            self._pressure[quote.port] = max(-limit, min(limit, self._pressure[quote.port] + delta))
            self._version += 1
            return quote


class PublicView:
    """Read/quote facade bound to the same owner, never a local-price fallback.

    This in-process contract is not a cross-process transport implementation.
    Private hosts use their own Market('private:<host>') and cannot bind here.
    """

    def __init__(self, authority=None):
        if authority is not None and authority.realm != 'public':
            raise MarketError('WRONG_MARKET')
        self._authority = authority

    def _owner(self):
        if self._authority is None:
            raise MarketError('MARKET_UNAVAILABLE')
        return self._authority

    def snapshot(self, now):
        return self._owner().snapshot(now)

    def quote(self, port, side, barrels, now):
        return self._owner().quote(port, side, barrels, now)
