"""Step 88: the planned lanes, hull speeds and time scale agree, and stay agreeing."""
import copy
import unittest
import traversal_budget as budget

# Route lengths in metres worked by hand for WORLD_LAYOUT.md (flat-chart arithmetic
# with a cosine correction). If one is off, trust the script and fix the document.
HAND_LENGTHS = {
    'brindle_cinder': 5588, 'slatewater_cinder': 6735, 'cinder_gannet_gut': 5484,
    'cinder_gannet_cape': 9968, 'gannet_orrin': 5559, 'brindle_gannet': 11107,
    'slatewater_gannet': 12607, 'brindle_orrin': 12217, 'slatewater_orrin': 13717,
    'brindle_tallow': 8440, 'slatewater_tallow_inner': 7268, 'slatewater_tallow_outer': 9462,
    'brindle_farrow': 11381, 'slatewater_farrow': 11611, 'cinder_farrow': 8321, 'tallow_farrow': 9517,
}


class TraversalBudgetTest(unittest.TestCase):
    def setUp(self):
        self.layout = budget.load()

    def broken(self, change):
        layout = copy.deepcopy(self.layout)
        change(layout)
        return budget.failures(layout)

    def test_layout_agrees(self):
        self.assertEqual(budget.failures(self.layout), [])

    def test_hand_lengths(self):
        routes = {route['id']: route for route in self.layout['routes']}
        self.assertEqual(set(HAND_LENGTHS) | {'brindle_slatewater'}, set(routes))
        for name, expected in HAND_LENGTHS.items():
            self.assertAlmostEqual(budget.route_lengths(self.layout, routes[name])[0], expected, delta=expected * 0.005, msg=name)

    def test_cinder_point_is_placed_as_recorded(self):
        port = self.layout['ports']['port_cinder_point']
        self.assertEqual(port['position'], [-2.0, 2.0])
        self.assertEqual(sorted(port['services']), sorted(budget.strings(budget.record(port['record'])['service_ids'])))

    def test_existing_anchors_are_kept(self):
        ports = self.layout['ports']
        self.assertEqual(ports['port_brindle_quay']['position'], [0.0, 0.0])
        apart = budget.separation(self.layout, ports['port_brindle_quay']['position'], ports['port_slatewater_works']['position'])
        self.assertAlmostEqual(apart, 1500.0, places=3)

    def test_heavy_lifter_cannot_use_needle_gut(self):
        lifter = budget.hull(self.layout, 'ship_heavy_lifter_01')
        routes = {route['id']: route for route in self.layout['routes']}
        self.assertFalse(budget.permitted(self.layout, lifter, routes['cinder_gannet_gut']))
        self.assertTrue(budget.permitted(self.layout, lifter, routes['slatewater_tallow_inner']))

    def test_disagreements_are_caught(self):
        def radius(layout): layout['scale']['navigation_radius_m'] = 200000.0
        def clock(layout): layout['scale']['game_seconds_per_real_second'] = 2.0
        def speed(layout): layout['hulls']['ship_swift_container_01']['top_speed_mps'] = 10.0
        def lifter(layout): layout['hulls']['ship_heavy_lifter_01']['size_class'] = 'S'
        def gate(layout): layout['passages']['skerry_gate']['clear_width_m'] = 60.0
        def service(layout): layout['ports']['port_cinder_point']['services'].remove('repair')
        def far(layout): layout['ports']['port_orrin_deep']['position'] = [-1.0, 9.0]
        def tier(layout): layout['routes'][1]['tier'] = 'long'
        def detour(layout): layout['routes'][3].pop('alternative')
        for change in (radius, clock, speed, lifter, gate, service, far, tier, detour):
            self.assertTrue(self.broken(change), change.__name__)


if __name__ == '__main__': unittest.main()
