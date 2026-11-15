extends RefCounted
## Data for the game: the world (M4), the ships a captain can own and the bulk
## jobs (M3). Prices and pay are in hundredths of a credit. No state lives here.
## The world: four ports on the two shores of a strait and two polar ports.
## Patch 2.9 item 6B: tools/world_layout/natural_land.py puts the four strait
## ports on seeded coastal spots; "was" and "was_side" are where they stood
## before, which pay (chart_at) and older saves still use. "drop_side" is the
## open side of the berth (+1 is +X), where heavy loads are picked up and dropped.
const WORLD = [
	{"id": "port_brindle_quay", "at": Vector3(3890, 0, -3960), "drop_side": 1.0, "was": Vector3(0, 0, 0), "was_side": 1.0},
	{"id": "port_slatewater_works", "at": Vector3(-310, 0, 630), "drop_side": 1.0, "was": Vector3(1500, 0, 0), "was_side": -1.0},
	{"id": "port_cinder_point", "at": Vector3(1660, 0, 1390), "drop_side": -1.0, "was": Vector3(-200, 0, 2200), "was_side": 1.0},
	{"id": "port_gannet_light", "at": Vector3(-410, 0, -1580), "drop_side": 1.0, "was": Vector3(1700, 0, -2200), "was_side": -1.0},
	# Patch 2.1 item 3: the two polar ports, far north (+Z) and far south.
	{"id": "port_north_pole", "at": Vector3(3700, 0, 4000), "drop_side": 1.0},
	{"id": "port_south_pole", "at": Vector3(-2300, 0, -4100), "drop_side": -1.0},
]
## The four strait ports come first. Their container jobs keep the destinations
## they had before the polar ports, so saved jobs still match their IDs.
const STRAIT_PORTS: int = 4
## Patch 2.9 item 6A: natural land. tools/world_layout/natural_land.py bakes
## irregular continents, peninsulas, bays and islands from one fixed seed into
## features/world/natural_land.json (the coast depth grid the toon coasts,
## maps and dressings read) and the blocks below: the land's 25 m samples as
## rectangles, each landmass's blocks together, biggest first. They are what
## is solid and what navigation and the checks test against. All land stays at
## least 2 km inside the world's edges; every port's quay backs onto land and
## keeps open water at its berths, approach and drop area.
## BEGIN NATURAL LAND (generated: python3 tools/world_layout/natural_land.py)
const LAND = [
	# Hearthland
	Rect2(-3037.5, -2462.5, 2525, 150),
	Rect2(-3362.5, 862.5, 2950, 125),
	Rect2(-3387.5, -37.5, 2900, 125),
	Rect2(-3312.5, 712.5, 2900, 125),
	Rect2(-3237.5, 2412.5, 2850, 125),
	Rect2(-3337.5, -287.5, 2800, 125),
	Rect2(-3162.5, -1362.5, 2650, 125),
	Rect2(-3062.5, -1637.5, 2550, 125),
	Rect2(-3312.5, 612.5, 2925, 100),
	Rect2(-3312.5, -487.5, 2825, 100),
	Rect2(-3237.5, 1087.5, 2825, 100),
	Rect2(-3337.5, -737.5, 2900, 75),
	Rect2(-3237.5, 2537.5, 2875, 75),
	Rect2(-3312.5, -612.5, 2850, 75),
	Rect2(-3212.5, 2612.5, 2850, 75),
	Rect2(-3187.5, -1237.5, 2675, 75),
	Rect2(-3162.5, -1162.5, 2650, 75),
	Rect2(-3087.5, -1512.5, 2575, 75),
	Rect2(-3037.5, -1787.5, 2525, 75),
	Rect2(-3112.5, 1587.5, 2525, 75),
	Rect2(-3087.5, 1662.5, 2500, 75),
	Rect2(-1887.5, -3587.5, 1225, 150),
	Rect2(-2987.5, -2187.5, 2375, 75),
	Rect2(-3312.5, -662.5, 2875, 50),
	Rect2(-3387.5, -87.5, 2875, 50),
	Rect2(-3362.5, -137.5, 2850, 50),
	Rect2(-3262.5, 2312.5, 2850, 50),
	Rect2(-3387.5, 137.5, 2825, 50),
	Rect2(-3237.5, 2362.5, 2825, 50),
	Rect2(-3312.5, -362.5, 2800, 50),
	Rect2(-3362.5, 187.5, 2800, 50),
	Rect2(-3212.5, 1037.5, 2800, 50),
	Rect2(-3237.5, 2262.5, 2800, 50),
	Rect2(-3137.5, 1437.5, 2750, 50),
	Rect2(-3137.5, 1387.5, 2725, 50),
	Rect2(-3137.5, 1487.5, 2725, 50),
	Rect2(-3237.5, 362.5, 2700, 50),
	Rect2(-3212.5, 412.5, 2700, 50),
	Rect2(-3212.5, 1212.5, 2700, 50),
	Rect2(-3137.5, -1412.5, 2625, 50),
	Rect2(-3062.5, -1687.5, 2575, 50),
	Rect2(-1912.5, -3387.5, 1275, 100),
	Rect2(-3012.5, -2537.5, 2525, 50),
	Rect2(-2987.5, -2587.5, 2500, 50),
	Rect2(-3012.5, -2312.5, 2475, 50),
	Rect2(-3037.5, -1862.5, 2475, 50),
	Rect2(-3012.5, -1937.5, 2425, 50),
	Rect2(-3087.5, 1787.5, 2425, 50),
	Rect2(-2962.5, 1987.5, 2425, 50),
	Rect2(-2987.5, -2237.5, 2400, 50),
	Rect2(-3012.5, -2037.5, 2350, 50),
	Rect2(-2987.5, -2087.5, 2325, 50),
	Rect2(-1837.5, -3062.5, 1300, 75),
	Rect2(-1862.5, -3187.5, 1275, 75),
	Rect2(-3337.5, 837.5, 2925, 25),
	Rect2(-3337.5, 987.5, 2925, 25),
	Rect2(-3312.5, 587.5, 2900, 25),
	Rect2(-3387.5, 87.5, 2875, 25),
	Rect2(-3287.5, 562.5, 2875, 25),
	Rect2(-3312.5, -512.5, 2850, 25),
	Rect2(-3387.5, 112.5, 2850, 25),
	Rect2(-3287.5, 537.5, 2850, 25),
	Rect2(-3187.5, 2687.5, 2850, 25),
	Rect2(-3287.5, -537.5, 2825, 25),
	Rect2(-3362.5, -162.5, 2825, 25),
	Rect2(-3162.5, 2712.5, 2825, 25),
	Rect2(-3262.5, 512.5, 2800, 25),
	Rect2(-3212.5, 1187.5, 2800, 25),
	Rect2(-3137.5, 2737.5, 2800, 25),
	Rect2(-3112.5, 2762.5, 2800, 25),
	Rect2(-3287.5, -387.5, 2775, 25),
	Rect2(-3312.5, -312.5, 2775, 25),
	Rect2(-3337.5, 237.5, 2775, 25),
	Rect2(-3312.5, 287.5, 2775, 25),
	Rect2(-3262.5, 487.5, 2775, 25),
	Rect2(-3187.5, 1012.5, 2775, 25),
	Rect2(-3312.5, 262.5, 2750, 25),
	Rect2(-3287.5, 312.5, 2750, 25),
	Rect2(-3237.5, 462.5, 2750, 25),
	Rect2(-3187.5, 2237.5, 2750, 25),
	Rect2(-3062.5, 2787.5, 2750, 25),
	Rect2(-3262.5, 337.5, 2725, 25),
	Rect2(-3162.5, 1362.5, 2725, 25),
	Rect2(-3187.5, 1287.5, 2700, 25),
	Rect2(-3162.5, 1337.5, 2700, 25),
	Rect2(-3112.5, 1537.5, 2700, 25),
	Rect2(-3187.5, 1262.5, 2675, 25),
	Rect2(-3162.5, 1312.5, 2675, 25),
	Rect2(-3112.5, 1562.5, 2675, 25),
	Rect2(-3137.5, 2212.5, 2675, 25),
	Rect2(-3137.5, -1087.5, 2625, 25),
	Rect2(-3087.5, 2187.5, 2625, 25),
	Rect2(-1887.5, -3237.5, 1300, 50),
	Rect2(-1862.5, -3112.5, 1300, 50),
	Rect2(-3112.5, -1437.5, 2600, 25),
	Rect2(-3112.5, -1062.5, 2600, 25),
	Rect2(-3087.5, -1037.5, 2575, 25),
	Rect2(-3037.5, 2162.5, 2575, 25),
	Rect2(-1887.5, -3287.5, 1275, 50),
	Rect2(-3037.5, -1712.5, 2550, 25),
	Rect2(-3037.5, -1012.5, 2525, 25),
	Rect2(-1912.5, -3437.5, 1250, 50),
	Rect2(-3012.5, -2487.5, 2500, 25),
	Rect2(-3037.5, -1812.5, 2500, 25),
	Rect2(-3012.5, -987.5, 2500, 25),
	Rect2(-3087.5, 1862.5, 2500, 25),
	Rect2(-3062.5, 1887.5, 2500, 25),
	Rect2(-3037.5, 1912.5, 2500, 25),
	Rect2(-3087.5, 1737.5, 2475, 25),
	Rect2(-3087.5, 1837.5, 2475, 25),
	Rect2(-3012.5, 1937.5, 2475, 25),
	Rect2(-2962.5, 2137.5, 2475, 25),
	Rect2(-3012.5, -1887.5, 2450, 25),
	Rect2(-3087.5, 1762.5, 2450, 25),
	Rect2(-2987.5, 1962.5, 2450, 25),
	Rect2(-2987.5, -2262.5, 2425, 25),
	Rect2(-2937.5, -962.5, 2425, 25),
	Rect2(-2937.5, 2037.5, 2425, 25),
	Rect2(-3012.5, -1962.5, 2400, 25),
	Rect2(-2912.5, 2062.5, 2400, 25),
	Rect2(-3012.5, -1987.5, 2375, 25),
	Rect2(-2862.5, 2112.5, 2375, 25),
	Rect2(-2987.5, -2112.5, 2350, 25),
	Rect2(-2862.5, 2087.5, 2350, 25),
	Rect2(-2737.5, -937.5, 2250, 25),
	Rect2(-2662.5, -912.5, 2175, 25),
	Rect2(-2637.5, -887.5, 2150, 25),
	Rect2(-1462.5, -4087.5, 2125, 25),
	Rect2(-2612.5, -862.5, 2125, 25),
	Rect2(-662.5, 3137.5, 425, 125),
	Rect2(-2587.5, -837.5, 2100, 25),
	Rect2(-1437.5, -4062.5, 2075, 25),
	Rect2(-2537.5, -762.5, 2075, 25),
	Rect2(-2512.5, -812.5, 2025, 25),
	Rect2(-2487.5, -787.5, 2025, 25),
	Rect2(-2237.5, 2812.5, 1925, 25),
	Rect2(-2162.5, 2837.5, 1875, 25),
	Rect2(-2087.5, 2862.5, 1800, 25),
	Rect2(-2262.5, -2612.5, 1775, 25),
	Rect2(-2037.5, 2887.5, 1750, 25),
	Rect2(-1437.5, -4037.5, 1725, 25),
	Rect2(-1987.5, 2912.5, 1700, 25),
	Rect2(-1887.5, -3662.5, 550, 75),
	Rect2(-2162.5, -2637.5, 1650, 25),
	Rect2(-1937.5, 2937.5, 1650, 25),
	Rect2(-2112.5, -2662.5, 1600, 25),
	Rect2(-1887.5, 2962.5, 1600, 25),
	Rect2(-2087.5, -2687.5, 1550, 25),
	Rect2(-2062.5, -2712.5, 1525, 25),
	Rect2(-2012.5, -2737.5, 1450, 25),
	Rect2(-1837.5, -3837.5, 475, 75),
	Rect2(-1462.5, -4112.5, 1350, 25),
	Rect2(-1912.5, -2762.5, 1350, 25),
	Rect2(-1462.5, -4137.5, 1300, 25),
	Rect2(-1312.5, -3637.5, 650, 50),
	Rect2(-1837.5, -2987.5, 1275, 25),
	Rect2(-1287.5, -3687.5, 625, 50),
	Rect2(-1812.5, -2962.5, 1250, 25),
	Rect2(-1812.5, -2937.5, 1225, 25),
	Rect2(-1812.5, -2787.5, 1225, 25),
	Rect2(-1262.5, -3737.5, 600, 50),
	Rect2(-1787.5, -2912.5, 1200, 25),
	Rect2(-1762.5, -2887.5, 1175, 25),
	Rect2(-1737.5, -2862.5, 1150, 25),
	Rect2(-1712.5, -2837.5, 1125, 25),
	Rect2(-1412.5, 2987.5, 1125, 25),
	Rect2(-1687.5, -2812.5, 1100, 25),
	Rect2(-1412.5, 3012.5, 1100, 25),
	Rect2(-1387.5, 3037.5, 1100, 25),
	Rect2(-1362.5, 3062.5, 1100, 25),
	Rect2(-1337.5, 3087.5, 1075, 25),
	Rect2(-1862.5, -3712.5, 525, 50),
	Rect2(-1287.5, 3112.5, 1025, 25),
	Rect2(-1862.5, -3762.5, 500, 50),
	Rect2(-1412.5, -4012.5, 950, 25),
	Rect2(-1412.5, -3987.5, 900, 25),
	Rect2(-662.5, 3262.5, 400, 50),
	Rect2(-3312.5, -762.5, 725, 25),
	Rect2(-1387.5, -3962.5, 700, 25),
	Rect2(-787.5, -4162.5, 600, 25),
	Rect2(37.5, -4112.5, 600, 25),
	Rect2(-1387.5, -3937.5, 600, 25),
	Rect2(-1312.5, -3862.5, 575, 25),
	Rect2(-1237.5, -3762.5, 575, 25),
	Rect2(-1337.5, -3887.5, 550, 25),
	Rect2(-1237.5, -3787.5, 550, 25),
	Rect2(87.5, -4137.5, 525, 25),
	Rect2(-1362.5, -3912.5, 525, 25),
	Rect2(-1212.5, -3812.5, 525, 25),
	Rect2(-1212.5, -3837.5, 500, 25),
	Rect2(-1462.5, -4162.5, 475, 25),
	Rect2(-1262.5, 3137.5, 475, 25),
	Rect2(-1462.5, -4187.5, 450, 25),
	Rect2(112.5, -4162.5, 450, 25),
	Rect2(-3262.5, -787.5, 450, 25),
	Rect2(-1812.5, -3862.5, 425, 25),
	Rect2(-1862.5, 2987.5, 425, 25),
	Rect2(-1462.5, -4212.5, 400, 25),
	Rect2(137.5, -4187.5, 375, 25),
	Rect2(-137.5, -4012.5, 375, 25),
	Rect2(-1787.5, -3887.5, 375, 25),
	Rect2(-1812.5, 3012.5, 375, 25),
	Rect2(-1237.5, 3162.5, 375, 25),
	Rect2(-2962.5, -2612.5, 350, 25),
	Rect2(-3037.5, 2812.5, 350, 25),
	Rect2(-637.5, 3312.5, 350, 25),
	Rect2(-1462.5, -4237.5, 325, 25),
	Rect2(162.5, -4212.5, 325, 25),
	Rect2(-1762.5, -3912.5, 325, 25),
	Rect2(-1787.5, 3037.5, 325, 25),
	Rect2(-612.5, 3337.5, 325, 25),
	Rect2(-737.5, -4187.5, 300, 25),
	Rect2(-1212.5, 3187.5, 300, 25),
	Rect2(-1462.5, -4262.5, 275, 25),
	Rect2(-1737.5, -3937.5, 275, 25),
	Rect2(-2962.5, -2637.5, 275, 25),
	Rect2(-1762.5, 3062.5, 275, 25),
	Rect2(-587.5, 3362.5, 275, 25),
	Rect2(-1737.5, 3087.5, 250, 25),
	Rect2(-3012.5, 2837.5, 225, 25),
	Rect2(-1712.5, 3112.5, 200, 25),
	Rect2(262.5, -4237.5, 175, 25),
	Rect2(-2912.5, -2662.5, 175, 25),
	Rect2(-1162.5, 3212.5, 175, 25),
	Rect2(-537.5, 3387.5, 175, 25),
	Rect2(-1687.5, 3137.5, 150, 25),
	Rect2(-362.5, -4187.5, 125, 25),
	Rect2(-1637.5, -3962.5, 125, 25),
	Rect2(-2987.5, 2862.5, 125, 25),
	Rect2(-712.5, -4212.5, 100, 25),
	Rect2(-3212.5, -812.5, 100, 25),
	Rect2(-1662.5, 3162.5, 100, 25),
	Rect2(-537.5, 1587.5, 75, 25),
	Rect2(337.5, -4262.5, 50, 25),
	Rect2(-2962.5, 2887.5, 50, 25),
	Rect2(-1087.5, 3237.5, 50, 25),
	Rect2(787.5, -4037.5, 550, 175),
	Rect2(812.5, -3862.5, 525, 50),
	Rect2(812.5, -4062.5, 525, 25),
	Rect2(837.5, -3812.5, 500, 25),
	Rect2(887.5, -3787.5, 450, 25),
	Rect2(937.5, -4087.5, 400, 25),
	Rect2(962.5, -4112.5, 375, 25),
	Rect2(987.5, -4137.5, 325, 25),
	Rect2(937.5, -3762.5, 275, 25),
	Rect2(1062.5, -4162.5, 125, 25),
	Rect2(837.5, -4087.5, 75, 25),
	Rect2(1012.5, -3737.5, 75, 25),
	# Northern Neck
	Rect2(12.5, 3187.5, 567.5, 150),
	Rect2(-1487.5, 3462.5, 1925, 25),
	Rect2(-1487.5, 3487.5, 1675, 25),
	Rect2(-1487.5, 3512.5, 1625, 25),
	Rect2(-1462.5, 3537.5, 1525, 25),
	Rect2(-1462.5, 3562.5, 1450, 25),
	Rect2(-1437.5, 3587.5, 1375, 25),
	Rect2(37.5, 3137.5, 542.5, 50),
	Rect2(-337.5, 3437.5, 850, 25),
	Rect2(-287.5, 3412.5, 825, 25),
	Rect2(-212.5, 3387.5, 775, 25),
	Rect2(-787.5, 3612.5, 700, 25),
	Rect2(-87.5, 3362.5, 667.5, 25),
	Rect2(-12.5, 3337.5, 592.5, 25),
	Rect2(-1487.5, 3437.5, 525, 25),
	Rect2(62.5, 3112.5, 517.5, 25),
	Rect2(112.5, 3087.5, 467.5, 25),
	Rect2(137.5, 3062.5, 442.5, 25),
	Rect2(-1487.5, 3412.5, 425, 25),
	Rect2(-562.5, 3637.5, 400, 25),
	Rect2(-1412.5, 3612.5, 375, 25),
	Rect2(-1462.5, 3387.5, 350, 25),
	Rect2(237.5, 3037.5, 342.5, 25),
	Rect2(-1462.5, 3362.5, 325, 25),
	Rect2(-1462.5, 3337.5, 275, 25),
	Rect2(-787.5, 3437.5, 275, 25),
	Rect2(-1387.5, 3637.5, 275, 25),
	Rect2(-1437.5, 3312.5, 200, 25),
	Rect2(-437.5, 3662.5, 200, 25),
	Rect2(-1412.5, 3287.5, 150, 25),
	Rect2(437.5, 3012.5, 125, 25),
	# Ironreach
	Rect2(1762.5, 1412.5, 1975, 150),
	Rect2(1887.5, 987.5, 1875, 150),
	Rect2(1737.5, 1837.5, 2250, 125),
	Rect2(1762.5, 1962.5, 1500, 175),
	Rect2(1737.5, 2137.5, 1525, 100),
	Rect2(1737.5, 1562.5, 2000, 75),
	Rect2(1762.5, 1337.5, 1950, 75),
	Rect2(1812.5, 787.5, 1925, 75),
	Rect2(1812.5, 712.5, 1900, 75),
	Rect2(1862.5, 887.5, 1875, 75),
	Rect2(1887.5, 1137.5, 1850, 75),
	Rect2(1862.5, 2562.5, 1300, 100),
	Rect2(1862.5, 2737.5, 1250, 100),
	Rect2(1637.5, -387.5, 1425, 75),
	Rect2(1812.5, 2337.5, 1425, 75),
	Rect2(3362.5, 2237.5, 575, 175),
	Rect2(1762.5, 1687.5, 2000, 50),
	Rect2(1762.5, 1637.5, 1975, 50),
	Rect2(1862.5, 2662.5, 1275, 75),
	Rect2(1887.5, 1212.5, 1825, 50),
	Rect2(1912.5, 1262.5, 1800, 50),
	Rect2(3087.5, -87.5, 700, 125),
	Rect2(1762.5, 337.5, 1050, 75),
	Rect2(1812.5, 462.5, 1000, 75),
	Rect2(1837.5, 587.5, 1000, 75),
	Rect2(1762.5, 2237.5, 1500, 50),
	Rect2(1787.5, 2287.5, 1475, 50),
	Rect2(1637.5, -312.5, 1400, 50),
	Rect2(1812.5, 2412.5, 1400, 50),
	Rect2(1737.5, -537.5, 1350, 50),
	Rect2(3312.5, 2012.5, 675, 100),
	Rect2(1837.5, 2487.5, 1350, 50),
	Rect2(1887.5, 2837.5, 1225, 50),
	Rect2(1937.5, 2912.5, 1175, 50),
	Rect2(787.5, 3262.5, 2350, 25),
	Rect2(787.5, 3237.5, 2325, 25),
	Rect2(787.5, 3212.5, 2225, 25),
	Rect2(1737.5, 287.5, 1075, 50),
	Rect2(1737.5, 1812.5, 2125, 25),
	Rect2(787.5, 3187.5, 2125, 25),
	Rect2(1737.5, 1787.5, 2100, 25),
	Rect2(1737.5, 1762.5, 2075, 25),
	Rect2(1787.5, 412.5, 1025, 50),
	Rect2(1737.5, 1737.5, 2050, 25),
	Rect2(1837.5, 537.5, 975, 50),
	Rect2(1837.5, 862.5, 1900, 25),
	Rect2(1862.5, 962.5, 1900, 25),
	Rect2(1862.5, 1312.5, 1850, 25),
	Rect2(3337.5, 2162.5, 600, 75),
	Rect2(1887.5, 112.5, 875, 50),
	Rect2(1912.5, 62.5, 825, 50),
	Rect2(1912.5, 12.5, 800, 50),
	Rect2(1362.5, 3162.5, 1500, 25),
	Rect2(1637.5, -412.5, 1450, 25),
	Rect2(1662.5, -437.5, 1425, 25),
	Rect2(3062.5, 187.5, 475, 75),
	Rect2(1612.5, 3037.5, 1425, 25),
	Rect2(1687.5, -462.5, 1400, 25),
	Rect2(3287.5, 1962.5, 700, 50),
	Rect2(1712.5, -487.5, 1375, 25),
	Rect2(1637.5, -262.5, 1375, 25),
	Rect2(1812.5, 2462.5, 1375, 25),
	Rect2(2937.5, 537.5, 675, 50),
	Rect2(1437.5, 3137.5, 1350, 25),
	Rect2(1762.5, -562.5, 1325, 25),
	Rect2(1637.5, -237.5, 1325, 25),
	Rect2(1837.5, 2537.5, 1325, 25),
	Rect2(1787.5, -587.5, 1300, 25),
	Rect2(1812.5, -612.5, 1275, 25),
	Rect2(1487.5, 3112.5, 1275, 25),
	Rect2(1837.5, -637.5, 1250, 25),
	Rect2(2962.5, 487.5, 625, 50),
	Rect2(3337.5, 2112.5, 625, 50),
	Rect2(1812.5, 3012.5, 1250, 25),
	Rect2(1512.5, 3087.5, 1225, 25),
	Rect2(1637.5, -212.5, 1200, 25),
	Rect2(2962.5, 437.5, 600, 50),
	Rect2(1912.5, 2887.5, 1200, 25),
	Rect2(1637.5, -187.5, 1175, 25),
	Rect2(787.5, 3287.5, 1175, 25),
	Rect2(1912.5, -662.5, 1150, 25),
	Rect2(1612.5, -162.5, 1150, 25),
	Rect2(1537.5, 3062.5, 1150, 25),
	Rect2(1987.5, 2962.5, 1125, 25),
	Rect2(2037.5, 3287.5, 1125, 25),
	Rect2(787.5, 3312.5, 1125, 25),
	Rect2(2987.5, 362.5, 550, 50),
	Rect2(2087.5, 3312.5, 1100, 25),
	Rect2(2137.5, 3337.5, 1075, 25),
	Rect2(1612.5, -137.5, 1050, 25),
	Rect2(1762.5, 262.5, 1050, 25),
	Rect2(3012.5, 312.5, 525, 50),
	Rect2(1812.5, 687.5, 1050, 25),
	Rect2(1837.5, 662.5, 1025, 25),
	Rect2(2062.5, 2987.5, 1025, 25),
	Rect2(1787.5, 237.5, 1000, 25),
	Rect2(3037.5, 262.5, 500, 50),
	Rect2(2212.5, 3362.5, 1000, 25),
	Rect2(1837.5, 212.5, 950, 25),
	Rect2(1862.5, 187.5, 925, 25),
	Rect2(1862.5, 162.5, 900, 25),
	Rect2(1762.5, -112.5, 850, 25),
	Rect2(3087.5, 112.5, 425, 50),
	Rect2(2262.5, 3387.5, 850, 25),
	Rect2(2887.5, 687.5, 825, 25),
	Rect2(1837.5, -87.5, 800, 25),
	Rect2(1862.5, -62.5, 800, 25),
	Rect2(2287.5, -687.5, 775, 25),
	Rect2(1887.5, -37.5, 775, 25),
	Rect2(1912.5, -12.5, 775, 25),
	Rect2(2912.5, 662.5, 775, 25),
	Rect2(2312.5, 3412.5, 775, 25),
	Rect2(2912.5, 637.5, 750, 25),
	Rect2(2937.5, 612.5, 725, 25),
	Rect2(2937.5, 587.5, 700, 25),
	Rect2(3112.5, -112.5, 675, 25),
	Rect2(3087.5, 37.5, 675, 25),
	Rect2(3137.5, -137.5, 650, 25),
	Rect2(3087.5, 62.5, 650, 25),
	Rect2(787.5, 3337.5, 650, 25),
	Rect2(3187.5, -162.5, 600, 25),
	Rect2(3087.5, 87.5, 600, 25),
	Rect2(3312.5, 2562.5, 300, 50),
	Rect2(2962.5, 412.5, 575, 25),
	Rect2(3337.5, 2437.5, 575, 25),
	Rect2(3237.5, -187.5, 550, 25),
	Rect2(3362.5, 2412.5, 550, 25),
	Rect2(787.5, 3162.5, 550, 25),
	Rect2(3262.5, -212.5, 525, 25),
	Rect2(787.5, 3137.5, 525, 25),
	Rect2(787.5, 3362.5, 525, 25),
	Rect2(3287.5, -237.5, 500, 25),
	Rect2(787.5, 3112.5, 500, 25),
	Rect2(787.5, 3387.5, 500, 25),
	Rect2(787.5, 3412.5, 475, 25),
	Rect2(3312.5, -262.5, 450, 25),
	Rect2(3087.5, 162.5, 450, 25),
	Rect2(787.5, 3087.5, 450, 25),
	Rect2(3337.5, 2462.5, 400, 25),
	Rect2(787.5, 3062.5, 400, 25),
	Rect2(2662.5, -712.5, 375, 25),
	Rect2(3362.5, -287.5, 375, 25),
	Rect2(1512.5, 3337.5, 375, 25),
	Rect2(2662.5, -737.5, 350, 25),
	Rect2(3337.5, 2487.5, 350, 25),
	Rect2(3312.5, 2512.5, 350, 25),
	Rect2(862.5, 3437.5, 350, 25),
	Rect2(3312.5, 2537.5, 325, 25),
	Rect2(1587.5, 3362.5, 300, 25),
	Rect2(2687.5, -760, 325, 22.5),
	Rect2(3412.5, -312.5, 275, 25),
	Rect2(3312.5, 2612.5, 275, 25),
	Rect2(3337.5, 2637.5, 225, 25),
	Rect2(1637.5, 3387.5, 225, 25),
	Rect2(912.5, 3462.5, 225, 25),
	Rect2(2787.5, 3062.5, 200, 25),
	Rect2(1662.5, 3412.5, 175, 25),
	Rect2(2462.5, -712.5, 150, 25),
	Rect2(3387.5, 2662.5, 150, 25),
	Rect2(787.5, 3037.5, 125, 25),
	Rect2(2787.5, 3437.5, 125, 25),
	Rect2(3487.5, -337.5, 100, 25),
	Rect2(3812.5, 2462.5, 100, 25),
	Rect2(787.5, 3012.5, 100, 25),
	Rect2(1037.5, 3037.5, 75, 25),
	Rect2(1687.5, 3437.5, 50, 25),
	Rect2(1912.5, -4012.5, 1875, 250),
	Rect2(2062.5, -2737.5, 1225, 225),
	Rect2(2012.5, -1337.5, 1750, 125),
	Rect2(1912.5, -4112.5, 1850, 100),
	Rect2(2112.5, -3187.5, 1700, 100),
	Rect2(2062.5, -2262.5, 1125, 150),
	Rect2(2112.5, -3012.5, 1825, 75),
	Rect2(2012.5, -1212.5, 1775, 75),
	Rect2(2112.5, -2937.5, 1200, 100),
	Rect2(2062.5, -2512.5, 1200, 100),
	Rect2(2287.5, -3737.5, 1500, 75),
	Rect2(2087.5, -2837.5, 1225, 75),
	Rect2(2062.5, -2412.5, 1175, 75),
	Rect2(2037.5, -2337.5, 1175, 75),
	Rect2(2137.5, -3237.5, 1675, 50),
	Rect2(2312.5, -3662.5, 1475, 50),
	Rect2(3062.5, -1612.5, 700, 100),
	Rect2(3062.5, -1512.5, 675, 100),
	Rect2(3212.5, -2087.5, 525, 125),
	Rect2(3387.5, -2762.5, 325, 200),
	Rect2(1987.5, -1087.5, 1100, 50),
	Rect2(2087.5, -2112.5, 1075, 50),
	Rect2(3062.5, -1412.5, 700, 75),
	Rect2(2012.5, -1387.5, 1025, 50),
	Rect2(3087.5, -1687.5, 675, 75),
	Rect2(2112.5, -2037.5, 1000, 50),
	Rect2(3112.5, -1762.5, 650, 75),
	Rect2(3262.5, -2262.5, 475, 100),
	Rect2(3137.5, -1837.5, 625, 75),
	Rect2(2112.5, -3037.5, 1800, 25),
	Rect2(1987.5, -1137.5, 1800, 25),
	Rect2(2112.5, -3062.5, 1775, 25),
	Rect2(1987.5, -1112.5, 1775, 25),
	Rect2(3362.5, -2562.5, 350, 125),
	Rect2(2112.5, -3087.5, 1725, 25),
	Rect2(3237.5, -2162.5, 500, 75),
	Rect2(2312.5, -3762.5, 1475, 25),
	Rect2(2337.5, -3612.5, 1450, 25),
	Rect2(2362.5, -3587.5, 1425, 25),
	Rect2(2062.5, -2762.5, 1250, 25),
	Rect2(3237.5, -3287.5, 575, 50),
	Rect2(3162.5, -1912.5, 575, 50),
	Rect2(3337.5, -2437.5, 375, 75),
	Rect2(3262.5, -3337.5, 550, 50),
	Rect2(3187.5, -1962.5, 550, 50),
	Rect2(1962.5, -1012.5, 1100, 25),
	Rect2(1987.5, -1037.5, 1075, 25),
	Rect2(3287.5, -3387.5, 525, 50),
	Rect2(2162.5, -3262.5, 1050, 25),
	Rect2(3387.5, -2837.5, 350, 75),
	Rect2(2112.5, -2062.5, 1025, 25),
	Rect2(2187.5, -3287.5, 1000, 25),
	Rect2(2012.5, -1412.5, 1000, 25),
	Rect2(2812.5, -3562.5, 975, 25),
	Rect2(2212.5, -3312.5, 975, 25),
	Rect2(2012.5, -1437.5, 975, 25),
	Rect2(2137.5, -1987.5, 950, 25),
	Rect2(2012.5, -1462.5, 950, 25),
	Rect2(2862.5, -3537.5, 925, 25),
	Rect2(2162.5, -1962.5, 925, 25),
	Rect2(2237.5, -3337.5, 900, 25),
	Rect2(3287.5, -2312.5, 450, 50),
	Rect2(2062.5, -1512.5, 900, 25),
	Rect2(2037.5, -1487.5, 900, 25),
	Rect2(2912.5, -3512.5, 875, 25),
	Rect2(2212.5, -1937.5, 875, 25),
	Rect2(2962.5, -3487.5, 825, 25),
	Rect2(2287.5, -3362.5, 825, 25),
	Rect2(2962.5, -4137.5, 775, 25),
	Rect2(3362.5, -2887.5, 375, 50),
	Rect2(2312.5, -987.5, 725, 25),
	Rect2(3112.5, -3462.5, 700, 25),
	Rect2(3187.5, -3437.5, 625, 25),
	Rect2(2437.5, -3387.5, 625, 25),
	Rect2(3112.5, -1087.5, 625, 25),
	Rect2(2462.5, -1912.5, 600, 25),
	Rect2(3162.5, -1862.5, 600, 25),
	Rect2(2412.5, -962.5, 600, 25),
	Rect2(3162.5, -4162.5, 575, 25),
	Rect2(3237.5, -3412.5, 575, 25),
	Rect2(3137.5, -1062.5, 575, 25),
	Rect2(3187.5, -4187.5, 550, 25),
	Rect2(2512.5, -1887.5, 550, 25),
	Rect2(3162.5, -1037.5, 525, 25),
	Rect2(2512.5, -3412.5, 500, 25),
	Rect2(2537.5, -1862.5, 500, 25),
	Rect2(2462.5, -1537.5, 500, 25),
	Rect2(3212.5, -4212.5, 450, 25),
	Rect2(3337.5, -2937.5, 450, 25),
	Rect2(2562.5, -1837.5, 450, 25),
	Rect2(3312.5, -2337.5, 425, 25),
	Rect2(3237.5, -4237.5, 400, 25),
	Rect2(3362.5, -2912.5, 400, 25),
	Rect2(3312.5, -2362.5, 400, 25),
	Rect2(2612.5, -1812.5, 400, 25),
	Rect2(2587.5, -1562.5, 375, 25),
	Rect2(2662.5, -937.5, 350, 25),
	Rect2(2662.5, -1787.5, 325, 25),
	Rect2(2212.5, -4137.5, 300, 25),
	Rect2(3337.5, -4262.5, 275, 25),
	Rect2(1962.5, -987.5, 275, 25),
	Rect2(2037.5, -3762.5, 225, 25),
	Rect2(2712.5, -1762.5, 225, 25),
	Rect2(2662.5, -1587.5, 225, 25),
	Rect2(2287.5, -4162.5, 200, 25),
	Rect2(2462.5, -3562.5, 150, 25),
	Rect2(2712.5, -1612.5, 150, 25),
	Rect2(3362.5, -1012.5, 150, 25),
	Rect2(2612.5, -3437.5, 125, 25),
	Rect2(2337.5, -4187.5, 100, 25),
	Rect2(2662.5, -4137.5, 100, 25),
	Rect2(2812.5, -3437.5, 75, 25),
	Rect2(3612.5, -1012.5, 75, 25),
	Rect2(3512.5, -4287.5, 50, 25),
	Rect2(3012.5, -4162.5, 50, 25),
	Rect2(2237.5, -1537.5, 50, 25),
	Rect2(3187.5, -1012.5, 50, 25),
	Rect2(1962.5, -962.5, 50, 25),
	Rect2(2587.5, -937.5, 50, 25),
	Rect2(3612.5, -712.5, 175, 225),
	Rect2(3637.5, -487.5, 150, 50),
	Rect2(3637.5, -760, 150, 47.5),
	Rect2(3662.5, -437.5, 125, 25),
	# Kelp Isle
	Rect2(4062.5, -787.5, 625, 225),
	Rect2(4087.5, 137.5, 750, 175),
	Rect2(4062.5, -112.5, 825, 150),
	Rect2(4162.5, 862.5, 550, 200),
	Rect2(4262.5, -2037.5, 525, 175),
	Rect2(4237.5, -1612.5, 600, 150),
	Rect2(4212.5, -1462.5, 600, 125),
	Rect2(4062.5, -562.5, 650, 100),
	Rect2(4112.5, -962.5, 625, 100),
	Rect2(4187.5, 762.5, 525, 100),
	Rect2(4262.5, -2137.5, 500, 100),
	Rect2(4187.5, -1337.5, 625, 75),
	Rect2(4162.5, -1212.5, 625, 75),
	Rect2(4237.5, -1737.5, 600, 75),
	Rect2(4162.5, -1137.5, 600, 75),
	Rect2(4162.5, 562.5, 600, 75),
	Rect2(4262.5, -1812.5, 575, 75),
	Rect2(4137.5, -862.5, 575, 75),
	Rect2(4162.5, 637.5, 575, 75),
	Rect2(4062.5, -162.5, 800, 50),
	Rect2(4087.5, 37.5, 800, 50),
	Rect2(4262.5, -2312.5, 525, 75),
	Rect2(4087.5, 87.5, 775, 50),
	Rect2(4287.5, -2387.5, 500, 75),
	Rect2(4262.5, -2237.5, 500, 75),
	Rect2(4062.5, -237.5, 750, 50),
	Rect2(4087.5, -287.5, 700, 50),
	Rect2(4062.5, -462.5, 675, 50),
	Rect2(4162.5, 412.5, 675, 50),
	Rect2(4112.5, -362.5, 650, 50),
	Rect2(4162.5, 462.5, 650, 50),
	Rect2(4237.5, -1662.5, 625, 50),
	Rect2(4137.5, -1062.5, 625, 50),
	Rect2(4112.5, -412.5, 625, 50),
	Rect2(4187.5, -1262.5, 600, 50),
	Rect2(4137.5, -1012.5, 600, 50),
	Rect2(4262.5, -1862.5, 550, 50),
	Rect2(4187.5, 712.5, 550, 50),
	Rect2(4287.5, -2437.5, 525, 50),
	Rect2(4187.5, 1112.5, 525, 50),
	Rect2(4312.5, -2487.5, 500, 50),
	Rect2(4187.5, 1062.5, 500, 50),
	Rect2(4212.5, 1162.5, 500, 50),
	Rect2(4287.5, 1262.5, 400, 50),
	Rect2(4062.5, -187.5, 775, 25),
	Rect2(4112.5, 312.5, 725, 25),
	Rect2(4137.5, 337.5, 700, 25),
	Rect2(4087.5, -312.5, 675, 25),
	Rect2(4162.5, 362.5, 675, 25),
	Rect2(4162.5, 387.5, 650, 25),
	Rect2(4162.5, 512.5, 625, 25),
	Rect2(4187.5, 537.5, 600, 25),
	Rect2(4312.5, -2512.5, 475, 25),
	Rect2(4262.5, -2162.5, 475, 25),
	Rect2(4312.5, -2537.5, 450, 25),
	Rect2(4237.5, 1212.5, 450, 25),
	Rect2(4262.5, 1237.5, 425, 25),
	Rect2(4337.5, -2562.5, 400, 25),
	Rect2(4337.5, -2587.5, 375, 25),
	Rect2(4312.5, 1312.5, 375, 25),
	Rect2(4362.5, -2612.5, 325, 25),
	Rect2(4337.5, 1337.5, 325, 25),
	Rect2(4362.5, 1362.5, 300, 25),
	Rect2(4387.5, -2637.5, 225, 25),
	Rect2(4412.5, 1387.5, 225, 25),
	Rect2(4437.5, 1412.5, 200, 25),
	Rect2(4387.5, -2662.5, 150, 25),
	Rect2(4437.5, -2687.5, 50, 25),
	Rect2(4562.5, 1437.5, 50, 25),
	# Gull Isle
	Rect2(-662.5, 3762.5, 325, 25),
	Rect2(-637.5, 3737.5, 275, 25),
	Rect2(-587.5, 3712.5, 200, 25),
	Rect2(-687.5, 3787.5, 200, 25),
	Rect2(-687.5, 3812.5, 150, 25),
	Rect2(-387.5, 3812.5, 75, 50),
	Rect2(-437.5, 3787.5, 125, 25),
	Rect2(-687.5, 3837.5, 100, 25),
	Rect2(-362.5, 3862.5, 50, 50),
	Rect2(-712.5, 3862.5, 75, 25),
	Rect2(-712.5, 3887.5, 50, 25),
	# Strait islets
	Rect2(437.5, -1937.5, 325, 100),
	Rect2(537.5, -2062.5, 300, 50),
	Rect2(462.5, -1962.5, 350, 25),
	Rect2(512.5, -2012.5, 325, 25),
	Rect2(487.5, -1987.5, 325, 25),
	Rect2(537.5, -2087.5, 275, 25),
	Rect2(462.5, -1837.5, 275, 25),
	Rect2(562.5, -2112.5, 250, 25),
	Rect2(462.5, -1812.5, 250, 25),
	Rect2(562.5, -2137.5, 200, 25),
	Rect2(487.5, -1787.5, 200, 25),
	Rect2(562.5, -1762.5, 75, 25),
	Rect2(862.5, 1437.5, 250, 125),
	Rect2(887.5, 1412.5, 225, 25),
	Rect2(862.5, 1562.5, 225, 25),
	Rect2(912.5, 1387.5, 175, 25),
	Rect2(887.5, 1587.5, 175, 25),
	Rect2(937.5, 1362.5, 125, 25),
	Rect2(937.5, 1612.5, 100, 25),
	# Palm Isles
	Rect2(1312.5, -1562.5, 225, 100),
	Rect2(1337.5, -1587.5, 175, 25),
	Rect2(1337.5, -1462.5, 175, 25),
	Rect2(1362.5, -1437.5, 125, 25),
	Rect2(1387.5, -1612.5, 100, 25),
	Rect2(1237.5, -2437.5, 200, 75),
	Rect2(1237.5, -2512.5, 150, 50),
	Rect2(1237.5, -2462.5, 175, 25),
	Rect2(1262.5, -2362.5, 150, 25),
	Rect2(1262.5, -2537.5, 125, 25),
	Rect2(1287.5, -2562.5, 100, 25),
	Rect2(887.5, -2987.5, 175, 100),
	Rect2(887.5, -2887.5, 150, 25),
	Rect2(912.5, -3012.5, 125, 25),
	Rect2(937.5, -2862.5, 75, 25),
	# Ember Isle
	Rect2(-2712.5, 3862.5, 550, 50),
	Rect2(-2687.5, 3737.5, 450, 50),
	Rect2(-2712.5, 3912.5, 575, 25),
	Rect2(-2687.5, 3937.5, 550, 25),
	Rect2(-2712.5, 3837.5, 525, 25),
	Rect2(-2687.5, 3962.5, 525, 25),
	Rect2(-2712.5, 3812.5, 500, 25),
	Rect2(-2662.5, 3987.5, 500, 25),
	Rect2(-2712.5, 3787.5, 475, 25),
	Rect2(-2637.5, 4012.5, 450, 25),
	Rect2(-2662.5, 3712.5, 400, 25),
	Rect2(-2612.5, 4037.5, 400, 25),
	Rect2(-2587.5, 4062.5, 375, 25),
	Rect2(-2637.5, 3687.5, 350, 25),
	Rect2(-2612.5, 3662.5, 325, 25),
	Rect2(-2587.5, 4087.5, 325, 25),
	Rect2(-2587.5, 3637.5, 275, 25),
	Rect2(-2562.5, 3612.5, 200, 25),
	# Driftwood Isle
	Rect2(-37.5, -3237.5, 325, 50),
	Rect2(-62.5, -3187.5, 325, 25),
	Rect2(-12.5, -3262.5, 275, 25),
	Rect2(12.5, -3287.5, 225, 25),
	Rect2(62.5, -3312.5, 125, 25),
	Rect2(-62.5, -3162.5, 100, 25),
	Rect2(1062.5, -3087.5, 75, 50),
	Rect2(1087.5, -3112.5, 50, 25),
	# Tern Isle
	Rect2(1037.5, 1712.5, 75, 25),
	Rect2(1037.5, 1737.5, 50, 25),
]
## The named landmasses, as [name, first LAND index, end index).
const LANDMASSES = [
	["Hearthland", 0, 248],
	["Northern Neck", 248, 279],
	["Ironreach", 279, 568],
	["Kelp Isle", 568, 637],
	["Gull Isle", 637, 648],
	["Strait islets", 648, 667],
	["Palm Isles", 667, 682],
	["Ember Isle", 682, 700],
	["Driftwood Isle", 700, 708],
	["Tern Isle", 708, 710],
]
## END NATURAL LAND
## Patch 2.5 item 7: the one volcano. Chosen once and fixed here, so it is the
## same every run (and online later): a toon cone on Ember Isle (LAND index
## `land`), `base_m` round at the foot and `peak_m` to the crater.
const VOLCANO = {"id": "ember_isle_volcano", "name": "Ember Isle", "land": 682, "at": Vector2(-2470, 3840), "base_m": 140.0, "peak_m": 170.0}
## Patch 2.1 item 3: snowy ice shelves beside the two polar quays, solid like
## land. Patch 2.5 item 1: each runs on to its quay, so the poles sit on a coast.
const ICE_SHELVES = [Rect2(3050, 3700, 450, 460), Rect2(-2100, -4360, 450, 500), Rect2(3500, 3700, 100, 460), Rect2(-2200, -4360, 100, 500)]
## Patch 2.5 item 1: the narrow ways through the land, like real ones. Each is
## a straight cut from `from` to `to` (X, Z), `width_m` clear water across. The
## sea lanes run down the middle; the narrowest still takes 2.5 beams of the
## biggest ship.
const STRAITS = [
	{"id": "needle_gut", "name": "Needle Gut", "like": "Bosphorus", "from": Vector2(680, 2850), "to": Vector2(680, 3550), "width_m": 200.0},
	{"id": "gannet_narrows", "name": "Gannet Narrows", "like": "Gibraltar", "from": Vector2(1625, -3550), "to": Vector2(1625, -4350), "width_m": 550.0},
	{"id": "kelp_strait", "name": "Kelp Strait", "like": "Malacca", "from": Vector2(3925, -2800), "to": Vector2(3925, 1600), "width_m": 250.0},
	{"id": "ironreach_canal", "name": "Ironreach Canal", "like": "Panama", "from": Vector2(1750, -830), "to": Vector2(3925, -830), "width_m": 140.0},
]
## Patch 2.5 item 2: toon bridges across the straits, crossing each at `at`
## (X, Z). Every tower and pier stands on land, out of the channel, and the
## deck's underside is BRIDGE_CLEARANCE_M above the sea: the tallest ship in any
## family (the Valemax bulker, about 49 m) passes under with room to spare.
const BRIDGES = [
	{"id": "gannet_narrows_bridge", "name": "Gannet Narrows Bridge", "strait": "gannet_narrows", "style": "suspension", "at": Vector2(1620, -3950)},
	{"id": "needle_gut_bridge", "name": "Needle Gut Bridge", "strait": "needle_gut", "style": "arch", "at": Vector2(680, 3270)},
	{"id": "kelp_strait_bridge", "name": "Kelp Strait Bridge", "strait": "kelp_strait", "style": "cable_stayed", "at": Vector2(3920, -100)},
	{"id": "ironreach_canal_bridge", "name": "Ironreach Canal Bridge", "strait": "ironreach_canal", "style": "truss", "at": Vector2(2870, -830)},
]
const BRIDGE_CLEARANCE_M: float = 70.0

## A bridge's strait entry.
static func bridge_strait(index: int) -> Dictionary:
	for strait: Dictionary in STRAITS:
		if strait.id == BRIDGES[index].strait: return strait
	return {}

## Patch 2.5 item 1: sea-lane points (X, Z). Navigation finds the shortest way
## between them that keeps LANE_MARGIN_M off all land, ice, icebergs and quays.
## The first eight are the straits' mouths; the rest mark the open sea.
const SEA_LANES: Array[Vector2] = [
	Vector2(680, 2850), Vector2(680, 3550), Vector2(1625, -3550), Vector2(1625, -4350),
	Vector2(1750, -830), Vector2(3925, -830), Vector2(3925, -2800), Vector2(3925, 1600),
	Vector2(5500, -830), Vector2(5500, 3000), Vector2(5500, -3500), Vector2(-2600, -4800),
	Vector2(-4200, -2000), Vector2(-4200, 1500), Vector2(-2500, 3550), Vector2(250, 3550),
	Vector2(2400, 3550), Vector2(250, -4500), Vector2(3000, -4500), Vector2(1000, 4300),
	Vector2(500, 900), Vector2(500, -900), Vector2(450, 2400),
]
const LANE_MARGIN_M: float = 60.0
## Ships leave and reach every port through its gate, this far south of it.
const GATE_M: float = 450.0
## Patch 2.1 item 3: icebergs in the polar seas, solid like land. Vector3(x,
## radius, z) in metres. They keep clear of the polar quays, their approaches
## and their heavy-load drop areas.
const ICEBERGS = [
	Vector3(3000, 45, 4750), Vector3(4300, 60, 4800), Vector3(5200, 50, 4300), Vector3(2200, 70, 5000),
	Vector3(3500, 55, 5400), Vector3(5000, 65, 5600), Vector3(1200, 50, 5500), Vector3(2700, 40, 5900),
	Vector3(-300, 60, 5200), Vector3(6200, 45, 5000),
	Vector3(-1500, 55, -4750), Vector3(-3800, 60, -4400), Vector3(-2000, 50, -6000), Vector3(-700, 70, -5100),
	Vector3(-4400, 45, -5600), Vector3(200, 50, -4600), Vector3(-3300, 60, -6100), Vector3(1400, 55, -5600),
	Vector3(-5200, 50, -4700), Vector3(2600, 45, -5000),
]
## Patch 2.1 item 3: the world repeats every WRAP_M metres east-west and
## north-south, so a ship that sails off one edge carries on from the opposite
## one. 4000 pi metres is a whole number of every swell and tone wave in the
## ocean shader, so the water looks the same on both sides of the edge. The
## land sits in the middle with at least 2.5 km of open sea to every edge.
const WRAP_M: float = 4000.0 * PI
const WRAP_CENTRE: Vector3 = Vector3(750, 0, -100)
## Patch 2.2 item 1: container ships 1-5 (REBUILD_PLAN.md section 7). Ship 1
## keeps the save ID "container"; ships 2-5 name their own records. Bigger is
## faster but heavier: slower to speed up, stop and turn.
const SHIPS = {
	"container": {"name": "Container ship", "price_minor": 80000},
	"container_2": {"name": "Coastal feeder", "price_minor": 1200000, "record": "res://features/catalog/records/container_02_ship.tres"},
	"container_3": {"name": "Panamax box ship", "price_minor": 4500000, "record": "res://features/catalog/records/container_03_ship.tres"},
	"container_4": {"name": "Neo-Panamax box ship", "price_minor": 12000000, "record": "res://features/catalog/records/container_04_ship.tres"},
	"container_5": {"name": "Ultra-large box ship", "price_minor": 30000000, "record": "res://features/catalog/records/container_05_ship.tres"},
	"bulk": {"name": "Handysize bulker", "price_minor": 120000, "record": "res://features/catalog/records/bulk_01_ship.tres"},
	"bulk_2": {"name": "Supramax bulker", "price_minor": 1800000, "record": "res://features/catalog/records/bulk_02_ship.tres"},
	"bulk_3": {"name": "Panamax bulker", "price_minor": 6750000, "record": "res://features/catalog/records/bulk_03_ship.tres"},
	"bulk_4": {"name": "Capesize bulker", "price_minor": 18000000, "record": "res://features/catalog/records/bulk_04_ship.tres"},
	"bulk_5": {"name": "Valemax ore carrier", "price_minor": 45000000, "record": "res://features/catalog/records/bulk_05_ship.tres"},
	"heavy": {"name": "Heavy lifter", "price_minor": 300000},
	"heavy_2": {"name": "Twin-crane project ship", "price_minor": 4500000, "record": "res://features/catalog/records/heavy_02_ship.tres"},
	"heavy_3": {"name": "Twin-crane heavy lifter", "price_minor": 15000000, "record": "res://features/catalog/records/heavy_03_ship.tres"},
	"heavy_4": {"name": "Semi-submersible heavy ship", "price_minor": 40000000, "record": "res://features/catalog/records/heavy_04_ship.tres"},
	"heavy_5": {"name": "Giant semi-submersible", "price_minor": 90000000, "record": "res://features/catalog/records/heavy_05_ship.tres"},
	# Patch 2.4 item 8: the small boats. Cheap, just for fun, no cargo jobs.
	"small_fishing": {"name": "Fishing boat", "price_minor": 20000, "record": "res://features/catalog/records/small_fishing_ship.tres"},
	"small_speedboat": {"name": "Speedboat", "price_minor": 40000, "record": "res://features/catalog/records/small_speedboat_ship.tres"},
	"small_racer": {"name": "Offshore racer", "price_minor": 60000, "record": "res://features/catalog/records/small_racer_ship.tres"},
	# Patch 2.9.1 item 1: the pirate galleon. A prestige buy in the same "small"
	# (Other boats) family: no cargo jobs, just for sailing.
	"small_galleon": {"name": "Pirate galleon", "price_minor": 20000000, "record": "res://features/catalog/records/pirate_galleon_ship.tres"},
}
## The container ladder, smallest first. Tier 1 is "container".
const CONTAINER_KINDS: Array[String] = ["container", "container_2", "container_3", "container_4", "container_5"]
## Pay per container grows a little with the tier (percent), so each step up
## earns more per trip than the containers alone.
const CONTAINER_PAY_PERCENT: Array[int] = [100, 110, 120, 130, 140]
## Patch 2.2 item 2: the bulk ladder, smallest first. Tier 1 keeps the save ID
## "bulk" (the old prototype). Tonnage comes from each record's dwt_tonnes.
const BULK_KINDS: Array[String] = ["bulk", "bulk_2", "bulk_3", "bulk_4", "bulk_5"]
const BULK_PAY_PERCENT: Array[int] = [100, 110, 120, 130, 140]
## Patch 2.2 item 3: the heavy-lift ladder, smallest first. Tier 1 keeps the
## save ID "heavy" and the current heavy lifter's record. Every heavy kind sails
## in heavy mode (lifting deck, one ocean load at a time).
const HEAVY_KINDS: Array[String] = ["heavy", "heavy_2", "heavy_3", "heavy_4", "heavy_5"]
## Patch 2.4 item 8: the small boats family, cheapest first. They carry no
## cargo and take no jobs; the planing ones jump the waves (ShipVisualMotion).
## Patch 2.9.1: the family is shown as "Other boats" and also holds the pirate
## ships (PIRATE_KINDS); the family ID stays "small" so saves are unchanged.
const SMALL_KINDS: Array[String] = ["small_fishing", "small_speedboat", "small_racer", "small_galleon"]
const PIRATE_KINDS: Array[String] = ["small_galleon"]
## Ship record IDs and the ladder kind each one is saved as. The old container
## variants all had the starter's 24-slot hull: the starter and the slower
## harbor ship are ship 1; the coastal and the faster swift ship are ship 2,
## the coastal feeder. A save naming one of them keeps the ship.
const LADDER_IDS = {
	"ship_starter_container_01": "container", "ship_harbor_container_01": "container",
	"ship_coastal_container_01": "container_2", "ship_swift_container_01": "container_2",
	"ship_container_feeder_02": "container_2", "ship_container_panamax_03": "container_3",
	"ship_container_neopanamax_04": "container_4", "ship_container_ultra_05": "container_5",
	"ship_heavy_lifter_01": "heavy", "ship_heavy_project_02": "heavy_2", "ship_heavy_twin_crane_03": "heavy_3",
	"ship_heavy_semisub_04": "heavy_4", "ship_heavy_semisub_05": "heavy_5",
	"ship_bulk_prototype_01": "bulk", "ship_bulk_handysize_01": "bulk",
	"ship_bulk_supramax_02": "bulk_2", "ship_bulk_panamax_03": "bulk_3",
	"ship_bulk_capesize_04": "bulk_4", "ship_bulk_valemax_05": "bulk_5",
	"ship_small_fishing_01": "small_fishing", "ship_small_speedboat_02": "small_speedboat", "ship_small_racer_03": "small_racer",
	"ship_pirate_galleon_01": "small_galleon",
}
## A sold ship pays back half its price.
const RESALE_PERCENT: int = 50
## Bulk cargo: name, label, pay per 100 m sailed and tonnes for ship 1. Every
## port always has one job of each cargo per bulk tier, one for each other port.
## A delivered job is on offer again at once. Bigger tiers carry tonnage in
## step with their deadweight and earn a little more per tonne.
const BULK_CARGO = [["grain", "Grain", 6000, 4000], ["coal", "Coal", 8000, 5000], ["ore", "Iron ore", 10000, 6000]]
## Pay of the six M3 bulk jobs, to read a version 4 save that lists delivered ones.
const BULK_V4 = {"bulk_0_grain": 90000, "bulk_0_coal": 120000, "bulk_0_ore": 150000, "bulk_1_grain": 90000, "bulk_1_coal": 120000, "bulk_1_ore": 150000}

## The same step taken the short way round the world.
static func short_way(step: Vector3) -> Vector3:
	return Vector3(wrapf(step.x, -WRAP_M / 2, WRAP_M / 2), step.y, wrapf(step.z, -WRAP_M / 2, WRAP_M / 2))

## A position brought back inside the world's edges.
static func wrapped(at: Vector3) -> Vector3:
	return WRAP_CENTRE + short_way(at - WRAP_CENTRE)

## The copy of `point` that is closest to `from`, which may be across an edge.
static func nearest(point: Vector3, from: Vector3) -> Vector3:
	return from + short_way(point - from)

static func port_index(id: Variant) -> int:
	for index: int in WORLD.size():
		if WORLD[index].id == id: return index
	return -1

## The other ports, in world order.
static func others(origin: int) -> Array[int]:
	var result: Array[int] = []
	for index: int in WORLD.size():
		if index != origin: result.append(index)
	return result

## Where a port stands on the chart that pay and saved jobs are worked out on:
## its spot before Patch 2.9 item 6B moved it ("was"), or where it is now.
static func chart_at(index: int) -> Vector3:
	return WORLD[index].get("was", WORLD[index].at)

## Length of a leg in units of 100 m, the short way round the world. Pay grows
## with it. It is measured on the chart (chart_at), so pay and saved jobs did
## not change when item 6B moved the ports. The leg between the poles goes over
## the edge.
static func leg_units(a: int, b: int) -> int:
	var from: Vector3 = chart_at(a)
	var to: Vector3 = chart_at(b)
	return roundi(short_way(to - from).length() / 100.0)

## 1 to 5 for a bulk ship, 0 for any other kind.
static func bulk_tier(kind: String) -> int:
	return BULK_KINDS.find(kind) + 1

## 1 to 5 for a heavy-lift ship, 0 for any other kind.
static func heavy_tier(kind: String) -> int:
	return HEAVY_KINDS.find(kind) + 1

## 1 to 3 for a small boat, 0 for any other kind.
static func small_tier(kind: String) -> int:
	return SMALL_KINDS.find(kind) + 1

## Deadweight tonnes a bulk tier carries, from its record.
static func bulk_capacity(tier: int) -> int:
	return definition(BULK_KINDS[tier - 1]).dwt_tonnes

## "12,500" for 12500.
static func thousands(value: int) -> String:
	var text: String = str(value)
	for at: int in range(text.length() - 3, 0, -3): text = text.insert(at, ",")
	return text

## A bulk job from its ID: "bulk_<origin port>_<cargo>" for ship 1 (the M3 IDs)
## or "bulk_t<tier>_<origin port>_<cargo>" for ships 2-5. Empty if there is none.
static func bulk_job(id: String) -> Dictionary:
	var parts: PackedStringArray = id.split("_")
	var tier: int = 1
	if parts.size() == 4 and parts[0] == "bulk" and parts[1].length() == 2 and parts[1][0] == "t" and parts[1][1] in "2345":
		tier = int(parts[1][1])
		parts.remove_at(1)
	if parts.size() != 3 or parts[0] != "bulk" or not parts[1].is_valid_int(): return {}
	var origin: int = int(parts[1])
	if origin < 0 or origin >= WORLD.size() or parts[1] != str(origin): return {}
	for index: int in BULK_CARGO.size():
		if BULK_CARGO[index][0] != parts[2]: continue
		var destination: int = others(origin)[index]
		var base: int = int(BULK_CARGO[index][3])
		var tonnes: int = base if tier == 1 else roundi(float(base) * bulk_capacity(tier) / bulk_capacity(1) / 100.0) * 100
		var pay: int = int(BULK_CARGO[index][2]) * leg_units(origin, destination) * tonnes / base * BULK_PAY_PERCENT[tier - 1] / 100
		return {"title": "%s, %s t" % [BULK_CARGO[index][1], thousands(tonnes)], "origin": origin, "destination": destination, "reward_minor": pay, "tier": tier, "tonnes": tonnes}
	return {}

static func bulk_ids(origin: int, tier: int = 1) -> Array[String]:
	var result: Array[String] = []
	for cargo: Array in BULK_CARGO: result.append(("bulk_%d_%s" % [origin, cargo[0]]) if tier == 1 else ("bulk_t%d_%d_%s" % [tier, origin, cargo[0]]))
	return result

## The ship record a kind sails with.
static func definition(kind: String) -> ShipDefinition:
	if kind == "heavy": return load("res://features/catalog/records/heavy_lifter.tres") as ShipDefinition
	return load(str(SHIPS.get(kind, {}).get("record", "res://features/catalog/records/starter_ship.tres"))) as ShipDefinition

## 1 to 5 for a container ship, 0 for any other kind.
static func container_tier(kind: String) -> int:
	return CONTAINER_KINDS.find(kind) + 1

## Containers a tier carries, from its record.
static func container_capacity(tier: int) -> int:
	return int(definition(CONTAINER_KINDS[tier - 1]).cargo_capacities.get("container_slots", 0))

## A saved ship ID as a ladder kind. Kinds pass through; unknown IDs too, so
## save_valid still rejects them.
static func ladder_kind(id: String) -> String:
	return id if SHIPS.has(id) else str(LADDER_IDS.get(id, id))

## Patch 2.2: a version 4/5 save that names ships by record ID reads them as
## ladder kinds. Two IDs on one kind keep the first. Call before save_valid.
static func migrate(d: Dictionary) -> void:
	if d.get("ship") is String: d.ship = ladder_kind(d.ship)
	if not d.get("fleet") is Dictionary: return
	var fleet: Dictionary = {}
	for kind: Variant in d.fleet:
		var mapped: Variant = ladder_kind(kind) if kind is String else kind
		if not fleet.has(mapped): fleet[mapped] = d.fleet[kind]
	d.fleet = fleet

static func resale_minor(kind: String) -> int:
	return int(SHIPS[kind].price_minor) * RESALE_PERCENT / 100

static func fraction(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(value) and value >= 0 and value <= 1

## The game's save fields. Version 4 (M3): spent, ship, fleet, bulk. Version 5
## (M4) adds banked: pay from bulk and heavy jobs, which can be taken again.
static func save_valid(d: Dictionary) -> bool:
	var current: bool = d.get("version") == 5
	if not d.get("spent") is int or d.spent < 0: return false
	if current and (not d.get("banked") is int or d.banked < 0): return false
	if not d.get("ship") is String or not SHIPS.has(d.ship) or d.get("heavy_mode") != (heavy_tier(d.ship) > 0): return false
	if not d.get("fleet") is Dictionary or not d.fleet.has(d.ship): return false
	for kind: Variant in d.fleet:
		if not kind is String or not SHIPS.has(kind): return false
		var stored: Variant = d.fleet[kind]
		if not stored is Dictionary or stored.size() != 2 or not fraction(stored.get("fuel")) or not fraction(stored.get("condition")): return false
	var bulk: Variant = d.get("bulk")
	if not bulk is Dictionary or bulk.size() != 2 or not bulk.get("active") is String or not bulk.get("done") is Array: return false
	if bulk.done.size() > (0 if current else BULK_V4.size()): return false
	var seen: Dictionary = {}
	for id: Variant in bulk.done:
		if not id is String or not BULK_V4.has(id) or seen.has(id): return false
		seen[id] = true
	if not bulk.active.is_empty() and (bulk_tier(d.ship) < int(bulk_job(bulk.active).get("tier", 9)) or seen.has(bulk.active)): return false
	return true

## Pay from bulk and heavy jobs that are not listed one by one in the save.
## Call only after save_valid.
static func earned(d: Dictionary) -> int:
	var total: int = int(d.get("banked", 0))
	for id: String in d.bulk.done: total += int(BULK_V4[id])
	return total

## Patch 2.9 item 6A: the baked coast depth grid (natural_land.json): metres
## from each 25 m sample to the coast, + inland and - at sea. Loaded once.
const NATURAL_LAND_PATH: String = "res://features/world/natural_land.json"
static var _natural: Dictionary = {}

static func natural_land() -> Dictionary:
	if not _natural.is_empty(): return _natural
	var text: String = FileAccess.get_file_as_string(NATURAL_LAND_PATH)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary: return {}
	var raw: PackedByteArray = Marshalls.base64_to_raw(data.depth)
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(raw.size())
	var step: float = float(data.depth_step_m)
	var zero: int = int(data.depth_zero)
	for index: int in raw.size(): depth[index] = float(raw[index] - zero) * step
	var outlines: Array = []
	for entry: Dictionary in data.outlines:
		var ring: PackedVector2Array = PackedVector2Array()
		for point: Array in entry.outline: ring.append(Vector2(point[0], point[1]))
		outlines.append({"name": entry.name, "outline": ring})
	_natural = {"seed": int(data.seed), "cell": float(data.cell_m), "origin": Vector2(data.origin[0], data.origin[1]),
		"count": Vector2i(int(data.count[0]), int(data.count[1])), "depth": depth, "outlines": outlines}
	return _natural

## Metres inland from the coast at `at` (X, Z): + on land, - at sea, from the
## natural land grid. Off the grid is deep sea.
static func land_depth(at: Vector2) -> float:
	var grid: Dictionary = natural_land()
	if grid.is_empty(): return -300.0
	var cell: Vector2 = (at - grid.origin) / grid.cell
	var count: Vector2i = grid.count
	if cell.x < 0.0 or cell.y < 0.0 or cell.x > count.x - 1.001 or cell.y > count.y - 1.001: return -300.0
	var i: int = int(cell.x)
	var j: int = int(cell.y)
	var fx: float = cell.x - i
	var fz: float = cell.y - j
	var depth: PackedFloat32Array = grid.depth
	var a: float = lerpf(depth[j * count.x + i], depth[j * count.x + i + 1], fx)
	var b: float = lerpf(depth[(j + 1) * count.x + i], depth[(j + 1) * count.x + i + 1], fx)
	return lerpf(a, b, fz)

## Spots on a `spacing` lattice over the land that are at least `inland` metres
## from the coast, jittered by `rng` up to `jitter` metres. Dressing uses it.
static func inland_spots(spacing: float, inland: float, rng: RandomNumberGenerator, jitter: float) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var grid: Dictionary = natural_land()
	if grid.is_empty(): return spots
	var size: Vector2 = Vector2(grid.count) * float(grid.cell)
	for gx: int in int(size.x / spacing):
		for gz: int in int(size.y / spacing):
			var at: Vector2 = grid.origin + Vector2(gx + 0.5, gz + 0.5) * spacing + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
			if land_depth(at) >= inland: spots.append(at)
	return spots

## Points `inland` metres in from the coast all round the land, about
## `spacing` apart: where a row of beach palms goes.
static func coast_ring(inland: float, spacing: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var grid: Dictionary = natural_land()
	if grid.is_empty(): return points
	var count: Vector2i = grid.count
	var depth: PackedFloat32Array = grid.depth
	var taken: Dictionary = {}
	for j: int in count.y - 1:
		for i: int in count.x - 1:
			var v: Array[float] = [depth[j * count.x + i], depth[j * count.x + i + 1], depth[(j + 1) * count.x + i + 1], depth[(j + 1) * count.x + i]]
			var corners: Array[Vector2] = [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			for edge: int in 4:
				var va: float = v[edge] - inland
				var vb: float = v[(edge + 1) % 4] - inland
				if (va > 0.0) == (vb > 0.0) or edge > 1: continue
				var at: Vector2 = grid.origin + corners[edge].lerp(corners[(edge + 1) % 4], va / (va - vb)) * float(grid.cell)
				var key: Vector2i = Vector2i(floori(at.x / spacing), floori(at.y / spacing))
				if taken.has(key): continue
				taken[key] = true
				points.append(at)
	return points

## Patch 2.5 item 1: sea navigation round the land. Read-only helpers for the
## minimap's course and the checks; no ship is steered by them.
static var _obstacles: Array[Rect2] = []
static var _links: Array = []
static var _route_key: Array = []
static var _route: Array[Vector3] = []

## A port's quay and berths, kept clear by the sea lanes like land.
static func harbour(index: int) -> Rect2:
	var at: Vector3 = WORLD[index].at
	var quay_side: float = -float(WORLD[index].drop_side)
	return Rect2(minf(at.x - quay_side * 25, at.x + quay_side * 110), at.z - 60, 135, 1000)

## Where ships leave and reach a port: open water straight astern of its berths.
static func gate(index: int) -> Vector3:
	return WORLD[index].at + Vector3(0, 0, -GATE_M)

## Land, ice shelves, icebergs (as squares) and quays: everything a lane avoids.
static func obstacles() -> Array[Rect2]:
	if _obstacles.is_empty():
		for block: Rect2 in LAND + ICE_SHELVES: _obstacles.append(block)
		for index: int in WORLD.size(): _obstacles.append(harbour(index))
		for berg: Vector3 in ICEBERGS: _obstacles.append(Rect2(berg.x - berg.y, berg.z - berg.y, berg.y * 2, berg.y * 2))
	return _obstacles

## Patch 2.9 item 6B: true when a hull of `hull` metres at `pose` floats clear of
## land, ice shelves and icebergs. A save made before the ports moved can hold a
## pose where land now stands; such a ship starts at its port instead.
static func afloat(pose: Transform3D, hull: Vector3) -> bool:
	var at: Vector3 = wrapped(pose.origin)
	var reach: Vector3 = (pose.basis.x.abs() * hull.x + pose.basis.z.abs() * hull.z) * 0.5
	var footprint: Rect2 = Rect2(at.x - reach.x, at.z - reach.z, reach.x * 2, reach.z * 2)
	for block: Rect2 in LAND + ICE_SHELVES:
		if block.intersects(footprint): return false
	for berg: Vector3 in ICEBERGS:
		if Rect2(berg.x - berg.y, berg.z - berg.y, berg.y * 2, berg.y * 2).intersects(footprint): return false
	return true

## True when the straight run from `a` to `b`, the short way round the world,
## stays `margin` metres off every obstacle. An obstacle whose margin already
## holds an end (a ship near a coast or in a harbour) only has to be missed
## itself, and a harbour that holds an end is left out.
static func clear_line(a: Vector2, b: Vector2, margin: float = LANE_MARGIN_M) -> bool:
	var step: Vector3 = short_way(Vector3(b.x - a.x, 0, b.y - a.y))
	var to: Vector2 = a + Vector2(step.x, step.z)
	var span: Rect2 = Rect2(a, Vector2.ZERO).expand(to).grow(margin + 1.0)
	var middle: Vector2 = span.get_center()
	var blocks: Array[Rect2] = obstacles()
	# Patch 2.9 item 6A: the natural land is hundreds of blocks, so each is
	# tried only as its copy nearest the line (no block is half a world wide).
	for index: int in blocks.size():
		var block: Rect2 = blocks[index]
		var off: Vector2 = block.get_center() - middle
		block.position -= Vector2(roundf(off.x / WRAP_M), roundf(off.y / WRAP_M)) * WRAP_M
		if not block.intersects(span): continue
		var grown: Rect2 = block.grow(margin)
		if grown.has_point(a) or grown.has_point(to):
			if block.has_point(a) or block.has_point(to): continue
			grown = block
		if _segment_hits(a, to, grown): return false
	return true

## Liang-Barsky: does the segment a-b touch the rectangle?
static func _segment_hits(a: Vector2, b: Vector2, box: Rect2) -> bool:
	var low: float = 0.0
	var high: float = 1.0
	var d: Vector2 = b - a
	for pair: Vector2 in [Vector2(-d.x, a.x - box.position.x), Vector2(d.x, box.end.x - a.x), Vector2(-d.y, a.y - box.position.y), Vector2(d.y, box.end.y - a.y)]:
		if is_zero_approx(pair.x):
			if pair.y < 0: return false
			continue
		var t: float = pair.y / pair.x
		if pair.x < 0: low = maxf(low, t)
		else: high = minf(high, t)
		if low > high: return false
	return true

static func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)

static func _apart(a: Vector2, b: Vector2) -> float:
	var step: Vector3 = short_way(Vector3(b.x - a.x, 0, b.y - a.y))
	return Vector2(step.x, step.z).length()

## The shortest way by sea from `from` to `to` through the lane points: the
## turning points after `from`, ending with `to`. Empty when there is none.
static func sea_route(from: Vector3, to: Vector3) -> Array[Vector3]:
	if _links.is_empty():
		for i: int in SEA_LANES.size():
			var row: PackedFloat32Array = PackedFloat32Array()
			for j: int in SEA_LANES.size():
				row.append(_apart(SEA_LANES[i], SEA_LANES[j]) if i != j and clear_line(SEA_LANES[i], SEA_LANES[j]) else INF)
			_links.append(row)
	var start: Vector2 = _flat(from)
	var goal: Vector2 = _flat(to)
	if clear_line(start, goal): return [to]
	var count: int = SEA_LANES.size()
	var to_goal: PackedFloat32Array = PackedFloat32Array()
	var best: PackedFloat32Array = PackedFloat32Array()
	var before: PackedInt32Array = PackedInt32Array()
	var done: PackedByteArray = PackedByteArray()
	for i: int in count:
		to_goal.append(_apart(SEA_LANES[i], goal) if clear_line(SEA_LANES[i], goal) else INF)
		best.append(_apart(start, SEA_LANES[i]) if clear_line(start, SEA_LANES[i]) else INF)
		before.append(-1)
		done.append(0)
	var finish: float = INF
	var last: int = -1
	while true:
		var next: int = -1
		for i: int in count:
			if done[i] == 0 and best[i] < INF and (next < 0 or best[i] < best[next]): next = i
		if next < 0 or best[next] >= finish: break
		done[next] = 1
		if best[next] + to_goal[next] < finish:
			finish = best[next] + to_goal[next]
			last = next
		for j: int in count:
			if done[j] == 0 and best[next] + _links[next][j] < best[j]:
				best[j] = best[next] + _links[next][j]
				before[j] = next
	var route: Array[Vector3] = []
	if last < 0: return route
	route.append(to)
	while last >= 0:
		route.push_front(Vector3(SEA_LANES[last].x, 0, SEA_LANES[last].y))
		last = before[last]
	return route

## The way by sea to a port's berth (`index` >= 0: through its gate, unless the
## ship is already in the port's own approach) or to an open-water point
## (`index` -1). Kept until the ship or the target moves 50 m.
static func course(from: Vector3, to: Vector3, index: int = -1) -> Array[Vector3]:
	var key: Array = [Vector2i(roundi(from.x / 50.0), roundi(from.z / 50.0)), Vector2i(roundi(to.x / 50.0), roundi(to.z / 50.0)), index]
	if key == _route_key: return _route
	var route: Array[Vector3] = []
	var local: Vector3 = short_way(from - WORLD[index].at) if index >= 0 else Vector3.ZERO
	if index < 0: route = sea_route(from, to)
	elif absf(local.x) < 400 and local.z > -GATE_M - 150 and local.z < 1000: route = [to]
	else:
		route = sea_route(from, gate(index))
		if not route.is_empty(): route.append(to)
	_route_key = key
	_route = route
	return route
