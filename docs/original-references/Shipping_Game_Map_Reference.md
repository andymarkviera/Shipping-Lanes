# Connected World — map design and data reference

Andy’s shipping game • October 18, 2026 • Map reference v0.1

## 1. Purpose and status

This is a **new, separate reference** for the selected map concept and its proposed Godot data contracts. It does not modify the mechanics research, game specification, or build roadmap. Consult it alongside those documents when implementing the map; do not silently rewrite the older documents to match it.

The visual basis is the last **“CONCEPT A — CONNECTED WORLD”** image: flat Earth-inspired world map, fictional islands, named ports, no drawn shipping routes, and a fictional widened Panama passage beneath a giant suspension bridge. Its subtitle is “Earth-inspired geography • Fictional islands • Ports overview.” The inset depicts the fictional Panama detail. The image is illustrative and is not a georeferenced coastline asset or an engineering drawing.

**Selected design direction:** recognizable world geography with fictional additions, a rotatable globe map interface, and continuous circumnavigation. The reference itself remains flat 2D for easy inspection. All regions and ordinary passages are open; no war closures, red restriction zones, level locks, or compulsory route lines.

**Proposed implementation:** one canonical geographic dataset feeding both flat and globe views, with streamed local simulation around active areas. The physical-world technique must pass a small prototype before commitment. No globe, terrain mesh, navigation graph, or runtime map system has been implemented by creating this file.

Names carried from the image are the baseline display names. Additional services, a local starter destination, coordinates, regions, and engineering fields below are explicitly proposed authoring data. Distances, port limits, world radius, bridge dimensions, and voyage duration remain unmeasured and tunable.

## 2. What the world looks like

| Area | Visual identity and arrangement | Intended gameplay character |
| --- | --- | --- |
| North America | Recognizable broad continent on the west side of the flat map; varied coasts and a large eastern harbor | Short starter trips and transatlantic departures |
| South America | Long western/southwestern landmass, navigable coasts and open southern approach | Bulk and container voyages; southern crossings |
| Europe | Dense northern coastline with a substantial North Europe hub | Industrial cargo and nearby coastal trips |
| Africa | Large central landmass; open ocean around its southern tip | Alternative voyage lengths and offshore industrial work |
| Asia | Large eastern landmass with readable coasts and southeast island passages | Large container, gas, and oil destinations |
| Australia | Separate southeastern continent with an accessible southern coast | A southern hub, not a map boundary |
| Arctic | Northern ocean, Greenland, scattered islands, snowy Aurora Port | Polar supply voyages; open fictional game navigation |
| Antarctica | Distinct southern ice-covered landmass with coastal Polar Station | Supply destination with navigable ocean offshore |
| Atlantic Relay islands | Invented mid-Atlantic island group and port | A useful stop and fictional cross-ocean destination |
| Southern Cross islands | Invented island group south of Australia | Southern Ocean staging and Antarctic connections |
| Panama passage | Deliberately terraformed, widened ocean connection at the American isthmus | Atlantic–Pacific shortcut under the megabridge |

The map is geographically inspired, not a simulation of actual geopolitical or polar navigation conditions. Fictional polar access is a game-world premise. In the playable world, use simple cartoon terrain, modular docks, readable silhouettes, and restrained port detail; do not assume the illustration’s painted detail is the required mesh complexity.

The oceans must feel spacious. Provide local journeys around populated coasts as well as long crossings. Do not surround each port with a tiny isolated island merely to reduce sailing distances. Compress world scale deliberately rather than hide inconsistent distances in unrelated scripts.

## 3. Named port register

Stable IDs are internal keys. Display names can change without changing ownership, jobs, prices, or save references. The first ten names come from the chosen image. The eleventh is a **new proposed starter-neighbor port**, needed to make a small container ship’s first trips practical; it was not a named label in the image.

Services here are proposals to ensure useful cargo coverage, not already approved prices, commodity catalogs, or berth dimensions. `containers`, `bulk`, `oil_trade`, `gas`, and `cargo_fuel` mean cargo services; `propulsion_fuel` is a separate ship service. `refinery` means access to a refinery facility, not a free stock grant. A port can have several different berths.

| Stable port ID | Display name | Concept location | Proposed cargo/service identity |
| --- | --- | --- | --- |
| `port_east_coast` | East Coast | Atlantic side of North America | Starter home; containers, propulsion fuel, repair, ship spawn/shop |
| `port_north_europe` | North Europe | Northwestern Europe coast | Major container/bulk hub; fuel, repair, large-ship services |
| `port_gulf_terminal` | Gulf Terminal | Gulf-side industrial coast of western Asia | Oil, gas, cargo fuel, refinery; tanker services |
| `port_east_asia` | East Asia | East Asian seaboard | Large container/bulk hub; fuel, repair, ship services |
| `port_singapore` | Singapore | Southeast Asian maritime junction | Mixed container, oil, gas, cargo-fuel services; refinery candidate |
| `port_south_australia` | South Australia | Southern Australian coast | Containers/bulk; fuel, repair, southern-voyage services |
| `port_atlantic_relay` | Atlantic Relay | Fictional Atlantic island chain | Containers, fuel, repair; a voyage stop and independent destination |
| `port_aurora` | Aurora Port | Fictional Arctic island | Containers/bulk supply; fuel and repair to avoid a one-way trap |
| `port_southern_cross` | Southern Cross | Fictional island south of Australia | Containers/cargo fuel; fuel and repair; Antarctic staging |
| `port_polar_station` | Polar Station | Antarctic coast | Primarily container/bulk supply; minimal compatible fuel/repair services |
| `port_harbor_point` | Harbor Point | **Proposed:** close to East Coast on the same broad coast | Second small-container destination; fuel, repair, small-ship berth |

Unlabelled white coastline dots in the illustration are **visual placeholders**. They are not dozens of fully defined ports or implied launch commitments. Add them later as explicit validated records. At least one additional major South American cargo port and African cargo port are sensible expansion candidates, but no names or catalog rows are silently invented for them here.

**Geographic correction during authoring:** the concept image places some labels approximately. Put Gulf Terminal on the intended Gulf-side water, with a real sea approach through the Gulf exit; do not interpret the painted label’s position on the Red Sea/Arabian area as final coordinates. Likewise, fictional island positions are adjustable. Author the coast, approach, dock, globe marker, and flat marker from the same data.

## 4. Authoring seed coordinates

These are **proposed coarse world-design seeds**, not surveyed port positions, not pixel measurements, and not spawn transforms. Latitude/longitude act as a consistent address system for our fictionalized world. Coastlines must be authored to support them, or the records moved deliberately with versioning. No economic distance table should be frozen from these seeds.

| Port ID suffix | Latitude ° | Longitude ° | Placement note |
| --- | ---: | ---: | --- |
| `east_coast` | 35.0 | -76.0 | Eastern North American region |
| `harbor_point` | 35.3 | -75.8 | Intentionally close to the starter home; tune for minutes, not Earth-scale realism |
| `north_europe` | 52.0 | 4.0 | Northwestern Europe region |
| `gulf_terminal` | 25.2 | 55.0 | Gulf region; coastline/berth placement needs local authoring |
| `east_asia` | 31.0 | 123.0 | East Asian coastal region |
| `singapore` | 1.2 | 104.0 | Southeast Asian junction |
| `south_australia` | -35.0 | 138.5 | Southern Australia |
| `atlantic_relay` | 17.0 | -41.0 | Fictional island chain |
| `aurora` | 75.0 | -5.0 | Fictional Arctic island |
| `southern_cross` | -49.0 | 115.0 | Fictional island south of western Australia |
| `polar_station` | -69.0 | 30.0 | Fictional Antarctic coastal service location |

Ports need separately authored offshore approach anchors, spawn volumes, berth-local transforms, depth, and collision. A coarse latitude/longitude record is insufficient to spawn a large hull safely. A seed can fall on land in a real-world basemap; this is precisely why the final fictional coastline and port validation must agree before using it at runtime.

## 5. Regions and scene streaming

Use these as content/authoring groups, **not separate matchmaking servers**:

| Region ID | Content grouping |
| --- | --- |
| `region_north_america` | East Coast, Harbor Point, continental shore assets |
| `region_central_america` | Panama passage and bridge |
| `region_south_america` | Continental shores and future ports |
| `region_north_atlantic` | North Europe approaches, Atlantic Relay and northern ocean content |
| `region_africa` | African coastline and southern cape navigation |
| `region_west_asia` | Gulf Terminal and surrounding approaches |
| `region_east_asia` | East Asia and western Pacific shores |
| `region_southeast_asia` | Singapore and nearby maritime passages |
| `region_australia` | South Australia and adjacent shores |
| `region_arctic` | Aurora Port and polar islands |
| `region_southern_ocean` | Southern Cross and open southern sea |
| `region_antarctica` | Polar Station and Antarctic coast |

A region can contain many streaming tiles. Exact tile bounds and sizes are determined by profiling; do not simulate an entire continent as one physics scene. Ocean tiles are valid even without land or ports. Every ocean position must resolve to a world address; the table is not a complete hand-drawn ocean partition.

For a spherical address system, use cube-face or another pole-safe tile indexing scheme once the prototype selects one; persist stable geographic positions rather than relying on a temporary tile index. `region_id` is an authoring/filter tag, while `tile_id` is a streaming implementation detail. Changing tiling must not teleport saved ships.

Only the required scenery, nearby hulls, service visuals, and collision need detailed instances. Distant ships retain lightweight authoritative identity/position records. Server interest/relevance checks must also connect across the longitude seam and nearby polar tiles.

## 6. One world address, two map views

### Canonical position contract

Proposed saved/networked geographic location:

```json
{
  "world_id": "world_connected_a",
  "world_revision": 1,
  "latitude_deg": 35.0,
  "longitude_deg": -76.0,
  "altitude_m": 0.0,
  "heading_deg": 90.0
}
```

- Latitude is north-positive, in `[-90, 90]`. Longitude is east-positive, canonicalized to `[-180, 180)`.
- Heading is clockwise from local north in `[0, 360)` for ordinary positions. Polar runtime motion needs a transported tangent basis; a scalar heading alone is ambiguous at the exact poles.
- Altitude is relative to the reference sea surface, in game meters. Hull draft/waterline geometry remains separate.
- Store numeric geographic fields with double-precision semantics in validated save/network formats; do not persist a giant global `Vector3` as the only location record.
- Ship IDs and cargo/job IDs do not change when longitude wraps or scenery changes.
- Public server switching is a session handoff; sailing between map regions or across the seam is **not** a public server switch.

### Flat 2D view

Use an equirectangular overview generated from the authored world. With longitude `λ` and latitude `φ` in degrees:

```text
u = (canonical_longitude_deg + 180) / 360
v = (90 - latitude_deg) / 180
pixel_x = u * map_width
pixel_y = v * map_height
```

Wrap horizontal scrolling; vertically stop at the polar extent rather than joining north directly to south. This projection distorts polar areas; it is an overview, not a reliable distance ruler. Draw each world feature once in canonical data and duplicate its presentation near the scrolling seam only when necessary.

### Rotatable globe view

Use the same land/port data on a globe mesh, not a second manually positioned port catalog. Proposed axis convention: `+Y` north; zero longitude faces `+Z`; positive longitude turns toward `+X`. For radians `φ, λ`, the unit surface direction is:

```text
x = cos(φ) * sin(λ)
y = sin(φ)
z = cos(φ) * cos(λ)
```

The UI globe radius is a **display radius**, independent of the navigation/world radius. Rotating the globe changes the view, not ship positions. Generate UVs consistently with the flat view and test known anchors; do not assume a stock sphere mesh’s UV orientation matches this convention.

Support drag-to-rotate, zoom limits, reset north, focus player, search/select port, cargo/service filters, and a detail panel. Ray-pick the sphere, convert the hit to geographic coordinates in the globe’s local frame, and select nearby eligible markers. Hide/fade markers on the far hemisphere and handle clustered labels. Players choose destinations; the globe is not a teleportation feature.

**Default overview has no route lines**, matching the selected image. Optional player waypoints or a route preview can be toggled on as interface aids. That is different from requiring ships to follow fixed painted lanes.

## 7. Circumnavigation and physical-world prototype

**Required player-facing result:** there is no east/west ocean wall. A player can complete a water-connected voyage around the world and return to the same place. Arctic and Southern Ocean routes are navigable. Antarctica is a continent, not a southern map-exit trigger.

### Recommended prototype direction

Use a spherical geographic address model, but stream manageable local simulation patches near active areas rather than putting the entire Earth-sized surface into one physics scene. Evaluate local tangent-plane patches against a small actual curved-surface prototype. Select the method that satisfies docking, nearby multiplayer, polar travel, camera behavior, and performance. This file establishes the data contract and intended connectivity; it does not falsely certify one untested physics implementation.

A simple east/west wrapped rectangle is an acceptable **test harness**, but is not automatically a complete globe: naïvely clamping latitude or joining top and bottom gives incorrect pole behavior. Any final method must agree with map distance and geographic travel rules. A rotatable globe UI by itself does not prove continuous sailing.

### Seam and pole rules

- Normalize longitude with `((longitude + 180) mod 360) - 180`, using nonnegative modulo behavior.
- Use the shortest wrapped longitude delta for overview interpolation, not a naïve subtraction. `179.9°` to `-179.9°` is a nearby crossing, not an almost-complete lap.
- At the poles, advance using a unit-sphere/tangent representation or an equivalent tested method. Do not drive longitude by dividing by `cos(latitude)` without a polar-safe branch.
- Transform ship orientation, local velocity, camera state, and attached payloads together when a simulation chart/origin changes. Transport the tangent frame rather than copying its coordinates into a differently oriented patch.
- Nearby ships on opposite sides of a tile/seam must still see, collide, dock, and exchange permissions consistently. Seam display duplication must never create two authoritative entities.
- Authoritative simulation owns motion. Map rotation, marker drag, and camera transitions cannot move the ship.
- Use game/server time for operations. Crossing a longitude/date boundary cannot reset loading clocks, create market refreshes, or earn offline rewards.

### Local physics and multiplayer boundaries

Server authority must assign each active ship to one simulation owner. Two client-local patches cannot independently simulate conflicting versions of the same collision. During chart/tile transitions, stage the target collision/visual data, transform related entities consistently, commit the new mapping once, then release the old representation. Reconnect restores canonical position, not a stale scene-node path.

Use origin-local coordinates for physics where selected. The spatial/index layer must translate interest queries across patches and polar boundaries. Late join snapshots include canonical position and the required simulation-frame metadata. This work is a prototype gate, not “Godot wraps the map automatically.”

## 8. World scale, distance, and travel

Keep these concepts distinct:

| Quantity | Meaning |
| --- | --- |
| UI globe radius | Display size of the rotatable map |
| Navigation radius | Configured game-world spherical scale used for geographic distance |
| Local scene scale | Normally meters per Godot unit; keep explicit |
| Direct separation | Endpoint separation used by a selected quote formula, if appropriate |
| Navigable route length | A water-valid path avoiding continents and incompatible passages |
| Odometer distance | Actual traveled distance, accumulated once by authority |
| ETA | Estimated travel time using current/assumed speed and a water-valid path |

For a spherical navigation model, direct separation can use a haversine/central-angle calculation with the configured game radius. Clamp intermediate trigonometric inputs against floating-point noise. A great-circle segment can cross land; it is not automatically a valid sea route. Use a water-navigation graph or equivalent obstacle-aware system for actual route planning.

No fixed Earth radius, final circumference, or time acceleration is selected here. Use one explicit `navigation_radius_m` and consistent speed/distance conversions; never set unrelated globe, physics, and payout scales to values that only look plausible individually. Benchmark local starter trips, medium journeys, longest crossings, and a full circuit before freezing dimensions.

Tune East Coast–Harbor Point first. If it is too short at the chosen world scale, adjust their authored separation or the scale deliberately. Do not solve it by assigning arbitrary unrelated “nautical miles” to one port pair while movement uses another distance system.

## 9. Fictional Panama passage and megabridge

| Record | Proposed value/rule |
| --- | --- |
| Passage ID | `passage_panama` |
| Display name | Panama Passage |
| Bridge ID | `bridge_panama_mega` |
| Bridge display name | Panama Megabridge |
| Region | `region_central_america` |
| Approximate design seed | `9.0° N, 79.7° W`; widened fictional geography around the seed |
| Connection | Caribbean/Atlantic water to Pacific water |
| Geography | A deliberately broad sea-level cut through the isthmus; no lock staircase required in this concept |
| Bridge | Monumental suspension bridge spanning the newly separated landbanks |
| Navigation | Large ships pass below the main span; the channel remains open |
| Gates/tolls/events | None required by the selected concept; no assumed war restrictions or level unlock |

Create a water-connected channel surface and depth corridor first; a bridge model alone does not establish passability. Author Atlantic approach, channel centerline, bridge span, Pacific approach, navigation lights, and exclusion/collision geometry around piers. The bridge footprint must not accidentally make an invisible dam.

Before assigning dimensions, measure the largest intended hull’s beam, loaded/unloaded draft, and air draft including superstructure/cargo. Set channel width/depth and bridge clearance with an explicit safety margin. The reference does **not** invent a certified meter clearance. Proposed fields include `channel_min_width_m`, `channel_min_depth_m`, `bridge_min_clearance_m`, and `largest_supported_ship_id`; they remain unresolved until the fleet prototype exists.

Avoid an unconditional one-ship lock queue for a broad permanently open passage. Add traffic control only if testing demonstrates a need. A visible overhead bridge stays fixed/open in the baseline; no lifting-bridge sequence is implied. If the scene is streamed, both sides of the main span need collision available before a ship enters it.

## 10. Proposed Godot content contracts

Use typed custom Resources for authored content. Immutable definitions must be separate from live berth occupancy, market quotes, refinery stock, and loading jobs. JSON below is an interchange illustration; it is not executable Godot code, a complete Resource implementation, or an untrusted Resource-loading format.

| Definition | Important fields |
| --- | --- |
| `WorldDefinition` | `world_id`, `content_revision`, coordinate convention, scale config, port/region/passage registries, coastline/depth/navigation assets |
| `PortDefinition` | Stable `port_id`, `display_name`, geographic marker, `region_id`, service IDs, berth IDs, spawn-set IDs, display/icon tags |
| `BerthDefinition` | Stable `berth_id`, parent port, local anchor, accepted cargo/services, depth/beam/length/clearance constraints |
| `ServiceDefinition` | Stable `service_id`, service type, port ID, optional refinery/market reference; no mutable stock in the definition |
| `RegionDefinition` | Stable region tag, content registry, biome/display tags; streaming policy separate |
| `PassageDefinition` | Stable passage ID, connected navigation anchors, constraint geometry, clearance/depth rules, related bridge ID |
| `BridgeDefinition` | Stable bridge ID, local placement, span/pier collision, clearance envelope, visual scene |
| `NavigationAnchor` | Stable anchor ID, geographic location, water-valid adjacency and permitted vessel envelope |

Prefer stable semantic IDs to names derived from the current scene hierarchy. If a port is renamed, keep its ID. If an existing location must move significantly, increment world content revision and migrate/reconcile saved docked ships and accepted jobs deliberately.

### Example authoring manifest

This compact valid JSON preserves the full named baseline. `null` means an intentional pending authoring value, **never zero** or unlimited capacity. It is not production-ready spawn data.

```json
{
  "schema_version": 1,
  "world_id": "world_connected_a",
  "content_revision": 1,
  "status": "concept_seed_not_runtime_ready",
  "coordinate_system": "latitude_longitude_degrees",
  "globe_axis_convention": "north_y_lon0_z_east_x",
  "navigation_radius_m": null,
  "meters_per_scene_unit": 1.0,
  "default_route_overlay": false,
  "ports": [
    {"port_id":"port_east_coast","display_name":"East Coast","lat":35.0,"lon":-76.0,"region_id":"region_north_america"},
    {"port_id":"port_north_europe","display_name":"North Europe","lat":52.0,"lon":4.0,"region_id":"region_north_atlantic"},
    {"port_id":"port_gulf_terminal","display_name":"Gulf Terminal","lat":25.2,"lon":55.0,"region_id":"region_west_asia"},
    {"port_id":"port_east_asia","display_name":"East Asia","lat":31.0,"lon":123.0,"region_id":"region_east_asia"},
    {"port_id":"port_singapore","display_name":"Singapore","lat":1.2,"lon":104.0,"region_id":"region_southeast_asia"},
    {"port_id":"port_south_australia","display_name":"South Australia","lat":-35.0,"lon":138.5,"region_id":"region_australia"},
    {"port_id":"port_atlantic_relay","display_name":"Atlantic Relay","lat":17.0,"lon":-41.0,"region_id":"region_north_atlantic"},
    {"port_id":"port_aurora","display_name":"Aurora Port","lat":75.0,"lon":-5.0,"region_id":"region_arctic"},
    {"port_id":"port_southern_cross","display_name":"Southern Cross","lat":-49.0,"lon":115.0,"region_id":"region_southern_ocean"},
    {"port_id":"port_polar_station","display_name":"Polar Station","lat":-69.0,"lon":30.0,"region_id":"region_antarctica"},
    {"port_id":"port_harbor_point","display_name":"Harbor Point","lat":35.3,"lon":-75.8,"region_id":"region_north_america","status":"proposed_starter_neighbor"}
  ],
  "passages": [
    {
      "passage_id":"passage_panama",
      "display_name":"Panama Passage",
      "region_id":"region_central_america",
      "seed_lat":9.0,
      "seed_lon":-79.7,
      "bridge_id":"bridge_panama_mega",
      "channel_min_width_m":null,
      "channel_min_depth_m":null,
      "bridge_min_clearance_m":null,
      "state":"open",
      "authoring_status":"requires_geometry_and_clearance_validation"
    }
  ]
}
```

A runtime build must reject unresolved required scale, navigation, berth, spawn, and clearance data. Do not spawn a ship directly from this example or interpret `state: open` as bypassing physical constraints. A complete implementation adds explicitly validated registries for all referenced regions/services and deterministic content hashes.

## 11. Dynamic state, economy, and persistence

The map catalog is not the economy database. Public servers share the selected oil market and refinery inventories. Use stable public facility keys such as `refinery_gulf_terminal_01` and retain them when scenery unloads. Private-host state uses a separate namespace even if its maps have the same port IDs. Public listing of a private-hosted server does not grant it public-economy authority.

Suggested live-state categories:

- Player/ship records: account and ship ID, canonical location, local motion/frame metadata, active job/cargo references, condition, and ownership.
- Berth records: berth ID, reservation/occupancy, operation ID, and expiry/recovery state.
- Public refinery records: facility ID, public-world/economy namespace, input/output quantities, processing jobs, transaction IDs, and version.
- Market records: commodity/port IDs, versioned prices and accepted terms; no market tick is triggered by map rotation or region loading.
- Offshore heavy jobs: stable zone and payload IDs with an explicit session/world scope. This reference does not automatically make every offshore payload globally shared.

Saves include schema/content revision. Rebuild visual port markers, water, bridge meshes, and cargo visuals from definitions. Do not serialize those meshes as duplicate authoritative state. On a content update, reconcile occupied berths and moved anchors; never silently place a saved loaded ship inside terrain.

## 12. Godot-facing responsibilities

These are proposed small modules, not a mandate for many autoloads:

| Module | Responsibility |
| --- | --- |
| World catalog | Resolve/validate immutable IDs and definitions |
| Geographic math | Normalize coordinates; convert to/from globe and flat UV; compute configured separation |
| Globe map scene | Display/rotate/pick ports; issue navigation/selection requests |
| Flat overview scene | Display the same content with horizontal wrapping and sensible polar limits |
| Simulation spatial layer | Map canonical locations into local charts; translate interest, collision, and transitions |
| Scenery streamer | Load tile visuals/collision without deleting persistent jobs or inventories |
| Marine navigation | Produce water-valid paths and passage eligibility; estimate ETA |
| Port/service controller | Docking and service requests using existing gameplay authority |

A port scene should not directly edit a public refinery balance. The globe UI should not directly instantiate an owned ship. Keep scene display dependencies explicit so the same port can be tested alone, displayed on either map, and used by local or dedicated sessions.

## 13. Implementation order for this map module

This order is local to the new map reference. It does not renumber or alter the existing roadmap.

1. Load a tiny world catalog with East Coast, proposed Harbor Point, and a placeholder coastline. Validate IDs and required fields.
2. Prove flat/globe coordinate round trips and marker agreement using known anchors.
3. Create a rotatable globe with port search, selection, player focus, label culling, and no route lines by default.
4. Build a small circumnavigation harness with an ocean, two interacting ships, a seam, and polar test points. Evaluate the physical-world approach before detailed geography.
5. Prove a chart/tile transition, two nearby peers across the seam, an attached heavy payload, save/reload, and reconnect. Record measured limits.
6. Choose world radius/local scale and test starter travel timing, medium trips, and a complete circuit.
7. Author matching simplified coastline, land mask, depth, approaches, and water navigation assets. Generate the overview/globe presentation from this world data.
8. Build the starter port pair and complete a container voyage using the existing cargo/economy systems.
9. Build fictional Panama water geometry and bridge; test the largest intended hull envelope in both directions.
10. Add the other named ports in validated batches, including Arctic and Antarctic services and water south of Australia.
11. Profile dispersed and clustered ships toward the dedicated-player target. Verify interest filtering, transition load, scenery budgets, and persistent shared inventories.
12. Run the acceptance matrix below before calling the connected map ready.

If the physical prototype fails, revise this new map module’s implementation approach while preserving agreed appearance and player-facing goals where possible. Do not claim continuous globe sailing solely because the UI globe rotates.

## 14. Map acceptance matrix

| Check | Passing result |
| --- | --- |
| Port catalog | All ten named concept ports resolve, plus explicitly selected additions; no accidental ports generated from painted dots |
| Marker consistency | Flat and globe views identify the same port from one record; no duplicate economic entities at the seam |
| Globe interactions | Rotation, zoom, focus, filters, picking, and far-side marker hiding work without moving ships |
| Circumnavigation | A ship completes a water-valid loop and returns to the same location without a boundary wall or duplicated identity |
| Seam proximity | Opposite-longitude-neighbor ships see/interact correctly; camera/velocity/payload do not jump incorrectly |
| Polar travel | Arctic routes and Antarctic approaches function without singular heading/longitude failures |
| Southern Ocean | Ships can sail south of Australia and along navigable Antarctic offshore water |
| Panama | Both ocean approaches connect; large tested hull passes under the span with valid depth and clearance; piers collide correctly |
| Starter voyage | A small container ship can afford and complete useful nearby trips; the world does not require a transoceanic first delivery |
| Navigation | Suggested sea paths avoid land and respect ship dimensions; great-circle distance is not mistaken for a valid path |
| Streaming | Scenery transitions preserve ship, cargo, jobs, berth/facility state, and a usable camera |
| Persistence | Saved ships resume in valid water/berths with the same IDs; world-content revisions are checked |
| Public economy | Server/region changes do not reset market state or create duplicate refinery stocks |
| Hosting | Private worlds retain isolated state regardless of public directory listing |
| Performance | Measured server/client frame times, memory, bandwidth, and transition spikes meet recorded budgets at tested capacity |
| Visual agreement | No war closures or fixed route network appears in the default map; fiction and stylized scale are clear |

## 15. Decisions intentionally left for prototypes

- Final navigation radius, circumference, world-space scale, and voyage-time targets.
- Local chart/streaming implementation and polar-safe tile addressing.
- Exact terrain polygons, island outlines, depths, port approaches, berth/spawn transforms.
- Panama channel width/depth and bridge clearance after the launch hull envelopes exist.
- Finalized service and commodity lists per port; prices and stock/processing tuning remain economy data.
- Whether Harbor Point keeps its proposed name/location and which additional coastal ports make the launch cut.
- Exact public heavy-job scope and future dynamic infrastructure behavior.
- Camera/horizon treatment if the physical prototype uses local surface approximations.

These are recorded choices to make at a known stage, not silent defaults. The map design should remain data-driven so ordinary new ports, island groups, and services can be added without rewriting movement or ownership.

## 16. Source basis and limits

Design source: Andy’s explicit selections in this conversation and the final “Concept A — Connected World” illustration. The illustration defines appearance and broad arrangement, not precise positions or an implemented mesh. Coordinates and proposed port services in this file are newly authored game-design seeds.

Official Godot documentation checked for the proposed technical boundaries:

- [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html): authored custom data containers and shared loading behavior support separating definitions from live state.
- [Large world coordinates](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html): precision, custom build costs, and origin-shifting/multiplayer tradeoffs motivate the early local-physics prototype.
- [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html): visibility filtering supports selective replication; geographic interest rules and authority remain our work.

The mathematical coordinate convention and data structure above are proposed project contracts, not an off-the-shelf Godot globe-world feature. Match implementation APIs to the engine version pinned during setup. No old reference file was edited to create this map document.
