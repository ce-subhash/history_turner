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

def setup_studio(cam_pos=(0, -2.1, 0.95), cam_rot=(math.radians(78), 0, 0), ortho=False, ortho_scale=1.5):
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = 'ORTHO' if ortho else 'PERSP'
    if ortho:
        cam_data.ortho_scale = ortho_scale
    else:
        cam_data.lens = 50
    cam_obj = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    cam_obj.location = cam_pos
    cam_obj.rotation_euler = cam_rot
    bpy.context.scene.camera = cam_obj

    # Main sunlight (warm golden sun)
    sun_data = bpy.data.lights.new("Sun", 'SUN')
    sun_data.energy = 5.8
    sun_data.color = (1.0, 0.96, 0.90)
    sun_obj = bpy.data.objects.new("Sun", sun_data)
    bpy.context.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(50), math.radians(20), math.radians(-25))

    # Fill light
    fill_data = bpy.data.lights.new("Fill", 'SUN')
    fill_data.energy = 2.8
    fill_data.color = (0.80, 0.88, 1.0)
    fill_obj = bpy.data.objects.new("Fill", fill_data)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(40), math.radians(-20), math.radians(160))

    # Rim light
    rim_data = bpy.data.lights.new("Rim", 'POINT')
    rim_data.energy = 40.0
    rim_data.color = (1.0, 1.0, 1.0)
    rim_obj = bpy.data.objects.new("Rim", rim_data)
    rim_obj.location = (0, 1.5, 1.2)
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

# =========================================================================
# CHIBI LEADER
# =========================================================================
def build_chibi_leader(pose="run1"):
    clear_scene()
    
    mat_skin = create_mat("Skin", (0.88, 0.68, 0.54, 1.0), roughness=0.5)
    mat_hair = create_mat("Hair", (0.07, 0.06, 0.06, 1.0), roughness=0.7)
    mat_cap = create_mat("Cap", (0.98, 0.98, 0.98, 1.0), roughness=0.3)
    mat_kurta = create_mat("Kurta", (0.96, 0.96, 0.95, 1.0), roughness=0.4)
    mat_sash = create_mat("Sash", (0.90, 0.10, 0.12, 1.0), roughness=0.3)
    mat_pants = create_mat("Pants", (0.94, 0.94, 0.93, 1.0), roughness=0.4)
    mat_shoe = create_mat("Shoe", (0.35, 0.20, 0.12, 1.0), roughness=0.4)
    mat_sole = create_mat("Sole", (0.98, 0.98, 0.98, 1.0), roughness=0.3)

    root_z = 0.0
    # Head
    head_z = 1.10
    if pose == "slide":
        head_z = 0.82
    head = add_sphere("Head", (0, 0, head_z), 0.32, mat_skin, segs=32, rings=24)
    head.scale = (1.0, 0.95, 1.02)

    # Hair (Dark wavy volume around back and sides)
    hair = add_sphere("Hair", (0, -0.04, head_z + 0.02), 0.335, mat_hair, segs=32, rings=24)
    hair.scale = (1.02, 0.98, 0.95)

    # Hair curls on back of neck and around ears
    for hx in [-0.24, -0.12, 0.0, 0.12, 0.24]:
        add_sphere(f"HairCurl_{hx}", (hx, -0.14, head_z - 0.10), 0.11, mat_hair, segs=16, rings=12)

    # Ears
    add_sphere("EarL", (-0.31, 0, head_z - 0.02), 0.07, mat_skin)
    add_sphere("EarR", (0.31, 0, head_z - 0.02), 0.07, mat_skin)

    # White Gandhi / Nehru Boat Cap sitting proudly on top of hair
    cap_z = head_z + 0.34
    cap = add_cube("CapBase", (0, 0.01, cap_z), (0.22, 0.30, 0.06), mat_cap, bevel=0.02)
    cap_top = add_cube("CapTop", (0, 0.01, cap_z + 0.06), (0.07, 0.28, 0.03), mat_cap, bevel=0.01)

    # Neck
    add_cylinder("Neck", (0, 0, head_z - 0.22), radius=0.10, depth=0.12, mat=mat_skin)

    # Torso (Kurta)
    torso_z = 0.68 + root_z
    if pose == "slide":
        torso_z = 0.50
        torso = add_cube("Torso", (0, 0, torso_z), (0.23, 0.15, 0.28), mat_kurta, rot=(math.radians(22), 0, 0), bevel=0.04)
        skirt = add_cube("Skirt", (0, -0.06, torso_z - 0.20), (0.25, 0.17, 0.16), mat_kurta, rot=(math.radians(22), 0, 0), bevel=0.03)
    else:
        torso = add_cube("Torso", (0, 0, torso_z), (0.23, 0.15, 0.28), mat_kurta, bevel=0.04)
        skirt = add_cube("Skirt", (0, 0, torso_z - 0.20), (0.25, 0.17, 0.16), mat_kurta, bevel=0.03)

    # Red Diagonal Sash (Uttariya) placed ON TOP of back surface
    # Torso back is at y = -0.15. So sash is placed at y = -0.18 to -0.20!
    sash_y = -0.17 if pose != "slide" else -0.22
    sash_segs = [
        (-0.18, sash_y + 0.02, torso_z + 0.20),
        (-0.09, sash_y, torso_z + 0.09),
        (0.01, sash_y, torso_z - 0.02),
        (0.11, sash_y, torso_z - 0.13),
        (0.19, sash_y + 0.02, torso_z - 0.22)
    ]
    for i, pt in enumerate(sash_segs):
        add_cube(f"Sash_{i}", pt, (0.08, 0.035, 0.08), mat_sash, rot=(0, math.radians(35), 0), bevel=0.015)
    # Fluttering sash tail hanging off right hip
    add_cube("SashTail", (0.23, sash_y - 0.04, torso_z - 0.32), (0.06, 0.03, 0.16), mat_sash, rot=(math.radians(-15), math.radians(15), 0), bevel=0.015)

    # Limbs and poses
    if pose == "run1":
        # Left foot forward, Right foot back kicked up
        add_cylinder("ThighL", (-0.13, 0.08, 0.38), radius=0.075, depth=0.24, mat=mat_pants, rot=(math.radians(-30), 0, 0))
        add_cylinder("ShinL", (-0.13, 0.15, 0.20), radius=0.065, depth=0.22, mat=mat_pants, rot=(math.radians(-8), 0, 0))
        add_cube("ShoeL", (-0.13, 0.18, 0.08), (0.08, 0.15, 0.06), mat_shoe, bevel=0.02)
        add_cube("SoleL", (-0.13, 0.18, 0.03), (0.085, 0.155, 0.02), mat_sole, bevel=0.01)

        add_cylinder("ThighR", (0.13, -0.10, 0.40), radius=0.075, depth=0.24, mat=mat_pants, rot=(math.radians(40), 0, 0))
        add_cylinder("ShinR", (0.13, -0.22, 0.30), radius=0.065, depth=0.22, mat=mat_pants, rot=(math.radians(80), 0, 0))
        add_cube("ShoeR", (0.13, -0.34, 0.33), (0.08, 0.15, 0.06), mat_shoe, rot=(math.radians(65), 0, 0), bevel=0.02)
        add_cube("SoleR", (0.13, -0.34, 0.29), (0.085, 0.155, 0.02), mat_sole, rot=(math.radians(65), 0, 0), bevel=0.01)

        # Arms: Left back, Right forward
        add_cylinder("ArmL", (-0.28, -0.10, 0.65), radius=0.055, depth=0.26, mat=mat_kurta, rot=(math.radians(35), 0, 0))
        add_sphere("HandL", (-0.28, -0.19, 0.53), 0.05, mat_skin)
        add_cylinder("ArmR", (0.28, 0.10, 0.65), radius=0.055, depth=0.26, mat=mat_kurta, rot=(math.radians(-35), 0, 0))
        add_sphere("HandR", (0.28, 0.19, 0.53), 0.05, mat_skin)

    elif pose == "run2":
        # Right foot forward, Left foot back kicked up
        add_cylinder("ThighR", (0.13, 0.08, 0.38), radius=0.075, depth=0.24, mat=mat_pants, rot=(math.radians(-30), 0, 0))
        add_cylinder("ShinR", (0.13, 0.15, 0.20), radius=0.065, depth=0.22, mat=mat_pants, rot=(math.radians(-8), 0, 0))
        add_cube("ShoeR", (0.13, 0.18, 0.08), (0.08, 0.15, 0.06), mat_shoe, bevel=0.02)
        add_cube("SoleR", (0.13, 0.18, 0.03), (0.085, 0.155, 0.02), mat_sole, bevel=0.01)

        add_cylinder("ThighL", (-0.13, -0.10, 0.40), radius=0.075, depth=0.24, mat=mat_pants, rot=(math.radians(40), 0, 0))
        add_cylinder("ShinL", (-0.13, -0.22, 0.30), radius=0.065, depth=0.22, mat=mat_pants, rot=(math.radians(80), 0, 0))
        add_cube("ShoeL", (-0.13, -0.34, 0.33), (0.08, 0.15, 0.06), mat_shoe, rot=(math.radians(65), 0, 0), bevel=0.02)
        add_cube("SoleL", (-0.13, -0.34, 0.29), (0.085, 0.155, 0.02), mat_sole, rot=(math.radians(65), 0, 0), bevel=0.01)

        # Arms: Right back, Left forward
        add_cylinder("ArmR", (0.28, -0.10, 0.65), radius=0.055, depth=0.26, mat=mat_kurta, rot=(math.radians(35), 0, 0))
        add_sphere("HandR", (0.28, -0.19, 0.53), 0.05, mat_skin)
        add_cylinder("ArmL", (-0.28, 0.10, 0.65), radius=0.055, depth=0.26, mat=mat_kurta, rot=(math.radians(-35), 0, 0))
        add_sphere("HandL", (-0.28, 0.19, 0.53), 0.05, mat_skin)

    elif pose == "jump":
        add_cylinder("ThighL", (-0.13, 0.06, 0.58), radius=0.075, depth=0.22, mat=mat_pants, rot=(math.radians(-45), 0, 0))
        add_cylinder("ShinL", (-0.13, -0.04, 0.45), radius=0.065, depth=0.22, mat=mat_pants, rot=(math.radians(35), 0, 0))
        add_cube("ShoeL", (-0.13, -0.06, 0.33), (0.08, 0.15, 0.06), mat_shoe, bevel=0.02)
        add_cube("SoleL", (-0.13, -0.06, 0.28), (0.085, 0.155, 0.02), mat_sole, bevel=0.01)

        add_cylinder("ThighR", (0.13, 0.06, 0.58), radius=0.075, depth=0.22, mat=mat_pants, rot=(math.radians(-45), 0, 0))
        add_cylinder("ShinR", (0.13, -0.04, 0.45), radius=0.065, depth=0.22, mat=mat_pants, rot=(math.radians(35), 0, 0))
        add_cube("ShoeR", (0.13, -0.06, 0.33), (0.08, 0.15, 0.06), mat_shoe, bevel=0.02)
        add_cube("SoleR", (0.13, -0.06, 0.28), (0.085, 0.155, 0.02), mat_sole, bevel=0.01)

        add_cylinder("ArmL", (-0.30, 0, 0.88), radius=0.055, depth=0.26, mat=mat_kurta, rot=(0, math.radians(-45), 0))
        add_sphere("HandL", (-0.40, 0, 0.98), 0.05, mat_skin)
        add_cylinder("ArmR", (0.30, 0, 0.88), radius=0.055, depth=0.26, mat=mat_kurta, rot=(0, math.radians(45), 0))
        add_sphere("HandR", (0.40, 0, 0.98), 0.05, mat_skin)

    elif pose == "slide":
        add_cylinder("ThighL", (-0.13, 0.15, 0.26), radius=0.075, depth=0.24, mat=mat_pants, rot=(math.radians(-75), 0, 0))
        add_cylinder("ShinL", (-0.13, 0.36, 0.16), radius=0.065, depth=0.22, mat=mat_pants, rot=(math.radians(-85), 0, 0))
        add_cube("ShoeL", (-0.13, 0.52, 0.09), (0.08, 0.15, 0.06), mat_shoe, rot=(math.radians(-15), 0, 0), bevel=0.02)
        add_cube("SoleL", (-0.13, 0.52, 0.04), (0.085, 0.155, 0.02), mat_sole, rot=(math.radians(-15), 0, 0), bevel=0.01)

        add_cylinder("ThighR", (0.13, 0.15, 0.26), radius=0.075, depth=0.24, mat=mat_pants, rot=(math.radians(-75), 0, 0))
        add_cylinder("ShinR", (0.13, 0.36, 0.16), radius=0.065, depth=0.22, mat=mat_pants, rot=(math.radians(-85), 0, 0))
        add_cube("ShoeR", (0.13, 0.52, 0.09), (0.08, 0.15, 0.06), mat_shoe, rot=(math.radians(-15), 0, 0), bevel=0.02)
        add_cube("SoleR", (0.13, 0.52, 0.04), (0.085, 0.155, 0.02), mat_sole, rot=(math.radians(-15), 0, 0), bevel=0.01)

        add_cylinder("ArmL", (-0.26, -0.18, 0.35), radius=0.055, depth=0.24, mat=mat_kurta, rot=(math.radians(45), 0, 0))
        add_sphere("HandL", (-0.26, -0.26, 0.23), 0.05, mat_skin)
        add_cylinder("ArmR", (0.26, -0.18, 0.35), radius=0.055, depth=0.24, mat=mat_kurta, rot=(math.radians(45), 0, 0))
        add_sphere("HandR", (0.26, -0.26, 0.23), 0.05, mat_skin)

# =========================================================================
# MATHEMATICALLY PERFECT 3D HEART
# =========================================================================
def build_token_heart():
    clear_scene()

    mat_gold = create_mat("GoldRim", (1.0, 0.76, 0.08, 1.0), metallic=0.92, roughness=0.15)
    mat_gold_inner = create_mat("GoldInner", (0.95, 0.68, 0.05, 1.0), metallic=0.88, roughness=0.25)
    mat_heart = create_mat("RedHeart", (0.98, 0.05, 0.12, 1.0), roughness=0.15, emit_color=(1.0, 0.08, 0.15, 1), emit_val=0.55)

    add_cylinder("CoinRim", (0, 0, 0), radius=0.45, depth=0.10, mat=mat_gold, rot=(math.radians(90), 0, 0))
    add_cylinder("CoinFace", (0, 0, 0), radius=0.39, depth=0.12, mat=mat_gold_inner, rot=(math.radians(90), 0, 0))

    mesh = bpy.data.meshes.new("HeartMesh")
    obj = bpy.data.objects.new("HeartObj", mesh)
    bpy.context.collection.objects.link(obj)

    verts = []
    steps = 36
    scale = 0.016
    for i in range(steps):
        t = 2.0 * math.pi * i / steps
        x = 16.0 * (math.sin(t) ** 3) * scale
        z = (13.0 * math.cos(t) - 5.0 * math.cos(2.0 * t) - 2.0 * math.cos(3.0 * t) - math.cos(4.0 * t)) * scale
        verts.append((x, -0.14, z + 0.02))
    for i in range(steps):
        t = 2.0 * math.pi * i / steps
        x = 16.0 * (math.sin(t) ** 3) * scale
        z = (13.0 * math.cos(t) - 5.0 * math.cos(2.0 * t) - 2.0 * math.cos(3.0 * t) - math.cos(4.0 * t)) * scale
        verts.append((x, -0.04, z + 0.02))

    faces = []
    for i in range(steps):
        next_i = (i + 1) % steps
        faces.append([i, next_i, steps + next_i, steps + i])
    faces.append(list(range(steps)))
    faces.append(list(range(steps, 2 * steps)))

    mesh.from_pydata(verts, [], faces)
    mesh.update()
    smooth_object(obj)
    apply_mat(obj, mat_heart)
    add_bevel(obj, width=0.015, segments=2)

def build_token_temple():
    clear_scene()

    mat_cyan_rim = create_mat("CyanRim", (0.08, 0.58, 0.95, 1.0), metallic=0.75, roughness=0.2)
    mat_cyan_face = create_mat("CyanFace", (0.04, 0.42, 0.85, 1.0), metallic=0.6, roughness=0.3)
    mat_white = create_mat("WhiteTemple", (0.98, 0.98, 1.0, 1.0), roughness=0.15, emit_color=(0.95, 0.98, 1.0, 1), emit_val=0.6)

    add_cylinder("BadgeRim", (0, 0, 0), radius=0.45, depth=0.10, mat=mat_cyan_rim, rot=(math.radians(90), 0, 0))
    add_cylinder("BadgeFace", (0, 0, 0), radius=0.39, depth=0.12, mat=mat_cyan_face, rot=(math.radians(90), 0, 0))

    # Classical Temple / Parliament portico proportioned inside badge
    pediment = add_cylinder("Pediment", (0, -0.08, 0.13), radius=0.17, depth=0.06, mat=mat_white, rot=(math.radians(90), 0, 0), vertices=3)
    add_cube("Beam", (0, -0.08, 0.05), (0.34, 0.06, 0.04), mat_white, bevel=0.01)
    for cx in [-0.12, -0.04, 0.04, 0.12]:
        add_cylinder(f"Col_{cx}", (cx, -0.08, -0.05), radius=0.024, depth=0.16, mat=mat_white)
    add_cube("Plinth", (0, -0.08, -0.16), (0.36, 0.06, 0.05), mat_white, bevel=0.01)

def re_render():
    char_dir = "/Users/subhash/Games/assets/sprites/characters"
    props_dir = "/Users/subhash/Games/assets/sprites/props"

    poses = ["run1", "run2", "jump", "slide"]
    for p in poses:
        build_chibi_leader(p)
        setup_studio(cam_pos=(0, -3.1, 0.98), cam_rot=(math.radians(82), 0, 0))
        render_out(f"{char_dir}/chibi_rear_{p}.png")

    build_token_heart()
    setup_studio(cam_pos=(0, -1.25, 0), cam_rot=(math.radians(90), 0, 0), ortho=True, ortho_scale=1.0)
    render_out(f"{props_dir}/token_heart.png")

    build_token_temple()
    setup_studio(cam_pos=(0, -1.25, 0), cam_rot=(math.radians(90), 0, 0), ortho=True, ortho_scale=1.0)
    render_out(f"{props_dir}/token_temple.png")

    build_chibi_leader("run1")
    bpy.ops.export_scene.gltf(filepath="/Users/subhash/Games/assets/characters/chibi_leader.glb", export_format='GLB', use_selection=False, export_apply=True)
    print("Exported updated chibi_leader.glb")

re_render()
