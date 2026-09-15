import bpy
import math
import os

WORKSPACE_DIR = "/Users/subhash/Games"
ENV_DIR = os.path.join(WORKSPACE_DIR, "assets/sprites/environment")
PROPS_DIR = os.path.join(WORKSPACE_DIR, "assets/sprites/props")
os.makedirs(ENV_DIR, exist_ok=True)
os.makedirs(PROPS_DIR, exist_ok=True)

def create_roman_pillar_asset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # Plinth (Base)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.2, 0))
    base = bpy.context.active_object
    base.scale = (0.7, 0.7, 0.4)
    bpy.ops.object.transform_apply(scale=True)
    
    # Fluted Shaft
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.42, depth=3.8, location=(0, 2.3, 0))
    shaft = bpy.context.active_object
    
    # Torus Ring collar
    bpy.ops.mesh.primitive_torus_add(major_radius=0.46, minor_radius=0.06, location=(0, 4.2, 0))
    collar = bpy.context.active_object
    
    # Capital (Top)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 4.45, 0))
    capital = bpy.context.active_object
    capital.scale = (0.75, 0.75, 0.35)
    bpy.ops.object.transform_apply(scale=True)
    
    # Join parts
    for obj in [base, collar, capital]:
        obj.select_set(True)
    shaft.select_set(True)
    bpy.context.view_layer.objects.active = shaft
    bpy.ops.object.join()
    pillar = bpy.context.active_object
    pillar.name = "RomanPillar"
    
    # Material: Aged Roman Marble
    mat = bpy.data.materials.new("RomanMarble")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.85, 0.83, 0.80, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.55
    pillar.data.materials.append(mat)
    
    out_path = os.path.join(PROPS_DIR, "roman_pillar.glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("Exported:", out_path)

def create_roman_aqueduct_asset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # Main arch span: Width 14m, Height 7.5m, Depth 1.8m
    # Left Pier
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-6.2, 3.5, 0))
    p_left = bpy.context.active_object
    p_left.scale = (1.4, 1.8, 7.0)
    bpy.ops.object.transform_apply(scale=True)
    
    # Right Pier
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(6.2, 3.5, 0))
    p_right = bpy.context.active_object
    p_right.scale = (1.4, 1.8, 7.0)
    bpy.ops.object.transform_apply(scale=True)
    
    # Top Conduit Lintel
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 7.3, 0))
    lintel = bpy.context.active_object
    lintel.scale = (14.0, 1.8, 1.2)
    bpy.ops.object.transform_apply(scale=True)
    
    # Decorative Keystone
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 6.7, 0))
    keystone = bpy.context.active_object
    keystone.scale = (1.0, 2.0, 0.6)
    bpy.ops.object.transform_apply(scale=True)
    
    # Join
    for obj in [p_right, lintel, keystone]:
        obj.select_set(True)
    p_left.select_set(True)
    bpy.context.view_layer.objects.active = p_left
    bpy.ops.object.join()
    aqueduct = bpy.context.active_object
    aqueduct.name = "RomanAqueduct"
    
    mat = bpy.data.materials.new("AqueductStone")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.72, 0.68, 0.63, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.8
    aqueduct.data.materials.append(mat)
    
    out_path = os.path.join(PROPS_DIR, "roman_aqueduct.glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("Exported:", out_path)

def create_brazier_asset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # Pedestal
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.35, depth=1.2, location=(0, 0.6, 0))
    stand = bpy.context.active_object
    
    # Fire Bowl
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.55, depth=0.3, location=(0, 1.3, 0))
    bowl = bpy.context.active_object
    
    # Embers
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.38, location=(0, 1.42, 0))
    coals = bpy.context.active_object
    coals.scale = (1.0, 1.0, 0.45)
    bpy.ops.object.transform_apply(scale=True)
    
    for obj in [bowl, coals]:
        obj.select_set(True)
    stand.select_set(True)
    bpy.context.view_layer.objects.active = stand
    bpy.ops.object.join()
    brazier = bpy.context.active_object
    brazier.name = "RomanBrazier"
    
    mat = bpy.data.materials.new("BronzeFire")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.35, 0.25, 0.15, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.85
    bsdf.inputs["Roughness"].default_value = 0.4
    brazier.data.materials.append(mat)
    
    out_path = os.path.join(PROPS_DIR, "curbside_brazier.glb")
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("Exported:", out_path)

def render_cinematic_menu_backdrop():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.image_settings.file_format = 'PNG'
    
    # Camera
    cam_data = bpy.data.cameras.new("MenuCam")
    cam_data.lens = 32
    cam_obj = bpy.data.objects.new("MenuCam", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    cam_obj.location = (0, -14, 2.8)
    cam_obj.rotation_euler = (math.radians(82), 0, 0)
    
    # World lighting: Golden Hour / Twilight
    world = bpy.data.worlds.new("TwilightWorld")
    world.use_nodes = True
    scene.world = world
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.12, 0.08, 0.18, 1.0)
    bg.inputs["Strength"].default_value = 0.4
    
    # Directional Sun at horizon
    sun_data = bpy.data.lights.new("GoldenSun", type='SUN')
    sun_data.energy = 4.5
    sun_data.color = (1.0, 0.65, 0.3)
    sun_obj = bpy.data.objects.new("GoldenSun", sun_data)
    sun_obj.rotation_euler = (math.radians(12), math.radians(10), math.radians(-30))
    scene.collection.objects.link(sun_obj)
    
    # Backdrop Ground Plane
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 15, -0.1))
    ground = bpy.context.active_object
    g_mat = bpy.data.materials.new("GroundMat")
    g_mat.use_nodes = True
    g_bsdf = g_mat.node_tree.nodes.get("Principled BSDF")
    g_bsdf.inputs["Base Color"].default_value = (0.07, 0.06, 0.09, 1.0)
    ground.data.materials.append(g_mat)
    
    # Central Grand Highway
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 15, 0))
    road = bpy.context.active_object
    road.scale = (8.0, 60.0, 0.2)
    bpy.ops.object.transform_apply(scale=True)
    r_mat = bpy.data.materials.new("RoadMat")
    r_mat.use_nodes = True
    r_bsdf = r_mat.node_tree.nodes.get("Principled BSDF")
    r_bsdf.inputs["Base Color"].default_value = (0.22, 0.20, 0.23, 1.0)
    r_bsdf.inputs["Roughness"].default_value = 0.4
    road.data.materials.append(r_mat)
    
    # Colonnade of Roman Pillars along both sides
    for side in [-5.5, 5.5]:
        for z_i in range(8):
            z_y = -6 + z_i * 6.0
            # Pillar
            bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.45, depth=5.5, location=(side, z_y, 2.75))
            p = bpy.context.active_object
            p_mat = bpy.data.materials.new(f"P_Mat_{side}_{z_i}")
            p_mat.use_nodes = True
            p_bsdf = p_mat.node_tree.nodes.get("Principled BSDF")
            p_bsdf.inputs["Base Color"].default_value = (0.75, 0.70, 0.65, 1.0)
            p.data.materials.append(p_mat)
            
            # Capital
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(side, z_y, 5.6))
            cap = bpy.context.active_object
            cap.scale = (1.2, 1.2, 0.4)
            cap.data.materials.append(p_mat)
    
    # Architrave Entablature beam atop pillars
    for side in [-5.5, 5.5]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(side, 15, 5.9))
        beam = bpy.context.active_object
        beam.scale = (1.2, 50.0, 0.4)
        b_mat = bpy.data.materials.new(f"BeamMat_{side}")
        b_mat.use_nodes = True
        b_bsdf = b_mat.node_tree.nodes.get("Principled BSDF")
        b_bsdf.inputs["Base Color"].default_value = (0.80, 0.75, 0.70, 1.0)
        beam.data.materials.append(b_mat)

    # Distant Glowing Temporal Rift Ring at end of highway
    bpy.ops.mesh.primitive_torus_add(major_radius=6.0, minor_radius=0.4, location=(0, 36, 6.0))
    rift = bpy.context.active_object
    rift.rotation_euler = (math.radians(90), 0, 0)
    rift_mat = bpy.data.materials.new("RiftPortal")
    rift_mat.use_nodes = True
    rift_bsdf = rift_mat.node_tree.nodes.get("Principled BSDF")
    rift_bsdf.inputs["Emission Color"].default_value = (1.0, 0.75, 0.25, 1.0)
    rift_bsdf.inputs["Emission Strength"].default_value = 8.0
    rift.data.materials.append(rift_mat)
    
    # Inner glowing vortex disc
    bpy.ops.mesh.primitive_circle_add(radius=5.8, fill_type='NGON', location=(0, 36, 6.0))
    disc = bpy.context.active_object
    disc.rotation_euler = (math.radians(90), 0, 0)
    d_mat = bpy.data.materials.new("VortexDisc")
    d_mat.use_nodes = True
    d_bsdf = d_mat.node_tree.nodes.get("Principled BSDF")
    d_bsdf.inputs["Emission Color"].default_value = (0.95, 0.45, 0.15, 1.0)
    d_bsdf.inputs["Emission Strength"].default_value = 4.0
    disc.data.materials.append(d_mat)
    
    # Point Light at Rift
    rift_light_data = bpy.data.lights.new("RiftLight", type='POINT')
    rift_light_data.energy = 800.0
    rift_light_data.color = (1.0, 0.7, 0.3)
    rift_light_obj = bpy.data.objects.new("RiftLight", rift_light_data)
    rift_light_obj.location = (0, 34, 6.0)
    scene.collection.objects.link(rift_light_obj)
    
    # Colosseum / Distant Ruin Silhouette in horizon
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=18.0, depth=14.0, location=(16, 48, 7.0))
    colosseum = bpy.context.active_object
    c_mat = bpy.data.materials.new("ColosseumMat")
    c_mat.use_nodes = True
    c_bsdf = c_mat.node_tree.nodes.get("Principled BSDF")
    c_bsdf.inputs["Base Color"].default_value = (0.10, 0.08, 0.12, 1.0)
    colosseum.data.materials.append(c_mat)
    
    out_img = os.path.join(ENV_DIR, "main_menu_backdrop.png")
    scene.render.filepath = out_img
    bpy.ops.render.render(write_still=True)
    print("Rendered Main Menu Backdrop to:", out_img)

if __name__ == "__main__":
    create_roman_pillar_asset()
    create_roman_aqueduct_asset()
    create_brazier_asset()
    render_cinematic_menu_backdrop()
