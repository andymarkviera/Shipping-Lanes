"""Blender 3.6.1: original heavy-lifter geometry using the starter's material roles.
The supplied starter .blend is read-only. Generated source, GLBs and preview are separate.
"""
from pathlib import Path
import hashlib
import json
import math
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art_sources/starter_container_01/starter_container_01.blend"
DEST = ROOT / "features/ships/heavy_lifter_01"
ART = ROOT / "art_sources/heavy_lifter_01"
assert bpy.app.version == (3, 6, 1)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest().upper() == "C5113240F9149996F1F8B6452E57FC04890F8A9AAE79FED904AE6139B8B5FE06"
DEST.mkdir(parents=True, exist_ok=True)
ART.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
with bpy.data.libraries.load(str(SOURCE), link=False) as (available, loaded):
    loaded.materials = [n for n in available.materials if n in {
        "MAT_deck", "MAT_hull_primary", "MAT_hull_secondary", "MAT_metal",
        "MAT_superstructure", "MAT_windows", "MAT_trim"}]
materials = {m.name: m for m in loaded.materials}
assert len(materials) == 7, materials.keys()

def xyz(p):
    # Author in Godot convention then convert to Blender.
    return (p[0], -p[2], p[1])

def box(name, size, center, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(center))
    o = bpy.context.object
    o.name = name
    o.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(materials[mat])
    return o

def hull():
    outline = [(-10,-45), (10,-45), (12,-37), (12,29), (9,40), (2,45), (-2,45), (-9,40), (-12,29), (-12,-37)]
    vertices = [xyz((x*s, y, z)) for y,s in [(-4.5,0.85),(-2.0,1.0)] for x,z in outline]
    n = len(outline)
    faces = [tuple(reversed(range(n))), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh = bpy.data.meshes.new("FacetedPontoon")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new("MESH_hull", mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(materials["MAT_hull_primary"])
    return o

ship = [hull()]
for side in [-1,1]:
    ship.append(box(f"MESH_side_pontoon_{side}", (3,5.0,74), (side*10.5,0.5,-5), "MAT_hull_primary"))
    ship.append(box(f"MESH_side_cap_{side}", (3.1,0.25,74), (side*10.5,3.12,-5), "MAT_deck"))
    for z in range(-40,33,6):
        ship.append(box(f"MESH_rail_post_{side}_{z}", (.11,1.0,.11), (side*11.8,3.7,z), "MAT_superstructure"))
    ship.append(box(f"MESH_rail_{side}", (.14,.14,73), (side*11.8,4.2,-4), "MAT_trim"))
    for z in [-35,-20,-5,10,25]:
        ship.append(box(f"MESH_bollard_{side}_{z}", (.45,.6,.45), (side*10.5,3.55,z), "MAT_metal"))
ship += [
    box("MESH_foredeck", (20,4.6,17), (0,.3,32), "MAT_hull_primary"),
    box("MESH_foredeck_cap", (20.2,.2,17.2), (0,2.7,32), "MAT_deck"),
    box("MESH_house_lower", (16,5,11), (0,5.3,32), "MAT_superstructure"),
    box("MESH_bridge", (17,3,9), (0,9.3,32), "MAT_superstructure"),
    box("MESH_bridge_roof", (18,.3,10), (0,10.95,32), "MAT_superstructure"),
    box("MESH_bridge_windows_front", (15,1.6,.08), (0,9.5,36.55), "MAT_windows"),
    box("MESH_bridge_windows_back", (15,1.6,.08), (0,9.5,27.45), "MAT_windows"),
    box("MESH_mast", (.25,5,.25), (0,13.5,32), "MAT_superstructure"),
    box("MESH_radar", (4,.3,.6), (0,15.8,32), "MAT_metal"),
    box("MESH_funnel", (2.8,4,3), (5,12,29), "MAT_trim"),
    box("MESH_funnel_cap", (3,.5,3.2), (5,14,29), "MAT_metal"),
]
for side in [-1,1]:
    ship.append(box(f"MESH_bridge_side_glass_{side}", (.08,1.6,7), (side*8.55,9.5,32), "MAT_windows"))
    for z in [29,32,35]:
        ship.append(box(f"MESH_house_porthole_{side}_{z}", (.08,.8,.9), (side*8.05,5.6,z), "MAT_windows"))
for x in [-6,-3,0,3,6]:
    ship.append(box(f"MESH_window_mullion_{x}", (.12,1.7,.13), (x,9.5,36.6), "MAT_superstructure"))
deck = [box("MESH_lift_deck", (18,.6,48), (0,2.3,-8), "MAT_deck")]
for x in [-8.6,8.6]:
    deck.append(box(f"MESH_deck_edge_{x}", (.18,.05,47), (x,2.63,-8), "MAT_trim"))
for z in [-29,-22,-15,-8,-1,6,13]:
    for x in [-7,7]:
        deck.append(box(f"MESH_deck_tie_{x}_{z}", (.8,.06,.4), (x,2.65,z), "MAT_metal"))

payload = [
    box("MESH_payload_base", (14,1.4,32), (0,.7,0), "MAT_hull_secondary"),
    box("MESH_payload_machine", (10,5,23), (0,3.9,0), "MAT_superstructure"),
    box("MESH_payload_top", (11,.4,24), (0,6.6,0), "MAT_deck"),
]
for x in [-5.3,5.3]:
    for z in [-13,13]:
        payload.append(box(f"MESH_payload_frame_{x}_{z}", (.6,8,.6), (x,4,z), "MAT_trim"))
for z in [-8,-4,0,4,8]:
    payload.append(box(f"MESH_payload_vent_{z}", (.1,2.4,1.6), (5.05,4,z), "MAT_windows"))

def export(objects, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(DEST/filename), export_format="GLB",
        use_selection=True, export_yup=True, export_apply=True,
        export_animations=False, export_cameras=False, export_lights=False)

export(ship, "heavy_lifter_01.glb")
export(deck, "lift_deck.glb")
export(payload, "industrial_payload.glb")
# Organize editable source with payload staged beside the ship for inspection.
for name, objects in [("EXPORT_hull",ship),("EXPORT_deck",deck),("EXPORT_payload",payload)]:
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    for o in objects:
        for old in list(o.users_collection): old.objects.unlink(o)
        collection.objects.link(o)
for o in payload: o.location.x += 33
bpy.context.scene.unit_settings.system = "METRIC"
bpy.context.scene.unit_settings.scale_length = 1
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ART/"heavy_lifter_01.blend"))
for o in ship+deck+payload: o.data.calc_loop_triangles()
triangles = sum(len(o.data.loop_triangles) for o in ship+deck+payload)
(DEST/"asset_manifest.json").write_text(json.dumps({
    "asset_id":"heavy_lifter_01", "status":"step26_feasibility_art",
    "blender_version":bpy.app.version_string, "meters_per_unit":1,
    "forward_godot":"+Z", "up_godot":"+Y",
    "hull_length_m":90, "beam_m":24, "deck_size_m":[18,48],
    "deck_raised_top_m":2.6, "deck_lowered_top_m":-1,
    "payload_envelope_m":[14,8,32], "mesh_objects":len(ship+deck+payload), "triangles":triangles,
    "materials":sorted(materials), "source":"art_sources/heavy_lifter_01/heavy_lifter_01.blend",
    "style":"Original faceted geometry; material datablocks read from user starter without modifying it",
    "gameplay_capacity":None, "actual_mass_tonnes":None
}, indent=2)+"\n")
# Render the authored asset, with a staged payload, for visual inspection.
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE"
scene.eevee.use_gtao=True
scene.eevee.gtao_distance=3
scene.world.color=(.4,.4,.4)
bpy.ops.object.light_add(type="SUN",rotation=(math.radians(25),math.radians(-20),math.radians(-35)))
bpy.context.object.data.energy=3
bpy.ops.object.light_add(type="AREA",location=(20,-40,75))
bpy.context.object.data.energy=10000
bpy.context.object.data.size=60
bpy.ops.object.camera_add(location=(110,105,100))
camera=bpy.context.object
camera.rotation_euler=(Vector((8,0,0))-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO"
camera.data.ortho_scale=135
scene.camera=camera
scene.render.resolution_x=1200
scene.render.resolution_y=850
scene.render.resolution_percentage=100
scene.view_settings.view_transform="Standard"
scene.view_settings.look="Medium High Contrast"
scene.render.filepath=str(ROOT.parent/"output/checks/step-26-blender.png")
bpy.ops.render.render(write_still=True)
print("HEAVY_BLENDER_BUILD_PASS meshes=%d" % len(ship+deck+payload))
