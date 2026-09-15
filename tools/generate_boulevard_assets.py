import bpy
import math
import os

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_mat(name, color, metallic=0.0, roughness=0.4, emit_color=(0,0,0,1), emit_val=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = color
        bsdf.inputs['Metallic'].default_value = metallic
        bsdf.inputs['Roughness'].default_value = roughness
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = emit_color
            bsdf.inputs['Emission Strength'].default_value = emit_val
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value = emit_color
    return mat

def apply_mat(obj, mat):
    if not obj.data.materials:
        obj.data.materials.append(mat)
    else:
        obj.data.materials[0] = mat

def smooth_object(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth()

def add_bevel(obj, width=0.03, segments=2):
    bev = obj.modifiers.new("Bevel", 'BEVEL')
    bev.width = width
    bev.segments = segments

def add_subsurf(obj, levels=1):
    sub = obj.modifiers.new("Subsurf", 'SUBSURF')
    sub.levels = levels
    sub.render_levels = levels

def add_cube(name, loc, scale, mat=None, rot=(0,0,0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0:
        add_bevel(obj, width=bevel)
    smooth_object(obj)
    if mat:
        apply_mat(obj, mat)
    return obj

def add_cylinder(name, loc, radius, depth, mat=None, rot=(0,0,0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    smooth_object(obj)
    if mat:
        apply_mat(obj, mat)
    return obj

def add_sphere(name, loc, radius, mat=None, rot=(0,0,0), segs=28, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=radius, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    smooth_object(obj)
    if mat:
        apply_mat(obj, mat)
    return obj

def setup_studio(cam_pos=(0, -2.5, 1.15), cam_rot=(math.radians(82), 0, 0), ortho=False):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = 'ORTHO' if ortho else 'PERSP'
    if ortho:
        cam_data.ortho_scale = 2.0
    else:
        cam_data.lens = 52
    cam_obj = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    cam_obj.location = cam_pos
    cam_obj.rotation_euler = cam_rot
    bpy.context.scene.camera = cam_obj

    # Main sunlight (warm golden sunlight from top right)
    sun_data = bpy.data.lights.new("Sun", 'SUN')
    sun_data.energy = 5.5
    sun_data.color = (1.0, 0.95, 0.88)
    sun_obj = bpy.data.objects.new("Sun", sun_data)
    bpy.context.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(55), math.radians(20), math.radians(-30))

    # Fill light (soft sky blue fill)
    fill_data = bpy.data.lights.new("Fill", 'SUN')
    fill_data.energy = 2.4
    fill_data.color = (0.78, 0.88, 1.0)
    fill_obj = bpy.data.objects.new("Fill", fill_data)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(45), math.radians(-25), math.radians(150))

    # Rim light for edge pop
    rim_data = bpy.data.lights.new("Rim", 'POINT')
    rim_data.energy = 45.0
    rim_data.color = (1.0, 0.98, 0.95)
    rim_obj = bpy.data.objects.new("Rim", rim_data)
    rim_obj.location = (0, 1.8, 1.4)
    bpy.context.collection.objects.link(rim_obj)

    scene = bpy.context.scene
    scene.render.film_transparent = True
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

def render_out(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print(f"Rendered: {path}")

def export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False, export_apply=True)
    print(f"Exported: {path}")

# =========================================================================
# 1. CHIBI LEADER
# =========================================================================
def build_chibi_leader(pose="run1"):
    clear_scene()
    
    mat_skin = create_mat("Skin", (0.86, 0.65, 0.50, 1.0), roughness=0.5)
    mat_hair = create_mat("Hair", (0.07, 0.06, 0.06, 1.0), roughness=0.7)
    mat_cap = create_mat("Cap", (0.97, 0.97, 0.96, 1.0), roughness=0.3)
    mat_kurta = create_mat("Kurta", (0.95, 0.95, 0.94, 1.0), roughness=0.4)
    mat_sash = create_mat("Sash", (0.88, 0.10, 0.12, 1.0), roughness=0.3)
    mat_pants = create_mat("Pants", (0.93, 0.93, 0.92, 1.0), roughness=0.4)
    mat_shoe = create_mat("Shoe", (0.32, 0.19, 0.12, 1.0), roughness=0.4)
    mat_sole = create_mat("Sole", (0.96, 0.96, 0.95, 1.0), roughness=0.3)

    root_z = 0.0
    if pose == "jump":
        root_z = 0.25
    elif pose == "slide":
        root_z = -0.32

    # Head
    head_z = 1.15 + root_z
    if pose == "slide":
        head_z = 0.82
    head = add_sphere("Head", (0, 0, head_z), 0.32, mat_skin, segs=32, rings=24)
    head.scale = (1.0, 0.95, 1.05)

    # Hair (Dark wavy volume around back and sides)
    hair = add_sphere("Hair", (0, -0.05, head_z + 0.02), 0.34, mat_hair, segs=32, rings=24)
    hair.scale = (1.02, 0.98, 0.95)

    # Hair curls on back of neck
    for hx in [-0.22, -0.11, 0.0, 0.11, 0.22]:
        add_sphere(f"HairCurl_{hx}", (hx, -0.16, head_z - 0.12), 0.11, mat_hair, segs=16, rings=12)

    # Ears
    add_sphere("EarL", (-0.31, 0, head_z - 0.02), 0.07, mat_skin)
    add_sphere("EarR", (0.31, 0, head_z - 0.02), 0.07, mat_skin)

    # White Gandhi / Nehru Boat Cap (Sculpted folded boat cap)
    cap_z = head_z + 0.22
    # Base boat cap
    cap = add_cube("CapBase", (0, 0.01, cap_z), (0.22, 0.30, 0.10), mat_cap, bevel=0.03)
    # Creased top crown
    cap_top = add_cube("CapTop", (0, 0.01, cap_z + 0.08), (0.08, 0.28, 0.05), mat_cap, bevel=0.02)

    # Neck
    add_cylinder("Neck", (0, 0, head_z - 0.22), radius=0.10, depth=0.12, mat=mat_skin)

    # Torso (Kurta)
    torso_z = 0.72 + root_z
    if pose == "slide":
        torso_z = 0.52
        torso = add_cube("Torso", (0, -0.10, torso_z), (0.24, 0.18, 0.28), mat_kurta, rot=(math.radians(22), 0, 0), bevel=0.04)
        skirt = add_cube("Skirt", (0, -0.16, torso_z - 0.22), (0.26, 0.20, 0.16), mat_kurta, rot=(math.radians(22), 0, 0), bevel=0.03)
    else:
        torso = add_cube("Torso", (0, 0, torso_z), (0.24, 0.17, 0.28), mat_kurta, bevel=0.04)
        skirt = add_cube("Skirt", (0, 0, torso_z - 0.22), (0.26, 0.19, 0.16), mat_kurta, bevel=0.03)

    # Red Diagonal Sash (Uttariya) draped over left shoulder down to right hip across the back
    sash_segs = [
        (-0.20, -0.11, torso_z + 0.20),
        (-0.10, -0.12, torso_z + 0.08),
        (0.02, -0.12, torso_z - 0.04),
        (0.14, -0.11, torso_z - 0.15),
        (0.22, -0.09, torso_z - 0.24)
    ]
    for i, pt in enumerate(sash_segs):
        add_cube(f"Sash_{i}", pt, (0.07, 0.025, 0.07), mat_sash, rot=(0, math.radians(35), 0), bevel=0.01)
    # Fluttering sash tail hanging off right hip
    add_cube("SashTail", (0.25, -0.13, torso_z - 0.32), (0.05, 0.025, 0.14), mat_sash, rot=(math.radians(-15), math.radians(15), 0), bevel=0.01)

    # Limbs and poses
    if pose == "run1":
        # Left foot forward, Right foot back kicked up
        add_cylinder("ThighL", (-0.14, 0.08, 0.40), radius=0.08, depth=0.24, mat=mat_pants, rot=(math.radians(-30), 0, 0))
        add_cylinder("ShinL", (-0.14, 0.15, 0.22), radius=0.07, depth=0.22, mat=mat_pants, rot=(math.radians(-8), 0, 0))
        add_cube("ShoeL", (-0.14, 0.18, 0.09), (0.08, 0.14, 0.06), mat_shoe, bevel=0.02)
        add_cube("SoleL", (-0.14, 0.18, 0.04), (0.085, 0.145, 0.02), mat_sole, bevel=0.01)

        add_cylinder("ThighR", (0.14, -0.10, 0.42), radius=0.08, depth=0.24, mat=mat_pants, rot=(math.radians(40), 0, 0))
        add_cylinder("ShinR", (0.14, -0.22, 0.32), radius=0.07, depth=0.22, mat=mat_pants, rot=(math.radians(80), 0, 0))
        add_cube("ShoeR", (0.14, -0.34, 0.35), (0.08, 0.14, 0.06), mat_shoe, rot=(math.radians(65), 0, 0), bevel=0.02)
        add_cube("SoleR", (0.14, -0.34, 0.31), (0.085, 0.145, 0.02), mat_sole, rot=(math.radians(65), 0, 0), bevel=0.01)

        # Arms: Left back, Right forward
        add_cylinder("ArmL", (-0.29, -0.10, 0.70), radius=0.06, depth=0.26, mat=mat_kurta, rot=(math.radians(35), 0, 0))
        add_sphere("HandL", (-0.29, -0.19, 0.58), 0.055, mat_skin)
        add_cylinder("ArmR", (0.29, 0.10, 0.70), radius=0.06, depth=0.26, mat=mat_kurta, rot=(math.radians(-35), 0, 0))
        add_sphere("HandR", (0.29, 0.19, 0.58), 0.055, mat_skin)

    elif pose == "run2":
        # Right foot forward, Left foot back kicked up
        add_cylinder("ThighR", (0.14, 0.08, 0.40), radius=0.08, depth=0.24, mat=mat_pants, rot=(math.radians(-30), 0, 0))
        add_cylinder("ShinR", (0.14, 0.15, 0.22), radius=0.07, depth=0.22, mat=mat_pants, rot=(math.radians(-8), 0, 0))
        add_cube("ShoeR", (0.14, 0.18, 0.09), (0.08, 0.14, 0.06), mat_shoe, bevel=0.02)
        add_cube("SoleR", (0.14, 0.18, 0.04), (0.085, 0.145, 0.02), mat_sole, bevel=0.01)

        add_cylinder("ThighL", (-0.14, -0.10, 0.42), radius=0.08, depth=0.24, mat=mat_pants, rot=(math.radians(40), 0, 0))
        add_cylinder("ShinL", (-0.14, -0.22, 0.32), radius=0.07, depth=0.22, mat=mat_pants, rot=(math.radians(80), 0, 0))
        add_cube("ShoeL", (-0.14, -0.34, 0.35), (0.08, 0.14, 0.06), mat_shoe, rot=(math.radians(65), 0, 0), bevel=0.02)
        add_cube("SoleL", (-0.14, -0.34, 0.31), (0.085, 0.145, 0.02), mat_sole, rot=(math.radians(65), 0, 0), bevel=0.01)

        # Arms: Right back, Left forward
        add_cylinder("ArmR", (0.29, -0.10, 0.70), radius=0.06, depth=0.26, mat=mat_kurta, rot=(math.radians(35), 0, 0))
        add_sphere("HandR", (0.29, -0.19, 0.58), 0.055, mat_skin)
        add_cylinder("ArmL", (-0.29, 0.10, 0.70), radius=0.06, depth=0.26, mat=mat_kurta, rot=(math.radians(-35), 0, 0))
        add_sphere("HandL", (-0.29, 0.19, 0.58), 0.055, mat_skin)

    elif pose == "jump":
        # Jump: knees tucked, shoes dangling, arms spread
        add_cylinder("ThighL", (-0.14, 0.06, 0.62), radius=0.08, depth=0.22, mat=mat_pants, rot=(math.radians(-45), 0, 0))
        add_cylinder("ShinL", (-0.14, -0.04, 0.48), radius=0.07, depth=0.22, mat=mat_pants, rot=(math.radians(35), 0, 0))
        add_cube("ShoeL", (-0.14, -0.06, 0.35), (0.08, 0.14, 0.06), mat_shoe, bevel=0.02)
        add_cube("SoleL", (-0.14, -0.06, 0.30), (0.085, 0.145, 0.02), mat_sole, bevel=0.01)

        add_cylinder("ThighR", (0.14, 0.06, 0.62), radius=0.08, depth=0.22, mat=mat_pants, rot=(math.radians(-45), 0, 0))
        add_cylinder("ShinR", (0.14, -0.04, 0.48), radius=0.07, depth=0.22, mat=mat_pants, rot=(math.radians(35), 0, 0))
        add_cube("ShoeR", (0.14, -0.06, 0.35), (0.08, 0.14, 0.06), mat_shoe, bevel=0.02)
        add_cube("SoleR", (0.14, -0.06, 0.30), (0.085, 0.145, 0.02), mat_sole, bevel=0.01)

        add_cylinder("ArmL", (-0.32, 0, 0.94), radius=0.06, depth=0.26, mat=mat_kurta, rot=(0, math.radians(-45), 0))
        add_sphere("HandL", (-0.42, 0, 1.04), 0.055, mat_skin)
        add_cylinder("ArmR", (0.32, 0, 0.94), radius=0.06, depth=0.26, mat=mat_kurta, rot=(0, math.radians(45), 0))
        add_sphere("HandR", (0.42, 0, 1.04), 0.055, mat_skin)

    elif pose == "slide":
        # Slide: legs forward, body tilted back
        add_cylinder("ThighL", (-0.14, 0.15, 0.28), radius=0.08, depth=0.24, mat=mat_pants, rot=(math.radians(-75), 0, 0))
        add_cylinder("ShinL", (-0.14, 0.36, 0.18), radius=0.07, depth=0.22, mat=mat_pants, rot=(math.radians(-85), 0, 0))
        add_cube("ShoeL", (-0.14, 0.52, 0.11), (0.08, 0.14, 0.06), mat_shoe, rot=(math.radians(-15), 0, 0), bevel=0.02)
        add_cube("SoleL", (-0.14, 0.52, 0.06), (0.085, 0.145, 0.02), mat_sole, rot=(math.radians(-15), 0, 0), bevel=0.01)

        add_cylinder("ThighR", (0.14, 0.15, 0.28), radius=0.08, depth=0.24, mat=mat_pants, rot=(math.radians(-75), 0, 0))
        add_cylinder("ShinR", (0.14, 0.36, 0.18), radius=0.07, depth=0.22, mat=mat_pants, rot=(math.radians(-85), 0, 0))
        add_cube("ShoeR", (0.14, 0.52, 0.11), (0.08, 0.14, 0.06), mat_shoe, rot=(math.radians(-15), 0, 0), bevel=0.02)
        add_cube("SoleR", (0.14, 0.52, 0.06), (0.085, 0.145, 0.02), mat_sole, rot=(math.radians(-15), 0, 0), bevel=0.01)

        add_cylinder("ArmL", (-0.28, -0.20, 0.38), radius=0.06, depth=0.24, mat=mat_kurta, rot=(math.radians(45), 0, 0))
        add_sphere("HandL", (-0.28, -0.28, 0.26), 0.055, mat_skin)
        add_cylinder("ArmR", (0.28, -0.20, 0.38), radius=0.06, depth=0.24, mat=mat_kurta, rot=(math.radians(45), 0, 0))
        add_sphere("HandR", (0.28, -0.28, 0.26), 0.055, mat_skin)

# =========================================================================
# 2. MOVING BULL CART (Normal People Faction Obstacle)
# =========================================================================
def build_bull_cart():
    clear_scene()

    mat_wood = create_mat("CartWood", (0.50, 0.32, 0.18, 1.0), roughness=0.7)
    mat_dark_wood = create_mat("CartDarkWood", (0.35, 0.21, 0.12, 1.0), roughness=0.8)
    mat_iron = create_mat("CartIron", (0.22, 0.22, 0.24, 1.0), metallic=0.7, roughness=0.4)
    mat_hay = create_mat("Hay", (0.85, 0.72, 0.35, 1.0), roughness=0.9)
    mat_sack = create_mat("Sack", (0.75, 0.65, 0.50, 1.0), roughness=0.8)
    mat_clay = create_mat("ClayPot", (0.78, 0.38, 0.22, 1.0), roughness=0.6)
    mat_ox_skin = create_mat("OxSkin", (0.92, 0.90, 0.86, 1.0), roughness=0.7)
    mat_horn = create_mat("OxHorn", (0.28, 0.24, 0.20, 1.0), roughness=0.4)
    mat_rope = create_mat("Rope", (0.68, 0.58, 0.42, 1.0), roughness=0.9)

    # 1. Wheels (2 large spoked wheels)
    for wx in [-1.15, 1.15]:
        # Iron rim
        add_cylinder(f"WheelRim_{wx}", (wx, 0, 0.75), radius=0.75, depth=0.10, mat=mat_iron, rot=(0, math.radians(90), 0))
        # Inner wood rim
        add_cylinder(f"WheelWood_{wx}", (wx, 0, 0.75), radius=0.71, depth=0.09, mat=mat_wood, rot=(0, math.radians(90), 0))
        # Central hub
        add_cylinder(f"WheelHub_{wx}", (wx, 0, 0.75), radius=0.18, depth=0.18, mat=mat_dark_wood, rot=(0, math.radians(90), 0))
        # Spokes (8 spokes)
        for s in range(8):
            ang = s * (math.pi / 4)
            add_cylinder(f"Spoke_{wx}_{s}", (wx, 0.35 * math.cos(ang), 0.75 + 0.35 * math.sin(ang)), radius=0.03, depth=0.68, mat=mat_wood, rot=(ang, 0, 0))

    # Axle connecting wheels
    add_cylinder("Axle", (0, 0, 0.75), radius=0.07, depth=2.4, mat=mat_iron, rot=(0, math.radians(90), 0))

    # Wooden Cart Bed Platform
    add_cube("BedPlatform", (0, 0, 0.85), (1.90, 2.4, 0.12), mat_wood, bevel=0.03)

    # Side railings (slatted wood)
    for sx in [-0.95, 0.95]:
        # Bottom rail
        add_cube(f"SideRail_Bot_{sx}", (sx, 0, 0.95), (0.08, 2.4, 0.08), mat_dark_wood)
        # Top rail
        add_cube(f"SideRail_Top_{sx}", (sx, 0, 1.35), (0.08, 2.4, 0.08), mat_dark_wood)
        # Vertical slats
        for sy in [-1.0, -0.6, -0.2, 0.2, 0.6, 1.0]:
            add_cube(f"SideSlat_{sx}_{sy}", (sx, sy, 1.15), (0.06, 0.08, 0.40), mat_wood)

    # Back tailgate
    add_cube("TailgateTop", (0, -1.2, 1.35), (1.90, 0.08, 0.08), mat_dark_wood)
    for bx in [-0.7, -0.35, 0.0, 0.35, 0.7]:
        add_cube(f"TailSlat_{bx}", (bx, -1.2, 1.15), (0.08, 0.06, 0.40), mat_wood)

    # Cargo on Cart:
    # Straw / Hay bales
    add_cube("HayBale1", (-0.45, -0.5, 1.15), (0.75, 0.9, 0.5), mat_hay, bevel=0.05)
    add_cube("HayBale2", (-0.40, -0.4, 1.55), (0.65, 0.8, 0.4), mat_hay, rot=(0,0,math.radians(10)), bevel=0.05)

    # Sacks of grain / flour
    add_sphere("GrainSack1", (0.45, -0.4, 1.12), 0.32, mat_sack)
    add_sphere("GrainSack2", (0.40, 0.3, 1.12), 0.30, mat_sack)
    add_sphere("GrainSack3", (0.42, -0.05, 1.45), 0.28, mat_sack)

    # Terracotta Clay Water Pots (Matkas)
    for px, py in [(0.0, 0.6), (-0.45, 0.65)]:
        pot_body = add_sphere(f"ClayPot_{px}", (px, py, 1.10), 0.22, mat_clay)
        pot_body.scale = (1.0, 1.0, 1.2)
        add_cylinder(f"PotNeck_{px}", (px, py, 1.30), radius=0.10, depth=0.08, mat=mat_clay)
        add_cylinder(f"PotRim_{px}", (px, py, 1.35), radius=0.13, depth=0.04, mat=mat_clay)

    # Front Draft Beams / Yoke Pole
    add_cylinder("DraftBeamL", (-0.45, 1.9, 0.75), radius=0.06, depth=1.8, mat=mat_wood, rot=(math.radians(85), 0, 0))
    add_cylinder("DraftBeamR", (0.45, 1.9, 0.75), radius=0.06, depth=1.8, mat=mat_wood, rot=(math.radians(85), 0, 0))
    # Yoke crossbar
    add_cylinder("YokeCrossbar", (0, 2.7, 0.90), radius=0.07, depth=1.8, mat=mat_dark_wood, rot=(0, math.radians(90), 0))

    # Stylized White Bullock / Ox
    # Body
    ox_body = add_sphere("OxBody", (0, 3.4, 0.95), 0.45, mat_ox_skin)
    ox_body.scale = (0.75, 1.3, 0.85)
    # Hump on back
    add_sphere("OxHump", (0, 3.15, 1.35), 0.24, mat_ox_skin)
    # Neck and Head
    add_cylinder("OxNeck", (0, 4.0, 1.15), radius=0.22, depth=0.45, mat=mat_ox_skin, rot=(math.radians(35), 0, 0))
    ox_head = add_sphere("OxHead", (0, 4.25, 1.30), 0.26, mat_ox_skin)
    ox_head.scale = (0.8, 1.1, 0.85)
    # Snout
    add_sphere("OxSnout", (0, 4.45, 1.18), 0.16, mat_skin if 'mat_skin' in locals() else mat_ox_skin)
    # Horns (curved upward/outward)
    for hx in [-0.22, 0.22]:
        add_cylinder(f"Horn_{hx}", (hx, 4.25, 1.55), radius=0.045, depth=0.35, mat=mat_horn, rot=(math.radians(-25), math.radians(30 if hx>0 else -30), 0))
    # Ears
    add_sphere("OxEarL", (-0.26, 4.15, 1.32), 0.09, mat_ox_skin)
    add_sphere("OxEarR", (0.26, 4.15, 1.32), 0.09, mat_ox_skin)
    # 4 Legs
    for lx, ly in [(-0.25, 3.0), (0.25, 3.0), (-0.25, 3.8), (0.25, 3.8)]:
        add_cylinder(f"OxLeg_{lx}_{ly}", (lx, ly, 0.45), radius=0.08, depth=0.85, mat=mat_ox_skin)
        add_cylinder(f"OxHoof_{lx}_{ly}", (lx, ly, 0.06), radius=0.09, depth=0.12, mat=mat_horn)
    # Halter rope / harness
    add_cylinder("HarnessRope", (0, 3.3, 1.05), radius=0.03, depth=1.6, mat=mat_rope, rot=(0, math.radians(90), 0))

# =========================================================================
# 3. POLICE K9 DOG (Police Faction Hazard)
# =========================================================================
def build_police_dog():
    clear_scene()

    mat_fur_black = create_mat("DogBlack", (0.10, 0.09, 0.08, 1.0), roughness=0.7)
    mat_fur_tan = create_mat("DogTan", (0.72, 0.46, 0.24, 1.0), roughness=0.6)
    mat_vest = create_mat("PoliceVest", (0.05, 0.22, 0.58, 1.0), roughness=0.4)
    mat_stripe = create_mat("VestStripe", (0.95, 0.95, 0.20, 1.0), emit_color=(0.95, 0.95, 0.2, 1), emit_val=0.5)
    mat_nose = create_mat("DogNose", (0.04, 0.04, 0.04, 1.0), roughness=0.2)
    mat_tongue = create_mat("DogTongue", (0.85, 0.25, 0.35, 1.0), roughness=0.3)

    # Body (Torso)
    body = add_sphere("DogBody", (0, 0, 0.65), 0.32, mat_fur_tan)
    body.scale = (0.75, 1.35, 0.85)

    # Black saddle on back
    saddle = add_sphere("DogSaddle", (0, -0.05, 0.72), 0.30, mat_fur_black)
    saddle.scale = (0.72, 1.25, 0.75)

    # Tactical Police Vest / Harness
    vest = add_cube("PoliceVest", (0, 0.08, 0.70), (0.52, 0.55, 0.42), mat_vest, bevel=0.03)
    # Reflective yellow police stripes on sides
    add_cube("VestStripeL", (-0.27, 0.08, 0.70), (0.02, 0.48, 0.08), mat_stripe)
    add_cube("VestStripeR", (0.27, 0.08, 0.70), (0.02, 0.48, 0.08), mat_stripe)

    # Neck
    add_cylinder("DogNeck", (0, 0.42, 0.82), radius=0.16, depth=0.32, mat=mat_fur_tan, rot=(math.radians(35), 0, 0))

    # Head
    head = add_sphere("DogHead", (0, 0.58, 0.98), 0.20, mat_fur_tan)
    head.scale = (0.85, 1.0, 0.9)
    # Black mask over top of head & snout
    add_sphere("HeadMask", (0, 0.60, 1.02), 0.18, mat_fur_black)

    # Muzzle / Snout
    muzzle = add_cube("Muzzle", (0, 0.74, 0.94), (0.16, 0.22, 0.14), mat_fur_black, bevel=0.02)
    # Nose
    add_sphere("Nose", (0, 0.86, 0.96), 0.045, mat_nose)
    # Open jaw / tongue
    add_cube("LowerJaw", (0, 0.72, 0.86), (0.12, 0.18, 0.05), mat_fur_tan)
    add_cube("Tongue", (0, 0.76, 0.88), (0.08, 0.14, 0.03), mat_tongue, rot=(math.radians(-15), 0, 0))

    # Alert Pointed Ears
    for ex in [-0.14, 0.14]:
        ear = add_cylinder(f"Ear_{ex}", (ex, 0.54, 1.18), radius=0.06, depth=0.22, mat=mat_fur_black, rot=(math.radians(-15), math.radians(20 if ex>0 else -20), 0))
        ear.scale = (1.0, 0.4, 1.0)

    # Bushy Tail (alert high angle)
    tail = add_cylinder("DogTail", (0, -0.48, 0.82), radius=0.07, depth=0.45, mat=mat_fur_black, rot=(math.radians(-55), 0, 0))

    # 4 Athletic Legs
    for lx, ly, rot_x in [
        (-0.18, 0.28, math.radians(-15)),
        (0.18, 0.28, math.radians(15)),
        (-0.18, -0.25, math.radians(25)),
        (0.18, -0.25, math.radians(-25))
    ]:
        add_cylinder(f"Leg_{lx}_{ly}", (lx, ly, 0.32), radius=0.065, depth=0.55, mat=mat_fur_tan, rot=(rot_x, 0, 0))
        add_sphere(f"Paw_{lx}_{ly}", (lx, ly + (0.05 if rot_x < 0 else -0.05), 0.06), 0.075, mat_fur_tan)

# =========================================================================
# 4. POLICE RIOT BARRICADE (Steel barrier + 3 Riot Police with Shields)
# =========================================================================
def build_police_barricade():
    clear_scene()

    mat_blue_steel = create_mat("BarricadeSteel", (0.06, 0.25, 0.65, 1.0), metallic=0.6, roughness=0.3)
    mat_sign = create_mat("PoliceSign", (0.95, 0.95, 0.95, 1.0), roughness=0.3)
    mat_sign_text = create_mat("PoliceText", (0.06, 0.20, 0.55, 1.0), roughness=0.3)
    mat_cop_suit = create_mat("CopSuit", (0.10, 0.16, 0.26, 1.0), roughness=0.6)
    mat_helmet = create_mat("CopHelmet", (0.12, 0.14, 0.18, 1.0), metallic=0.3, roughness=0.2)
    mat_visor = create_mat("CopVisor", (0.15, 0.25, 0.40, 1.0), metallic=0.8, roughness=0.1)
    mat_shield = create_mat("RiotShield", (0.35, 0.55, 0.75, 1.0), metallic=0.4, roughness=0.2)

    # 1. Steel Barricade Frame
    add_cube("TopBar", (0, 0, 1.15), (2.6, 0.08, 0.08), mat_blue_steel)
    add_cube("BotBar", (0, 0, 0.15), (2.6, 0.08, 0.08), mat_blue_steel)
    add_cube("LeftPost", (-1.25, 0, 0.65), (0.08, 0.08, 1.0), mat_blue_steel)
    add_cube("RightPost", (1.25, 0, 0.65), (0.08, 0.08, 1.0), mat_blue_steel)
    # Legs / Feet
    for fx in [-1.15, 1.15]:
        add_cube(f"Foot_{fx}", (fx, 0, 0.06), (0.08, 0.70, 0.06), mat_blue_steel)

    # Front POLICE Plate
    add_cube("PolicePlate", (0, -0.06, 0.65), (1.8, 0.04, 0.45), mat_blue_steel, bevel=0.02)
    add_cube("PoliceWhitePlate", (0, -0.09, 0.65), (1.5, 0.02, 0.28), mat_sign)
    add_cube("PoliceTextBar", (0, -0.11, 0.65), (1.2, 0.02, 0.16), mat_sign_text)

    # 2. Three Riot Police Officers behind barricade
    for cx in [-0.75, 0.0, 0.75]:
        # Cop Torso
        add_cube(f"CopTorso_{cx}", (cx, 0.25, 1.05), (0.42, 0.30, 0.50), mat_cop_suit, bevel=0.03)
        # Tactical Vest
        add_cube(f"CopVest_{cx}", (cx, 0.22, 1.08), (0.44, 0.28, 0.38), mat_helmet, bevel=0.02)
        # Cop Head
        add_sphere(f"CopHead_{cx}", (cx, 0.25, 1.48), 0.18, mat_cop_suit)
        # Riot Helmet
        helmet = add_sphere(f"CopHelmet_{cx}", (cx, 0.25, 1.54), 0.21, mat_helmet)
        # Helmet Visor
        visor = add_cube(f"CopVisor_{cx}", (cx, 0.11, 1.48), (0.28, 0.08, 0.12), mat_visor, bevel=0.02)
        # Clear Polycarbonate Riot Shield in front
        add_cube(f"Shield_{cx}", (cx, 0.05, 0.95), (0.50, 0.04, 0.90), mat_shield, bevel=0.02)

# =========================================================================
# 5. WOODEN ROADBLOCK (Construction timber barricade with NO ENTRY sign)
# =========================================================================
def build_wooden_roadblock():
    clear_scene()

    mat_timber = create_mat("TimberWood", (0.55, 0.36, 0.20, 1.0), roughness=0.8)
    mat_cross = create_mat("CrossWood", (0.42, 0.26, 0.14, 1.0), roughness=0.9)
    mat_sign = create_mat("NoEntrySign", (0.92, 0.90, 0.85, 1.0), roughness=0.4)
    mat_sign_text = create_mat("SignRedText", (0.85, 0.12, 0.15, 1.0), roughness=0.4)
    mat_bolt = create_mat("IronBolt", (0.2, 0.2, 0.2, 1.0), metallic=0.8, roughness=0.3)

    # 2 Side A-Frame posts
    for px in [-1.1, 1.1]:
        # Slanted legs
        add_cube(f"LegF_{px}", (px, 0.25, 0.65), (0.12, 0.10, 1.3), mat_timber, rot=(math.radians(20), 0, 0))
        add_cube(f"LegB_{px}", (px, -0.25, 0.65), (0.12, 0.10, 1.3), mat_timber, rot=(math.radians(-20), 0, 0))
        # Cross tie
        add_cube(f"Tie_{px}", (px, 0, 0.35), (0.14, 0.45, 0.08), mat_cross)

    # Heavy horizontal crossbar planks
    add_cube("PlankTop", (0, 0, 1.05), (2.5, 0.08, 0.20), mat_timber, bevel=0.02)
    add_cube("PlankMid", (0, 0, 0.70), (2.5, 0.08, 0.20), mat_timber, bevel=0.02)
    add_cube("PlankBot", (0, 0, 0.35), (2.5, 0.08, 0.16), mat_timber, bevel=0.02)

    # Diagonal criss-cross timbers
    add_cube("DiagL", (0, -0.06, 0.70), (0.10, 0.06, 1.15), mat_cross, rot=(0, math.radians(48), 0))
    add_cube("DiagR", (0, -0.06, 0.70), (0.10, 0.06, 1.15), mat_cross, rot=(0, math.radians(-48), 0))

    # NO ENTRY sign plaque
    add_cube("SignBoard", (0, -0.12, 0.72), (1.2, 0.04, 0.32), mat_sign, bevel=0.02)
    add_cube("SignText", (0, -0.15, 0.72), (0.95, 0.02, 0.18), mat_sign_text)

    # Iron bolts
    for bx in [-1.1, 1.1]:
        for bz in [0.35, 0.70, 1.05]:
            add_sphere(f"Bolt_{bx}_{bz}", (bx, -0.08, bz), 0.035, mat_bolt)

# =========================================================================
# 6. SLIDE TUNNEL (Low clearance hazard canopy with red/white stripes)
# =========================================================================
def build_slide_tunnel():
    clear_scene()

    mat_metal = create_mat("CanopyMetal", (0.35, 0.35, 0.38, 1.0), metallic=0.5, roughness=0.4)
    mat_red = create_mat("StripeRed", (0.88, 0.12, 0.14, 1.0), roughness=0.3)
    mat_white = create_mat("StripeWhite", (0.95, 0.95, 0.95, 1.0), roughness=0.3)
    mat_wood_post = create_mat("PostWood", (0.45, 0.28, 0.16, 1.0), roughness=0.7)

    # Height clearance is 1.15m (player standing is 1.6m, slide is 0.7m)
    # Side support walls/posts
    add_cube("WallL", (-1.25, 0, 0.58), (0.18, 1.8, 1.16), mat_wood_post, bevel=0.03)
    add_cube("WallR", (1.25, 0, 0.58), (0.18, 1.8, 1.16), mat_wood_post, bevel=0.03)

    # Overhead canopy roof (top at 1.25m)
    add_cube("RoofBase", (0, 0, 1.22), (2.68, 1.9, 0.14), mat_metal, bevel=0.02)

    # Red & White diagonal hazard awning / stripes on front face
    num_stripes = 8
    width = 2.68
    stripe_w = width / num_stripes
    for i in range(num_stripes):
        sx = -width/2 + (i + 0.5) * stripe_w
        mat_s = mat_red if i % 2 == 0 else mat_white
        add_cube(f"Stripe_{i}", (sx, -0.92, 1.15), (stripe_w * 0.95, 0.04, 0.26), mat_s, rot=(0, math.radians(20), 0))

    # Downward white arrow indicator in center
    add_cube("ArrowStem", (0, -0.96, 1.08), (0.08, 0.02, 0.12), mat_white)
    add_cube("ArrowHead", (0, -0.96, 0.98), (0.16, 0.02, 0.08), mat_white, rot=(0, 0, math.radians(45)))

# =========================================================================
# 7. JUMP RAMP (Blue steel launch ramp with upward white chevron arrows)
# =========================================================================
def build_jump_ramp():
    clear_scene()

    mat_steel = create_mat("RampSteel", (0.10, 0.32, 0.65, 1.0), metallic=0.5, roughness=0.3)
    mat_trim = create_mat("RampTrim", (0.18, 0.18, 0.20, 1.0), metallic=0.7, roughness=0.3)
    mat_arrow = create_mat("RampArrow", (0.96, 0.96, 0.96, 1.0), roughness=0.2, emit_color=(1,1,1,1), emit_val=0.4)

    # Sloped wedge ramp (length 2.6m, width 2.2m, height 0.85m)
    # Using inclined cubes
    ramp_angle = math.radians(20)
    add_cube("RampSurface", (0, 0, 0.42), (2.1, 2.5, 0.10), mat_steel, rot=(ramp_angle, 0, 0), bevel=0.02)

    # Side guard plates
    for sx in [-1.1, 1.1]:
        add_cube(f"RampSide_{sx}", (sx, 0, 0.42), (0.08, 2.5, 0.45), mat_trim)

    # 3 Upward Chevron Arrows painted on ramp surface
    for i, ay in enumerate([-0.5, 0.1, 0.7]):
        az = 0.42 - ay * math.sin(ramp_angle)
        # Left chevron wing
        add_cube(f"ChevL_{i}", (-0.22, ay, az + 0.06), (0.12, 0.40, 0.02), mat_arrow, rot=(ramp_angle, math.radians(35), 0))
        # Right chevron wing
        add_cube(f"ChevR_{i}", (0.22, ay, az + 0.06), (0.12, 0.40, 0.02), mat_arrow, rot=(ramp_angle, math.radians(-35), 0))

# =========================================================================
# 8. COLLECTIBLES (Heart Token & Temple Token)
# =========================================================================
def build_token_heart():
    clear_scene()

    mat_gold = create_mat("GoldCoin", (1.0, 0.82, 0.20, 1.0), metallic=0.85, roughness=0.2)
    mat_heart = create_mat("RedHeart", (0.95, 0.08, 0.15, 1.0), roughness=0.2, emit_color=(1.0, 0.1, 0.2, 1), emit_val=0.4)

    # Outer coin cylinder
    coin = add_cylinder("CoinRim", (0, 0, 0), radius=0.42, depth=0.10, mat=mat_gold, rot=(math.radians(90), 0, 0))
    # Inner face inset
    add_cylinder("CoinFace", (0, 0, 0), radius=0.36, depth=0.12, mat=mat_gold, rot=(math.radians(90), 0, 0))

    # 3D Heart in center
    # Two top lobes
    add_sphere("HeartLobeL", (-0.11, -0.07, 0.07), 0.14, mat_heart)
    add_sphere("HeartLobeR", (0.11, -0.07, 0.07), 0.14, mat_heart)
    # Bottom point cone/sphere
    heart_pt = add_cylinder("HeartPoint", (0, -0.07, -0.09), radius=0.16, depth=0.28, mat=mat_heart, rot=(0, 0, math.radians(45)))
    heart_pt.scale = (0.7, 0.7, 1.0)

def build_token_temple():
    clear_scene()

    mat_cyan = create_mat("CyanBadge", (0.05, 0.65, 0.95, 1.0), metallic=0.6, roughness=0.2)
    mat_white = create_mat("WhiteTemple", (0.96, 0.96, 0.98, 1.0), roughness=0.2, emit_color=(0.8, 0.9, 1.0, 1), emit_val=0.5)

    # Outer cyan badge
    add_cylinder("BadgeRim", (0, 0, 0), radius=0.42, depth=0.10, mat=mat_cyan, rot=(math.radians(90), 0, 0))
    add_cylinder("BadgeFace", (0, 0, 0), radius=0.36, depth=0.12, mat=mat_cyan, rot=(math.radians(90), 0, 0))

    # Classical Temple / Parliament portico in center
    # Triangular pediment / roof
    pediment = add_cylinder("Pediment", (0, -0.07, 0.16), radius=0.26, depth=0.06, mat=mat_white, rot=(math.radians(90), 0, 0), vertices=3)
    # Entablature beam
    add_cube("Beam", (0, -0.07, 0.08), (0.46, 0.06, 0.05), mat_white)
    # 4 Classical columns
    for cx in [-0.18, -0.06, 0.06, 0.18]:
        add_cylinder(f"Col_{cx}", (cx, -0.07, -0.06), radius=0.035, depth=0.22, mat=mat_white)
    # Base plinth
    add_cube("Plinth", (0, -0.07, -0.20), (0.50, 0.06, 0.06), mat_white)

# =========================================================================
# 9. ENVIRONMENT PROPS (Boulevard Tree, Street Lamppost, Crowd Sidewalk, Parliament Dome)
# =========================================================================
def build_boulevard_tree():
    clear_scene()

    mat_bark = create_mat("TreeBark", (0.42, 0.28, 0.16, 1.0), roughness=0.8)
    mat_leaves1 = create_mat("LeavesDark", (0.15, 0.52, 0.20, 1.0), roughness=0.6)
    mat_leaves2 = create_mat("LeavesLight", (0.28, 0.68, 0.25, 1.0), roughness=0.5)

    # Trunk
    add_cylinder("Trunk", (0, 0, 1.5), radius=0.22, depth=3.0, mat=mat_bark)

    # Stylized leafy clusters
    clusters = [
        ((0, 0, 3.8), 1.25, mat_leaves1),
        ((-0.6, -0.4, 3.2), 0.95, mat_leaves2),
        ((0.6, -0.3, 3.3), 0.90, mat_leaves1),
        ((-0.4, 0.5, 3.4), 0.85, mat_leaves2),
        ((0.5, 0.5, 3.5), 0.90, mat_leaves1),
        ((0, 0, 4.6), 0.85, mat_leaves2),
    ]
    for i, (loc, r, m) in enumerate(clusters):
        add_sphere(f"Canopy_{i}", loc, r, m, segs=16, rings=12)

def build_street_lamppost():
    clear_scene()

    mat_iron = create_mat("LampIron", (0.12, 0.13, 0.15, 1.0), metallic=0.7, roughness=0.3)
    mat_gold_trim = create_mat("LampGold", (0.85, 0.70, 0.25, 1.0), metallic=0.8, roughness=0.3)
    mat_glow = create_mat("LampGlow", (1.0, 0.92, 0.70, 1.0), emit_color=(1.0, 0.92, 0.7, 1), emit_val=2.5)

    # Base
    add_cylinder("Base", (0, 0, 0.25), radius=0.32, depth=0.5, mat=mat_iron)
    add_cylinder("BaseTrim", (0, 0, 0.55), radius=0.22, depth=0.15, mat=mat_gold_trim)

    # Pole
    add_cylinder("Pole", (0, 0, 2.5), radius=0.10, depth=3.8, mat=mat_iron)

    # Double curved lamp brackets
    for lx, rot_y in [(-0.55, math.radians(-35)), (0.55, math.radians(35))]:
        add_cylinder(f"Arm_{lx}", (lx * 0.5, 0, 4.3), radius=0.04, depth=0.8, mat=mat_iron, rot=(0, rot_y, 0))
        # Lantern housing
        add_cube(f"LanternTop_{lx}", (lx, 0, 4.5), (0.28, 0.28, 0.08), mat_iron, bevel=0.02)
        add_cube(f"LanternGlow_{lx}", (lx, 0, 4.3), (0.22, 0.22, 0.30), mat_glow)
        add_cube(f"LanternBot_{lx}", (lx, 0, 4.1), (0.20, 0.20, 0.06), mat_iron)

    # Center finial
    add_sphere("Finial", (0, 0, 4.6), 0.12, mat_gold_trim)

def build_crowd_sidewalk():
    clear_scene()

    mat_stone = create_mat("StoneWall", (0.82, 0.78, 0.72, 1.0), roughness=0.7)
    mat_sign_wood = create_mat("SignPole", (0.48, 0.30, 0.18, 1.0), roughness=0.8)
    mat_sign_board = create_mat("SignBoard", (0.95, 0.93, 0.90, 1.0), roughness=0.4)
    mat_sign_text_red = create_mat("SignTextRed", (0.85, 0.12, 0.15, 1.0), roughness=0.3)
    mat_sign_text_black = create_mat("SignTextBlack", (0.12, 0.12, 0.12, 1.0), roughness=0.3)
    mat_flag_saffron = create_mat("FlagSaffron", (1.0, 0.50, 0.10, 1.0), roughness=0.5)
    mat_flag_green = create_mat("FlagGreen", (0.10, 0.65, 0.20, 1.0), roughness=0.5)

    # Sidewalk stone parapet / balustrade wall (length 6m, height 1.1m)
    add_cube("ParapetWall", (0, 0, 0.55), (6.0, 0.35, 1.10), mat_stone, bevel=0.04)
    add_cube("ParapetCap", (0, 0, 1.14), (6.1, 0.45, 0.10), mat_stone, bevel=0.03)

    # Cheering Crowd Spectators behind the wall
    crowd_colors = [
        (0.85, 0.25, 0.20, 1.0),
        (0.20, 0.45, 0.85, 1.0),
        (0.95, 0.85, 0.15, 1.0),
        (0.25, 0.75, 0.35, 1.0),
        (0.95, 0.95, 0.95, 1.0),
        (0.80, 0.40, 0.70, 1.0),
    ]
    mat_skin = create_mat("CrowdSkin", (0.82, 0.62, 0.48, 1.0), roughness=0.6)

    for i, cx in enumerate([-2.4, -1.5, -0.6, 0.3, 1.2, 2.1]):
        m_shirt = create_mat(f"Shirt_{i}", crowd_colors[i % len(crowd_colors)], roughness=0.5)
        # Body
        add_cube(f"CrowdTorso_{i}", (cx, 0.45, 1.35), (0.32, 0.25, 0.42), m_shirt, bevel=0.03)
        # Head
        add_sphere(f"CrowdHead_{i}", (cx, 0.45, 1.72), 0.15, mat_skin)
        # Raised cheering hands
        add_cylinder(f"HandL_{i}", (cx - 0.22, 0.45, 1.80), radius=0.045, depth=0.45, mat=m_shirt, rot=(0, math.radians(-30), 0))
        add_cylinder(f"HandR_{i}", (cx + 0.22, 0.45, 1.80), radius=0.045, depth=0.45, mat=m_shirt, rot=(0, math.radians(30), 0))

    # Campaign & Protest Signs held up by crowd
    signs = [
        (-1.8, 2.3, "Sign_MoreJobs", mat_sign_text_black),
        (0.6, 2.4, "Sign_StrongLeadership", mat_sign_text_red),
        (2.3, 2.2, "Sign_PeopleSupport", mat_sign_text_black),
    ]
    for sx, sz, sname, stext_mat in signs:
        # Wooden pole
        add_cylinder(f"{sname}_Pole", (sx, 0.55, sz - 0.5), radius=0.03, depth=1.4, mat=mat_sign_wood)
        # Sign placard
        add_cube(f"{sname}_Board", (sx, 0.53, sz), (0.95, 0.04, 0.55), mat_sign_board, bevel=0.02)
        # Text stripe block on sign
        add_cube(f"{sname}_Text", (sx, 0.51, sz), (0.80, 0.02, 0.30), stext_mat)

    # Indian campaign flags on poles
    for fx, fz in [(-0.8, 2.5), (1.6, 2.5)]:
        add_cylinder(f"FlagPole_{fx}", (fx, 0.55, fz - 0.5), radius=0.025, depth=1.5, mat=mat_sign_wood)
        add_cube(f"FlagSaffron_{fx}", (fx + 0.25, 0.54, fz + 0.12), (0.45, 0.02, 0.12), mat_flag_saffron)
        add_cube(f"FlagWhite_{fx}", (fx + 0.25, 0.54, fz), (0.45, 0.02, 0.12), mat_sign_board)
        add_cube(f"FlagGreen_{fx}", (fx + 0.25, 0.54, fz - 0.12), (0.45, 0.02, 0.12), mat_flag_green)

def build_parliament_dome():
    clear_scene()

    mat_sandstone = create_mat("Sandstone", (0.86, 0.74, 0.60, 1.0), roughness=0.6)
    mat_dome = create_mat("DomeCopper", (0.82, 0.68, 0.50, 1.0), metallic=0.3, roughness=0.4)
    mat_flag = create_mat("FlagSaffron", (1.0, 0.50, 0.10, 1.0), roughness=0.5)

    # Classical grand parliament building for horizon backdrop (width 24m, height 12m)
    # Main base block
    add_cube("BaseWings", (0, 0, 2.0), (22.0, 6.0, 4.0), mat_sandstone, bevel=0.1)
    # Colonapped central colonnade
    for cx in [-4.5, -3.0, -1.5, 0, 1.5, 3.0, 4.5]:
        add_cylinder(f"MainCol_{cx}", (cx, -3.2, 3.0), radius=0.25, depth=4.0, mat=mat_sandstone)
    # Pediment beam
    add_cube("Entablature", (0, -3.2, 5.2), (12.0, 1.2, 0.6), mat_sandstone)

    # Central Grand Dome
    add_cylinder("DomeDrum", (0, 0, 5.5), radius=3.2, depth=2.5, mat=mat_sandstone)
    dome = add_sphere("MainDome", (0, 0, 7.5), 3.2, mat_dome)
    dome.scale = (1.0, 1.0, 1.25)
    # Lantern cupola on top
    add_cylinder("Cupola", (0, 0, 11.0), radius=0.6, depth=1.2, mat=mat_sandstone)
    add_sphere("CupolaDome", (0, 0, 11.8), 0.65, mat_dome)
    # Flagpole and flag
    add_cylinder("Flagpole", (0, 0, 13.0), radius=0.06, depth=2.0, mat=mat_sandstone)
    add_cube("HorizonFlag", (0.5, 0, 13.4), (0.9, 0.04, 0.5), mat_flag)

# =========================================================================
# MASTER GENERATION FUNCTION
# =========================================================================
def generate_all():
    props_dir = "/Users/subhash/Games/assets/sprites/props"
    char_dir = "/Users/subhash/Games/assets/sprites/characters"
    char_model_dir = "/Users/subhash/Games/assets/characters"
    env_dir = "/Users/subhash/Games/assets/sprites/environment"

    # 1. Chibi Leader Sprites & Model
    poses = ["run1", "run2", "jump", "slide"]
    for p in poses:
        build_chibi_leader(p)
        setup_studio(cam_pos=(0, -2.5, 1.15), cam_rot=(math.radians(82), 0, 0))
        render_out(f"{char_dir}/chibi_rear_{p}.png")

    build_chibi_leader("run1")
    export_glb(f"{char_model_dir}/chibi_leader.glb")

    # 2. Moving Bull Cart (GLB)
    build_bull_cart()
    export_glb(f"{props_dir}/bull_cart.glb")

    # 3. Police Dog (GLB)
    build_police_dog()
    export_glb(f"{props_dir}/police_dog.glb")

    # 4. Police Barricade (GLB)
    build_police_barricade()
    export_glb(f"{props_dir}/police_barricade.glb")

    # 5. Wooden Roadblock (GLB)
    build_wooden_roadblock()
    export_glb(f"{props_dir}/wooden_roadblock.glb")

    # 6. Slide Tunnel (GLB)
    build_slide_tunnel()
    export_glb(f"{props_dir}/slide_tunnel.glb")

    # 7. Jump Ramp (GLB)
    build_jump_ramp()
    export_glb(f"{props_dir}/jump_ramp.glb")

    # 8. Collectibles: Heart & Temple (GLB + Rendered PNG icons)
    build_token_heart()
    export_glb(f"{props_dir}/token_heart.glb")
    setup_studio(cam_pos=(0, -1.4, 0), cam_rot=(math.radians(90), 0, 0), ortho=True)
    render_out(f"{props_dir}/token_heart.png")

    build_token_temple()
    export_glb(f"{props_dir}/token_temple.glb")
    setup_studio(cam_pos=(0, -1.4, 0), cam_rot=(math.radians(90), 0, 0), ortho=True)
    render_out(f"{props_dir}/token_temple.png")

    # 9. Environment Props (GLB)
    build_boulevard_tree()
    export_glb(f"{props_dir}/boulevard_tree.glb")

    build_street_lamppost()
    export_glb(f"{props_dir}/street_lamppost.glb")

    build_crowd_sidewalk()
    export_glb(f"{props_dir}/crowd_sidewalk.glb")

    build_parliament_dome()
    export_glb(f"{props_dir}/parliament_dome.glb")

    print("\n>>> ALL ASSETS GENERATED SUCCESSFULLY! <<<")

generate_all()
