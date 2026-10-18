# Map art direction

## Coastal palette — October 18, 2026

Andy selected the ocean and rocks in the supplied coastal photograph as a map
color reference, with permission for colors to vary by region. The direction is
a softly muted blue-green / blue-gray sea against warm gray-brown rock, with
off-white foam, dark wet crevices, and pale mineral highlights. This complements
the project's original low-poly art style: broad readable color groups, simple
faceted rocks, and restrained surface detail.

The reference is the coastal photograph in `Photo 1.jpg` attached to this chat.
The social interface and room photograph are outside the selected reference.
The supplied image remains external and unchanged; it is a visual reference,
not a game texture or a terrain model to reproduce.

These are interpreted starting colors, not exact physical samples or a promise
of identical on-screen color under every light:

| Role | Starting color | Intended use |
| --- | --- | --- |
| Coastal water | `#8EAEB7` | Muted blue-gray water with a gentle green cast |
| Water in shallows | `#B1CACB` | Lighter, less saturated coastal transitions |
| Deeper water | `#607F8C` | Cooler, darker distance and depth variation |
| Coastal rock | `#76695B` | Warm gray-brown stone body |
| Wet rock / crevices | `#443E37` | Small dark areas that preserve the warm rock family |
| Mineral highlights | `#B6AD9B` | Sparse pale facets, avoiding uniformly bright stone |
| Foam | `#E7EDE7` | Soft off-white surf, without a harsh pure-white border |

## Reusable material starting points

Three plain `StandardMaterial3D` resources store the primary swatches:

- `res://features/world/materials/coastal_water.tres`: `#8EAEB7`, roughness 0.35.
- `res://features/world/materials/coastal_rock.tres`: `#76695B`, roughness 0.90.
- `res://features/world/materials/coastal_foam.tres`: `#E7EDE7`, roughness 0.85.

All three are opaque, non-metallic starting materials. They are ready to use as
base swatches when the water and terrain roadmap tasks begin. They do not yet
render water depth, transparency, waves, reflections, foam motion, wetness, or
shore transitions; those behaviors need their own later implementation and
visual checks. No map geometry is added by this palette change.

## Regional variation

Keep the muted coastal palette as one recognizable regional family. Later
regions can shift water toward clearer blue-green in warm shallows, deeper
blue-gray offshore, and cooler desaturated tones around polar coasts. Rock can
vary with the terrain, including warmer tan, cooler gray, or darker volcanic
stone. Preserve readable separation between land, sea, foam, ships, and route
markers; avoid making every region use the same rock or water shade.

Choose final regional colors alongside actual terrain, daylight, fog, and ship
materials. Revisit these swatches in the first representative water-and-coast
scene; the setup screen and export check do not validate the finished map look.
