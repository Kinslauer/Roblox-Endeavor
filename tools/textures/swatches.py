# One small plane per library material carrying its four maps, for upload. Roblox turns the maps of an uploaded
# model into a SurfaceAppearance; common/SurfaceLibrary.lua copies that onto every MeshPart named "<Part>_<Name>".
# Run: blender -b --python tools/textures/swatches.py [-- Name ...] -> tools/textures/out/Swatch_<Name>.glb
# (glTF carries metal/rough/normal unambiguously; the upload script sends .glb as model/gltf-binary).
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models"))
from lib import *
import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
names = argv or sorted(TILE)
for name in names:
    reset()
    bpy.ops.mesh.primitive_plane_add(size=4)
    ob = bpy.context.active_object
    ob.name = f"Swatch_{name}"
    ob.data.materials.append(material(name, (0.5, 0.5, 0.5)))
    pbr_swap([ob])
    ob.name = f"Swatch_{name}"
    path = os.path.join(TEX, f"Swatch_{name}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_image_format="AUTO")
    print("SWATCH", name, path)
