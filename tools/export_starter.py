"""Blender 3.6.1: export the preserved starter source; never save over it.

Run with --background --factory-startup --disable-autoexec --python this_file.
Optional arguments after --: --revision-note TEXT (harmless reimport proof).
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

PROJECT = Path(__file__).resolve().parent.parent
SOURCE = PROJECT / 'art_sources/starter_container_01/starter_container_01.blend'
DEST = PROJECT / 'features/ships/starter_container_01'
SOURCE_HASH = 'C5113240F9149996F1F8B6452E57FC04890F8A9AAE79FED904AE6139B8B5FE06'
SOCKETS = ['camera_follow', 'helm_view', 'name_port', 'name_starboard', 'flag',
           'service', 'engine_audio', 'horn_audio', 'wake_port', 'wake_starboard',
           'exhaust_01', 'cargo_origin']


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def godot_point(point):
    return [round(float(point[0]), 6), round(float(point[2]), 6), round(float(-point[1]), 6)]


def bounds(objects):
    deps = bpy.context.evaluated_depsgraph_get()
    points = [o.matrix_world @ Vector(p) for o in objects
              for p in o.evaluated_get(deps).bound_box]
    converted = [godot_point(p) for p in points]
    return {'min': [min(p[i] for p in converted) for i in range(3)],
            'max': [max(p[i] for p in converted) for i in range(3)]}


def export_glb(objects, path):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.hide_set(False)
        obj.select_set(True)
    options = dict(filepath=str(path), export_format='GLB', use_selection=True,
                   export_yup=True, export_apply=True, export_extras=True,
                   export_animations=False, export_cameras=False, export_lights=False)
    supported = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    require(all(key in supported for key in options), 'Pinned glTF exporter API changed.')
    require('FINISHED' in bpy.ops.export_scene.gltf(**options), 'GLB export failed.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--revision-note', default='baseline')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    require(bpy.app.version == (3, 6, 1), 'Validate an exporter upgrade before changing Blender version.')
    require(hashlib.sha256(SOURCE.read_bytes()).hexdigest().upper() == SOURCE_HASH,
            'Preserved source changed; inspect and update the source contract deliberately.')
    DEST.mkdir(parents=True, exist_ok=True)
    # Append only the authored asset collection into a disposable factory scene.
    # This avoids evaluating preview cargo modifiers before their shading fix.
    with bpy.data.libraries.load(str(SOURCE), link=False) as (available, loaded):
        require('EXPORT_starter_container_01' in available.collections, 'Missing export collection.')
        loaded.collections = ['EXPORT_starter_container_01']
    collection = loaded.collections[0]
    for obj in collection.all_objects:
        if obj.type == 'MESH' and any(m.type == 'WEIGHTED_NORMAL' for m in obj.modifiers):
            obj.data.use_auto_smooth = True
    bpy.context.scene.collection.children.link(collection)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0
    root = collection.objects.get('MODEL_starter_container_01')
    require(root is not None and root.matrix_local == Matrix.Identity(4), 'Asset root must remain identity.')
    root['asset_id'] = 'starter_container_01'
    root['revision_note'] = args.revision_note
    cargo = [o for o in collection.all_objects if o.name.startswith('CARGO_')]
    objects = [o for o in collection.all_objects
               if o.type in {'MESH', 'EMPTY'} and not o.name.startswith(('CARGO_', 'Cargo_', 'PROXY_'))]
    for obj in objects:
        require(obj.matrix_world.determinant() > 0, 'Negative/zero scale: ' + obj.name)
    for name in SOCKETS:
        require(sum(o.name == 'SOCKET_' + name for o in objects) == 1, 'Missing/duplicate socket: ' + name)
    # Sign local +Z points out of the hull after conversion, with local +Y up.
    collection.objects['SOCKET_name_port'].rotation_euler = (0, 0, math.pi / 2)
    collection.objects['SOCKET_name_starboard'].rotation_euler = (0, 0, -math.pi / 2)
    meshes = [o for o in objects if o.type == 'MESH']
    hull = collection.objects['MESH_hull']
    bpy.context.view_layer.update()
    hull_bounds = bounds([hull])
    visual_bounds = bounds(meshes)
    deps = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    for obj in meshes:
        evaluated = obj.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    materials = sorted({m.name for o in meshes for m in o.data.materials if m})
    require(len(meshes) <= 100 and len(materials) <= 8 and triangles <= 20000,
            'Starter prototype budget exceeded; review before expanding asset.')
    export_glb(objects, DEST / 'starter_container_01.glb')

    # Tiny independent axis/scale witness uses the same exporter options.
    calibration = bpy.data.objects.new('MODEL_calibration', None)
    bpy.context.scene.collection.objects.link(calibration)
    witnesses = [calibration]
    for name, position in [('CAL_bow', (0, -2, 0)), ('CAL_port', (1, 0, 0)),
                           ('CAL_starboard', (-1, 0, 0)), ('CAL_up', (0, 0, 1))]:
        obj = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = calibration
        obj.location = position
        witnesses.append(obj)
    export_glb(witnesses, DEST / 'axis_calibration.glb')
    manifest = {
        'asset_id': 'starter_container_01', 'ship_definition_id': 'ship_starter_container_01',
        'status': 'prototype_asset_only', 'source_sha256': SOURCE_HASH,
        'blender_version': bpy.app.version_string, 'meters_per_unit': 1.0,
        'forward_godot': '+Z', 'up_godot': '+Y',
        'origin': 'Hull midpoint/centerline at reference empty waterline Y=0',
        'hull_bounds': hull_bounds, 'empty_visual_bounds': visual_bounds,
        'loaded_draft_m': None, 'gameplay_capacity': None,
        'required_sockets': ['SOCKET_' + n for n in SOCKETS],
        'socket_positions': {o.name: godot_point(o.matrix_world.translation)
                             for o in objects if o.name.startswith('SOCKET_')},
        'visual_slot_positions': {o.name.removeprefix('CARGO_'): godot_point(o.matrix_world.translation)
                                  for o in cargo},
        'collision_hull_points': [godot_point(hull.matrix_world @ v.co) for v in hull.data.vertices],
        'collision_status': 'Convex hull authoring reference; physics ownership selected at Step16',
        'mesh_objects': len(meshes), 'evaluated_triangles': triangles, 'materials': materials,
        'export_fixes': ['Enable Auto Smooth for existing weighted-normal modifiers in disposable scene',
                        'Correct name socket outward normals and preserve upright sign axes'],
        'excluded': ['Preview cargo and corrugation', 'Source collision proxies', 'Cameras/lights', 'Default scene objects'],
        'provenance': 'User-supplied Blender file; related local generation script claims original agent-assisted geometry. Source files differ; rights confirmation pending before distribution.'
    }
    (DEST / 'asset_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    points = ', '.join(str(v) for point in manifest['collision_hull_points'] for v in point)
    (DEST / 'hull_collision.tres').write_text(
        '[gd_resource type="ConvexPolygonShape3D" format=3]\n\n[resource]\n'
        'points = PackedVector3Array(' + points + ')\n', encoding='utf-8')
    print('STARTER_EXPORT_OK ' + json.dumps({'meshes': len(meshes), 'triangles': triangles,
                                          'materials': materials, 'bounds': visual_bounds}))


if __name__ == '__main__':
    main()
