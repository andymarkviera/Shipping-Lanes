"""One condition meter. Trusted simulated propulsion time, never wall-clock age."""
BP_PER_HOUR = 100.0  # 1% per active hour; provisional tuning.
FLOOR_BP = 1000      # Wear alone cannot sink a ship.


def apply(ship, seconds):
    remainder = ship.get('wear_fraction_bp', 0.0) + seconds * BP_PER_HOUR / 3600.0
    whole = int(remainder)
    current = ship.get('condition_bp', 10000)
    ship['condition_bp'] = max(min(current, FLOOR_BP), current - whole)
    ship['wear_fraction_bp'] = remainder - whole
    return ship['condition_bp']
