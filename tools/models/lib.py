# Shared helpers for building Endeavor props in Blender (run with: blender -b --python <script>).
# Roblox scale: 1 stud = 1 Blender unit here; the FBX exporter is told 1 unit = 1 stud.
import bpy, bmesh, math, os, sys
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, rgb, metallic=0.0, roughness=0.6, emission=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = 4
    m.diffuse_color = (*rgb, 1)
    return m

def obj_from_bmesh(name, bm, mat, location=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    # Roblox drops Blender material colours on import, so the material rides in the part name:
    # "<Part>_<Material>"; the game reads the suffix (see shared/Assets.lua).
    ob = bpy.data.objects.new(f"{name}_{mat.name}", me)
    ob.location = location
    me.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob

def cylinder(name, radius, depth, mat, segments=12, location=(0, 0, 0), radius2=None, cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segments, radius1=radius, radius2=radius if radius2 is None else radius2, depth=depth)
    return obj_from_bmesh(name, bm, mat, location)

def box(name, size, mat, location=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    return obj_from_bmesh(name, bm, mat, location)

def bevel(ob, width=0.04, segments=2):
    mod = ob.modifiers.new("Bevel", "BEVEL")
    mod.width, mod.segments = width, segments
    mod.limit_method = "ANGLE"

def jitter(ob, amount=0.02, seed=1):
    """Dents and dings: nudge vertices a little so the piece reads as worn, not CAD-perfect."""
    import random
    random.seed(seed)
    for v in ob.data.vertices:
        v.co += Vector((random.uniform(-amount, amount), random.uniform(-amount, amount), random.uniform(-amount, amount)))

def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]

def apply_mods(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)

def export_fbx(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, global_scale=0.01, # Blender metres -> FBX cm; 0.01 makes 1 unit = 1 stud in Roblox
        bake_space_transform=True, axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE",
        use_mesh_modifiers=True, path_mode="COPY", embed_textures=True)

def export_obj(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True, export_materials=True, forward_axis="NEGATIVE_Z", up_axis="Y", apply_modifiers=True)

def render(path, objs, size=(900, 700), distance=None, elevation=0.35, azimuth=0.8):
    """Preview: export an OBJ next to the PNG and rasterize it with preview.py (no GPU needed)."""
    import subprocess
    obj_path = os.path.splitext(path)[0] + ".obj"
    export_obj(obj_path, objs)
    subprocess.run(["python3", os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview.py"), obj_path, path], check=False)
    return

def render_workbench(path, objs, size=(900, 700), distance=None, elevation=0.35, azimuth=0.8):
    """Workbench render (needs OpenGL libs) for previews."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = path
    # frame all objects
    xs, ys, zs = [], [], []
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            xs.append(w.x); ys.append(w.y); zs.append(w.z)
    center = Vector(((min(xs)+max(xs))/2, (min(ys)+max(ys))/2, (min(zs)+max(zs))/2))
    extent = max(max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs))
    dist = distance or extent * 1.6 + 2
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = center + Vector((math.cos(azimuth) * dist, math.sin(azimuth) * dist, dist * elevation))
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    bpy.ops.render.render(write_still=True)

# ---------- the material library (tools/textures): UVs and render-time PBR ----------
TEX = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "textures", "out")
# studs per texture repeat; keep in step with Assets.Surfaces[name].Tile
TILE = {"CarBody": 8.0, "CarLivery": 8.0, "CarPanel": 6.0, "CarFloor": 4.0, "Moquette": 2.5, "SeatShell": 4.0,
        "Stainless": 3.0, "Underframe": 6.0, "Gunmetal": 1.5, "Polymer": 1.0, "Waxcloth": 2.5, "HideLeather": 1.5,
        "CarTrim": 4.0, "Techcloth": 2.0, "Twill": 1.5, "Gauze": 1.2, "PlateSteel": 2.0, "Flesh": 2.0}

def uv_box(ob, tile=None):
    """World-scale box mapping: each face takes the two axes across its normal, so every model that uses a
    library material shows it at the same size (one repeat per TILE[material] studs)."""
    name = ob.name.rsplit("_", 1)[-1]
    tile = tile or TILE.get(name, 4.0)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv = bm.loops.layers.uv.verify()
    M = ob.matrix_world
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        flip = -1 if n[ax] < 0 else 1
        for l in f.loops:
            w = M @ l.vert.co
            u = w[a] * (flip if ax != 2 else 1)
            v = w[b] * (1 if ax != 2 else flip)
            l[uv].uv = (u / tile, v / tile)
    bm.to_mesh(ob.data)
    bm.free()

def pbr_swap(objs):
    """For renders: give every object whose name ends in a library material that material's textures."""
    cache = {}
    for ob in objs:
        name = ob.name.split(".")[0].rsplit("_", 1)[-1]
        if not os.path.exists(os.path.join(TEX, f"{name}_col.png")):
            continue
        if name not in cache:
            m = bpy.data.materials.new("PBR_" + name)
            m.use_nodes = True
            nt = m.node_tree
            b = nt.nodes["Principled BSDF"]
            def tex(kind, noncolor=True):
                n = nt.nodes.new("ShaderNodeTexImage")
                n.image = bpy.data.images.load(os.path.join(TEX, f"{name}_{kind}.png"), check_existing=True)
                if noncolor:
                    n.image.colorspace_settings.name = "Non-Color"
                return n
            nt.links.new(tex("col", False).outputs["Color"], b.inputs["Base Color"])
            nt.links.new(tex("rgh").outputs["Color"], b.inputs["Roughness"])
            nt.links.new(tex("mtl").outputs["Color"], b.inputs["Metallic"])
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(tex("nrm").outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
            cache[name] = m
        ob.data.materials.clear()
        ob.data.materials.append(cache[name])
