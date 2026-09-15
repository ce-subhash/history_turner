"""
generate_characters.py
High-Quality Stylized 3D Character Generator for "Timetracks: Rulers & Rebels".
Uses Blender 5.2.1 LTS headless API to procedurally model and export:
  1. Julius Caesar  -> res://assets/characters/caesar.glb
  2. Joan of Arc    -> res://assets/characters/joan.glb
  3. Harriet Tubman -> res://assets/characters/harriet.glb

Key Aesthetic Improvements:
  - Heroic tapered proportions (no blocky giraffe necks or disjointed stacks).
  - Head sits naturally on shoulders/collar (Y: 1.28m - 1.56m).
  - Expressive stylized facial features with glossy eyes.
  - Smooth-shaded beveled armor, cloth folds, and accessories.
  - Accurate local joint pivots for fluid running animation.
"""

import bpy
import math
import os

OUTPUT_DIR = "/Users/subhash/Games/assets/characters"
os.makedirs(OUTPUT_DIR, exist_ok=True)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not bpy.data.collections:
        col = bpy.data.collections.new("Collection")
        bpy.context.scene.collection.children.link(col)


def create_mat(name, color, metallic=0.0, roughness=0.4, emission=(0, 0, 0, 1), emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        if "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = color
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        if emission_strength > 0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = emission
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def add_cube(name, location, scale, material=None, rotation=(0, 0, 0), smooth=True):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if smooth:
        for f in obj.data.polygons:
            f.use_smooth = True
    if material:
        obj.data.materials.append(material)
    return obj


def add_cylinder(name, location, radius, depth, material=None, rotation=(0, 0, 0), vertices=12, smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if smooth:
        for f in obj.data.polygons:
            f.use_smooth = True
    if material:
        obj.data.materials.append(material)
    return obj


def add_sphere(name, location, radius, material=None, scale=(1, 1, 1), rotation=(0, 0, 0), segments=16, ring_count=10, smooth=True):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=ring_count,
        radius=radius,
        location=location,
        rotation=rotation
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if smooth:
        for f in obj.data.polygons:
            f.use_smooth = True
    if material:
        obj.data.materials.append(material)
    return obj


def add_torus(name, location, major_radius, minor_radius, material=None, rotation=(0, 0, 0), smooth=True):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=20,
        minor_segments=8,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=location,
        rotation=rotation
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if smooth:
        for f in obj.data.polygons:
            f.use_smooth = True
    if material:
        obj.data.materials.append(material)
    return obj


def join_and_set_pivot(parts, final_name, pivot_location, parent=None):
    if not parts:
        return None
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = final_name

    # Set object origin to specified pivot
    bpy.context.scene.cursor.location = pivot_location
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

    if parent:
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


# ==============================================================================
# 1. JULIUS CAESAR
# ==============================================================================
def build_caesar():
    reset_scene()

    # Materials
    mat_skin = create_mat("CaesarSkin", (0.86, 0.70, 0.58, 1.0), roughness=0.5)
    mat_hair = create_mat("CaesarHair", (0.24, 0.18, 0.14, 1.0), roughness=0.6)
    mat_tunic = create_mat("RomanTunic", (0.95, 0.94, 0.92, 1.0), roughness=0.5)
    mat_lorica = create_mat("LoricaBronze", (0.82, 0.58, 0.22, 1.0), metallic=0.88, roughness=0.22)
    mat_gold = create_mat("ImperialGold", (1.0, 0.82, 0.18, 1.0), metallic=0.95, roughness=0.18,
                          emission=(1.0, 0.78, 0.15, 1.0), emission_strength=0.35)
    mat_leather = create_mat("RomanLeather", (0.34, 0.18, 0.10, 1.0), roughness=0.55)
    mat_cape = create_mat("TyrianCrimson", (0.78, 0.06, 0.14, 1.0), roughness=0.5)
    mat_eye = create_mat("EyeGloss", (0.08, 0.08, 0.08, 1.0), roughness=0.1)

    root = bpy.data.objects.new("Caesar", None)
    bpy.context.scene.collection.objects.link(root)

    # --- TORSO --- (Chest + Cuirass + Belt + Pauldrons)
    torso_parts = []
    # Tapered Lorica Cuirass (Shoulders width 0.42, waist width 0.32, depth 0.24, height 0.40)
    torso_parts.append(add_cube("LoricaChest", (0, 0, 1.06), (0.40, 0.24, 0.36), mat_lorica))
    # Chest contour / musculata definition
    torso_parts.append(add_cube("PecLeft", (-0.09, 0.08, 1.12), (0.16, 0.06, 0.14), mat_lorica))
    torso_parts.append(add_cube("PecRight", (0.09, 0.08, 1.12), (0.16, 0.06, 0.14), mat_lorica))
    # Golden Imperial Eagle Emblem (+Y is front)
    torso_parts.append(add_cube("EagleWings", (0, 0.115, 1.14), (0.24, 0.02, 0.06), mat_gold))
    torso_parts.append(add_cube("EagleBody", (0, 0.118, 1.09), (0.06, 0.02, 0.12), mat_gold))
    # Leather Belt (Cingulum)
    torso_parts.append(add_cube("Cingulum", (0, 0, 0.86), (0.38, 0.25, 0.08), mat_leather))
    torso_parts.append(add_cube("CingulumBuckle", (0, 0.13, 0.86), (0.10, 0.02, 0.08), mat_gold))
    # Pteruges (Hanging leather battle skirt straps around hips)
    for i in range(5):
        x_pos = -0.14 + i * 0.07
        torso_parts.append(add_cube(f"Pteruges_{i}", (x_pos, 0.11, 0.74), (0.05, 0.02, 0.18), mat_leather))
        torso_parts.append(add_cube(f"PterugesStud_{i}", (x_pos, 0.122, 0.68), (0.03, 0.015, 0.03), mat_gold))
    # Roman Shoulder Pauldrons (curved over shoulder joints)
    torso_parts.append(add_cube("LeftPuldron", (-0.23, 0, 1.22), (0.12, 0.22, 0.06), mat_lorica, (0, 0.15, 0)))
    torso_parts.append(add_cube("RightPuldron", (0.23, 0, 1.22), (0.12, 0.22, 0.06), mat_lorica, (0, -0.15, 0)))
    # Short natural neck (Z = 1.24 to 1.30, perfectly recessed)
    torso_parts.append(add_cylinder("Neck", (0, 0, 1.26), 0.08, 0.08, mat_skin))

    torso_obj = join_and_set_pivot(torso_parts, "Torso", (0, 0, 0.86), parent=root)

    # --- HEAD --- (Sits naturally on neck: Y=1.28 to 1.54)
    head_parts = []
    # Head Base (stylized rounded form)
    head_parts.append(add_sphere("HeadBase", (0, 0.02, 1.42), 0.16, mat_skin, scale=(0.92, 0.96, 1.04)))
    # Classical Roman Brow & Nose
    head_parts.append(add_cube("RomanNose", (0, 0.17, 1.41), (0.035, 0.05, 0.08), mat_skin))
    # Expressive stylized eyes (+Y front)
    for ex in [-0.06, 0.06]:
        head_parts.append(add_sphere(f"Eye_{ex}", (ex, 0.145, 1.43), 0.022, mat_eye, scale=(0.85, 0.35, 1.2)))
    # Cropped Roman Hair
    head_parts.append(add_sphere("HairBack", (0, -0.03, 1.45), 0.165, mat_hair, scale=(0.95, 0.98, 1.02)))
    head_parts.append(add_cube("HairFringe", (0, 0.08, 1.52), (0.18, 0.12, 0.05), mat_hair))
    # Golden Laurel Wreath (Crown of Victory)
    head_parts.append(add_torus("LaurelRing", (0, 0.01, 1.47), 0.17, 0.02, mat_gold, (0.12, 0, 0)))
    for angle in [-40, -20, 0, 20, 40]:
        rad = math.radians(angle)
        lx = math.sin(rad) * 0.17
        ly = math.cos(rad) * 0.17 + 0.01
        head_parts.append(add_cube(f"Leaf_{angle}", (lx, ly, 1.48), (0.04, 0.025, 0.012), mat_gold, (0, 0, -rad)))

    join_and_set_pivot(head_parts, "Head", (0, 0, 1.28), parent=torso_obj)

    # --- ARMS --- (Shoulder pivot at ±0.28, 0, 1.20)
    # Left Arm
    l_arm_parts = []
    l_arm_parts.append(add_cube("L_UpperSleeve", (-0.28, 0, 1.14), (0.10, 0.12, 0.14), mat_tunic))
    l_arm_parts.append(add_cylinder("L_Arm", (-0.28, 0, 1.02), 0.055, 0.16, mat_skin))
    l_arm_parts.append(add_cube("L_Bracer", (-0.28, 0, 0.89), (0.085, 0.095, 0.12), mat_lorica))
    l_arm_parts.append(add_sphere("L_Hand", (-0.28, 0.01, 0.79), 0.055, mat_skin))
    join_and_set_pivot(l_arm_parts, "LeftArm", (-0.28, 0, 1.20), parent=root)

    # Right Arm
    r_arm_parts = []
    r_arm_parts.append(add_cube("R_UpperSleeve", (0.28, 0, 1.14), (0.10, 0.12, 0.14), mat_tunic))
    r_arm_parts.append(add_cylinder("R_Arm", (0.28, 0, 1.02), 0.055, 0.16, mat_skin))
    r_arm_parts.append(add_cube("R_Bracer", (0.28, 0, 0.89), (0.085, 0.095, 0.12), mat_lorica))
    r_arm_parts.append(add_sphere("R_Hand", (0.28, 0.01, 0.79), 0.055, mat_skin))
    join_and_set_pivot(r_arm_parts, "RightArm", (0.28, 0, 1.20), parent=root)

    # --- LEGS --- (Hip pivot at ±0.13, 0, 0.78)
    # Left Leg
    l_leg_parts = []
    l_leg_parts.append(add_cube("L_Thigh", (-0.13, 0, 0.62), (0.11, 0.13, 0.28), mat_tunic))
    l_leg_parts.append(add_cube("L_Greave", (-0.13, 0.01, 0.34), (0.10, 0.11, 0.28), mat_lorica))
    l_leg_parts.append(add_cube("L_Foot", (-0.13, 0.05, 0.07), (0.095, 0.18, 0.08), mat_leather))
    join_and_set_pivot(l_leg_parts, "LeftLeg", (-0.13, 0, 0.78), parent=root)

    # Right Leg
    r_leg_parts = []
    r_leg_parts.append(add_cube("R_Thigh", (0.13, 0, 0.62), (0.11, 0.13, 0.28), mat_tunic))
    r_leg_parts.append(add_cube("R_Greave", (0.13, 0.01, 0.34), (0.10, 0.11, 0.28), mat_lorica))
    r_leg_parts.append(add_cube("R_Foot", (0.13, 0.05, 0.07), (0.095, 0.18, 0.08), mat_leather))
    join_and_set_pivot(r_leg_parts, "RightLeg", (0.13, 0, 0.78), parent=root)

    # --- CRIMSON CAPE --- (Pivot at upper back: 0, -0.13, 1.22)
    cape_parts = []
    cape_parts.append(add_cube("CapeTop", (0, -0.13, 1.21), (0.34, 0.03, 0.08), mat_cape))
    cape_parts.append(add_sphere("FibulaL", (-0.14, -0.11, 1.23), 0.028, mat_gold))
    cape_parts.append(add_sphere("FibulaR", (0.14, -0.11, 1.23), 0.028, mat_gold))
    cape_parts.append(add_cube("CapeMid", (0, -0.16, 0.86), (0.38, 0.025, 0.62), mat_cape, (-0.07, 0, 0)))
    cape_parts.append(add_cube("CapeLow", (0, -0.20, 0.46), (0.44, 0.025, 0.32), mat_cape, (-0.12, 0, 0)))
    join_and_set_pivot(cape_parts, "Cape", (0, -0.13, 1.22), parent=torso_obj)

    # --- GLADIUS --- (At left hip)
    sword_parts = []
    sword_parts.append(add_cube("Scabbard", (-0.23, 0.02, 0.78), (0.05, 0.07, 0.36), mat_leather, (0.25, 0.1, 0)))
    sword_parts.append(add_cube("SwordHilt", (-0.23, 0.05, 0.98), (0.03, 0.03, 0.10), mat_gold, (0.25, 0.1, 0)))
    sword_parts.append(add_sphere("SwordPommel", (-0.23, 0.08, 1.04), 0.028, mat_gold))
    join_and_set_pivot(sword_parts, "Gladius", (-0.23, 0.02, 0.86), parent=torso_obj)

    # Export
    filepath = os.path.join(OUTPUT_DIR, "caesar.glb")
    bpy.ops.export_scene.gltf(filepath=filepath, export_format='GLB')
    print("Exported Caesar:", filepath)


# ==============================================================================
# 2. JOAN OF ARC
# ==============================================================================
def build_joan():
    reset_scene()

    # Materials
    mat_skin = create_mat("JoanSkin", (0.92, 0.76, 0.68, 1.0), roughness=0.5)
    mat_hair = create_mat("JoanDarkHair", (0.12, 0.09, 0.08, 1.0), roughness=0.7)
    mat_steel = create_mat("FrenchPlate", (0.86, 0.90, 0.94, 1.0), metallic=0.92, roughness=0.18)
    mat_dark_steel = create_mat("DarkSteelJoints", (0.42, 0.45, 0.50, 1.0), metallic=0.85, roughness=0.3)
    mat_tabard = create_mat("RoyalAzure", (0.08, 0.28, 0.75, 1.0), roughness=0.5)
    mat_fleur = create_mat("FleurDeLisGold", (1.0, 0.84, 0.20, 1.0), metallic=0.9, roughness=0.2,
                          emission=(1.0, 0.82, 0.20, 1.0), emission_strength=0.3)
    mat_halo = create_mat("SaintHalo", (1.0, 0.95, 0.45, 1.0), metallic=0.2, roughness=0.1,
                          emission=(1.0, 0.92, 0.4, 1.0), emission_strength=2.5)
    mat_eye = create_mat("EyeGloss", (0.12, 0.12, 0.14, 1.0), roughness=0.1)

    root = bpy.data.objects.new("JoanOfArc", None)
    bpy.context.scene.collection.objects.link(root)

    # --- TORSO --- (Steel Cuirass + Azure Tabard + Gorget)
    torso_parts = []
    torso_parts.append(add_cube("SteelCuirass", (0, 0, 1.06), (0.38, 0.23, 0.36), mat_steel))
    # Royal Azure Tabard draped over front & back
    torso_parts.append(add_cube("TabardFront", (0, 0.12, 1.02), (0.28, 0.02, 0.44), mat_tabard))
    torso_parts.append(add_cube("TabardBack", (0, -0.12, 1.02), (0.28, 0.02, 0.44), mat_tabard))
    # Gold Fleur-de-lis on chest
    torso_parts.append(add_cube("FleurCenter", (0, 0.135, 1.10), (0.04, 0.015, 0.12), mat_fleur))
    torso_parts.append(add_cube("FleurLeft", (-0.06, 0.135, 1.08), (0.06, 0.015, 0.06), mat_fleur, (0, 0, 0.5)))
    torso_parts.append(add_cube("FleurRight", (0.06, 0.135, 1.08), (0.06, 0.015, 0.06), mat_fleur, (0, 0, -0.5)))
    # Steel Belt & Faulds
    torso_parts.append(add_cube("SteelBelt", (0, 0, 0.86), (0.39, 0.24, 0.07), mat_dark_steel))
    torso_parts.append(add_cube("Faulds", (0, 0, 0.80), (0.37, 0.23, 0.09), mat_steel))
    # Pauldrons
    torso_parts.append(add_cube("LeftPuldron", (-0.23, 0, 1.22), (0.13, 0.22, 0.07), mat_steel, (0, 0.2, 0)))
    torso_parts.append(add_cube("RightPuldron", (0.23, 0, 1.22), (0.13, 0.22, 0.07), mat_steel, (0, -0.2, 0)))
    # Steel Gorget (Neck guard)
    torso_parts.append(add_cylinder("Gorget", (0, 0, 1.26), 0.085, 0.08, mat_steel))

    torso_obj = join_and_set_pivot(torso_parts, "Torso", (0, 0, 0.86), parent=root)

    # --- HEAD --- (Knight Sallet Helmet + Open Brow Face + Saint's Halo)
    head_parts = []
    # Face inside helmet
    head_parts.append(add_sphere("FaceBase", (0, 0.02, 1.42), 0.15, mat_skin, scale=(0.92, 0.95, 1.02)))
    for ex in [-0.055, 0.055]:
        head_parts.append(add_sphere(f"Eye_{ex}", (ex, 0.14, 1.43), 0.020, mat_eye, scale=(0.85, 0.35, 1.2)))
    # Flowing dark hair under helmet
    head_parts.append(add_cube("HairL", (-0.14, -0.01, 1.34), (0.04, 0.10, 0.18), mat_hair))
    head_parts.append(add_cube("HairR", (0.14, -0.01, 1.34), (0.04, 0.10, 0.18), mat_hair))
    head_parts.append(add_cube("HairBack", (0, -0.11, 1.32), (0.20, 0.06, 0.20), mat_hair))
    # Steel Sallet Helmet Dome
    head_parts.append(add_sphere("SalletDome", (0, 0, 1.46), 0.165, mat_steel, scale=(0.96, 1.0, 1.02)))
    # Sallet Visor Brow Rim
    head_parts.append(add_cube("VisorBrow", (0, 0.13, 1.48), (0.22, 0.06, 0.04), mat_steel, (0.15, 0, 0)))
    # Flared Sallet Neck Tail at back
    head_parts.append(add_cube("SalletTail", (0, -0.13, 1.37), (0.22, 0.08, 0.10), mat_steel, (-0.30, 0, 0)))
    # Holy Golden Saint's Halo
    head_parts.append(add_torus("SaintHalo", (0, 0, 1.68), 0.20, 0.018, mat_halo, (0.08, 0, 0)))

    join_and_set_pivot(head_parts, "Head", (0, 0, 1.28), parent=torso_obj)

    # --- ARMS --- (Shoulder pivot at ±0.28, 0, 1.20)
    l_arm_parts = []
    l_arm_parts.append(add_cube("L_UpperArmor", (-0.28, 0, 1.13), (0.10, 0.12, 0.15), mat_steel))
    l_arm_parts.append(add_cylinder("L_Elbow", (-0.28, 0, 1.01), 0.05, 0.10, mat_dark_steel))
    l_arm_parts.append(add_cube("L_Vambrace", (-0.28, 0, 0.89), (0.09, 0.10, 0.14), mat_steel))
    l_arm_parts.append(add_cube("L_Gauntlet", (-0.28, 0.01, 0.77), (0.08, 0.09, 0.10), mat_steel))
    join_and_set_pivot(l_arm_parts, "LeftArm", (-0.28, 0, 1.20), parent=root)

    r_arm_parts = []
    r_arm_parts.append(add_cube("R_UpperArmor", (0.28, 0, 1.13), (0.10, 0.12, 0.15), mat_steel))
    r_arm_parts.append(add_cylinder("R_Elbow", (0.28, 0, 1.01), 0.05, 0.10, mat_dark_steel))
    r_arm_parts.append(add_cube("R_Vambrace", (0.28, 0, 0.89), (0.09, 0.10, 0.14), mat_steel))
    r_arm_parts.append(add_cube("R_Gauntlet", (0.28, 0.01, 0.77), (0.08, 0.09, 0.10), mat_steel))
    join_and_set_pivot(r_arm_parts, "RightArm", (0.28, 0, 1.20), parent=root)

    # --- LEGS --- (Hip pivot at ±0.13, 0, 0.78)
    l_leg_parts = []
    l_leg_parts.append(add_cube("L_Cuisses", (-0.13, 0, 0.62), (0.11, 0.13, 0.28), mat_steel))
    l_leg_parts.append(add_sphere("L_Poleyn", (-0.13, 0.06, 0.48), 0.06, mat_dark_steel))
    l_leg_parts.append(add_cube("L_Greave", (-0.13, 0.01, 0.33), (0.10, 0.11, 0.26), mat_steel))
    l_leg_parts.append(add_cube("L_Sabaton", (-0.13, 0.05, 0.07), (0.095, 0.18, 0.08), mat_steel))
    join_and_set_pivot(l_leg_parts, "LeftLeg", (-0.13, 0, 0.78), parent=root)

    r_leg_parts = []
    r_leg_parts.append(add_cube("R_Cuisses", (0.13, 0, 0.62), (0.11, 0.13, 0.28), mat_steel))
    r_leg_parts.append(add_sphere("R_Poleyn", (0.13, 0.06, 0.48), 0.06, mat_dark_steel))
    r_leg_parts.append(add_cube("R_Greave", (0.13, 0.01, 0.33), (0.10, 0.11, 0.26), mat_steel))
    r_leg_parts.append(add_cube("R_Sabaton", (0.13, 0.05, 0.07), (0.095, 0.18, 0.08), mat_steel))
    join_and_set_pivot(r_leg_parts, "RightLeg", (0.13, 0, 0.78), parent=root)

    # --- ROYAL AZURE CAPE --- (Pivot at upper back: 0, -0.13, 1.22)
    cape_parts = []
    cape_parts.append(add_cube("CapeTop", (0, -0.13, 1.21), (0.34, 0.03, 0.08), mat_tabard))
    cape_parts.append(add_sphere("CapeClaspL", (-0.14, -0.11, 1.23), 0.028, mat_fleur))
    cape_parts.append(add_sphere("CapeClaspR", (0.14, -0.11, 1.23), 0.028, mat_fleur))
    cape_parts.append(add_cube("CapeMid", (0, -0.16, 0.86), (0.38, 0.025, 0.62), mat_tabard, (-0.07, 0, 0)))
    cape_parts.append(add_cube("CapeLow", (0, -0.20, 0.46), (0.44, 0.025, 0.32), mat_tabard, (-0.12, 0, 0)))
    join_and_set_pivot(cape_parts, "Cape", (0, -0.13, 1.22), parent=torso_obj)

    # --- KNIGHT LONGSWORD --- (At left hip)
    sword_parts = []
    sword_parts.append(add_cube("Scabbard", (-0.23, 0.02, 0.74), (0.045, 0.07, 0.46), mat_dark_steel, (0.25, 0.1, 0)))
    sword_parts.append(add_cube("Crossguard", (-0.23, 0.05, 0.98), (0.16, 0.03, 0.03), mat_fleur, (0.25, 0.1, 0)))
    sword_parts.append(add_cylinder("Grip", (-0.23, 0.07, 1.06), 0.02, 0.14, mat_steel, (0.25, 0.1, 0)))
    sword_parts.append(add_sphere("Pommel", (-0.23, 0.09, 1.14), 0.03, mat_fleur))
    join_and_set_pivot(sword_parts, "Sword", (-0.23, 0.02, 0.86), parent=torso_obj)

    # Export
    filepath = os.path.join(OUTPUT_DIR, "joan.glb")
    bpy.ops.export_scene.gltf(filepath=filepath, export_format='GLB')
    print("Exported Joan:", filepath)


# ==============================================================================
# 3. HARRIET TUBMAN
# ==============================================================================
def build_harriet():
    reset_scene()

    # Materials
    mat_skin = create_mat("HarrietSkin", (0.34, 0.22, 0.16, 1.0), roughness=0.55)
    mat_coat = create_mat("TravelerCoat", (0.25, 0.21, 0.18, 1.0), roughness=0.65)
    mat_collar = create_mat("CoatCollar", (0.19, 0.16, 0.13, 1.0), roughness=0.6)
    mat_wrap = create_mat("HeadwrapEmerald", (0.18, 0.38, 0.24, 1.0), roughness=0.55)
    mat_wrap_accent = create_mat("HeadwrapOchre", (0.78, 0.54, 0.18, 1.0), roughness=0.5)
    mat_brass = create_mat("AntiqueBrass", (0.88, 0.70, 0.26, 1.0), metallic=0.90, roughness=0.22)
    mat_pants = create_mat("RuggedTrousers", (0.20, 0.20, 0.22, 1.0), roughness=0.7)
    mat_boots = create_mat("TravelBoots", (0.14, 0.10, 0.07, 1.0), roughness=0.5)
    mat_flame = create_mat("FreedomFlame", (1.0, 0.85, 0.35, 1.0), metallic=0.0, roughness=0.1,
                           emission=(1.0, 0.75, 0.25, 1.0), emission_strength=4.5)
    mat_glass = create_mat("LanternGlass", (0.95, 0.92, 0.85, 0.4), roughness=0.1)
    mat_eye = create_mat("EyeGloss", (0.08, 0.08, 0.08, 1.0), roughness=0.1)

    root = bpy.data.objects.new("HarrietTubman", None)
    bpy.context.scene.collection.objects.link(root)

    # --- TORSO --- (Wool Overcoat + Collar + Scarf + Brass Buttons)
    torso_parts = []
    torso_parts.append(add_cube("OvercoatBody", (0, 0, 1.06), (0.40, 0.25, 0.38), mat_coat))
    torso_parts.append(add_cube("OvercoatSkirt", (0, 0, 0.78), (0.42, 0.26, 0.20), mat_coat))
    # Lapels
    torso_parts.append(add_cube("LapelL", (-0.10, 0.13, 1.18), (0.10, 0.03, 0.14), mat_collar, (0, 0, 0.15)))
    torso_parts.append(add_cube("LapelR", (0.10, 0.13, 1.18), (0.10, 0.03, 0.14), mat_collar, (0, 0, -0.15)))
    # Warm Scarf around neck
    torso_parts.append(add_cylinder("NeckScarf", (0, 0, 1.26), 0.10, 0.08, mat_wrap_accent))
    # Double-Breasted Brass Buttons
    for row in range(3):
        z_pos = 1.16 - row * 0.10
        torso_parts.append(add_sphere(f"BtnL_{row}", (-0.07, 0.135, z_pos), 0.018, mat_brass))
        torso_parts.append(add_sphere(f"BtnR_{row}", (0.07, 0.135, z_pos), 0.018, mat_brass))
    # Waist Belt & Utility Pouch
    torso_parts.append(add_cube("Belt", (0, 0, 0.88), (0.41, 0.26, 0.07), mat_collar))
    torso_parts.append(add_cube("BeltBuckle", (0, 0.135, 0.88), (0.07, 0.02, 0.07), mat_brass))
    torso_parts.append(add_cube("Pouch", (0.21, 0.04, 0.86), (0.06, 0.12, 0.10), mat_collar))

    torso_obj = join_and_set_pivot(torso_parts, "Torso", (0, 0, 0.88), parent=root)

    # --- HEAD --- (Sculpted Tignon / Headwrap + Face + Eyes)
    head_parts = []
    head_parts.append(add_sphere("FaceBase", (0, 0.02, 1.42), 0.15, mat_skin, scale=(0.92, 0.95, 1.02)))
    head_parts.append(add_cube("Nose", (0, 0.165, 1.41), (0.035, 0.04, 0.05), mat_skin))
    for ex in [-0.055, 0.055]:
        head_parts.append(add_sphere(f"Eye_{ex}", (ex, 0.14, 1.43), 0.020, mat_eye, scale=(0.85, 0.35, 1.2)))
    # Sculpted Headwrap Dome
    head_parts.append(add_sphere("WrapDome", (0, -0.02, 1.46), 0.165, mat_wrap, scale=(0.95, 0.98, 1.04)))
    # Fabric Fold Rings
    head_parts.append(add_torus("WrapFold1", (0, 0.01, 1.48), 0.165, 0.025, mat_wrap_accent, (0.15, 0, 0)))
    head_parts.append(add_torus("WrapFold2", (0, -0.02, 1.52), 0.145, 0.025, mat_wrap, (-0.1, 0, 0)))
    head_parts.append(add_cube("WrapKnot", (0, -0.13, 1.48), (0.09, 0.06, 0.08), mat_wrap_accent, (0.25, 0, 0)))

    join_and_set_pivot(head_parts, "Head", (0, 0, 1.28), parent=torso_obj)

    # --- ARMS --- (Shoulder pivot at ±0.28, 0, 1.20)
    l_arm_parts = []
    l_arm_parts.append(add_cube("L_SleeveUpper", (-0.28, 0, 1.13), (0.11, 0.13, 0.15), mat_coat))
    l_arm_parts.append(add_cube("L_SleeveForearm", (-0.28, 0, 0.97), (0.10, 0.12, 0.18), mat_coat))
    l_arm_parts.append(add_cube("L_Cuff", (-0.28, 0, 0.85), (0.105, 0.125, 0.05), mat_collar))
    l_arm_parts.append(add_sphere("L_Hand", (-0.28, 0.01, 0.78), 0.055, mat_skin))
    join_and_set_pivot(l_arm_parts, "LeftArm", (-0.28, 0, 1.20), parent=root)

    # Right Arm (Holds Freedom Lantern forward!)
    r_arm_parts = []
    r_arm_parts.append(add_cube("R_SleeveUpper", (0.28, 0, 1.13), (0.11, 0.13, 0.15), mat_coat))
    r_arm_parts.append(add_cube("R_SleeveForearm", (0.28, 0.03, 0.97), (0.10, 0.12, 0.18), mat_coat, (0.15, 0, 0)))
    r_arm_parts.append(add_cube("R_Cuff", (0.28, 0.06, 0.85), (0.105, 0.125, 0.05), mat_collar, (0.15, 0, 0)))
    r_arm_parts.append(add_sphere("R_Hand", (0.28, 0.09, 0.79), 0.055, mat_skin))

    # --- THE FREEDOM LANTERN (Attached to Right Hand) ---
    r_arm_parts.append(add_torus("LanternRing", (0.28, 0.09, 0.76), 0.045, 0.009, mat_brass, (0, 1.57, 0)))
    r_arm_parts.append(add_cylinder("LanternCap", (0.28, 0.09, 0.69), 0.065, 0.03, mat_brass))
    # 4 Brass Cage Bars
    for bx, by in [(-0.045, -0.045), (0.045, -0.045), (-0.045, 0.045), (0.045, 0.045)]:
        r_arm_parts.append(add_cylinder(f"Bar_{bx}", (0.28 + bx, 0.09 + by, 0.60), 0.006, 0.15, mat_brass))
    r_arm_parts.append(add_cylinder("LanternGlass", (0.28, 0.09, 0.60), 0.055, 0.14, mat_glass))
    r_arm_parts.append(add_sphere("FlameCore", (0.28, 0.09, 0.60), 0.032, mat_flame))
    r_arm_parts.append(add_cylinder("LanternBase", (0.28, 0.09, 0.51), 0.065, 0.03, mat_brass))

    join_and_set_pivot(r_arm_parts, "RightArm", (0.28, 0, 1.20), parent=root)

    # --- LEGS --- (Hip pivot at ±0.13, 0, 0.78)
    l_leg_parts = []
    l_leg_parts.append(add_cube("L_Thigh", (-0.13, 0, 0.62), (0.11, 0.13, 0.28), mat_pants))
    l_leg_parts.append(add_cube("L_Shin", (-0.13, 0, 0.35), (0.10, 0.12, 0.28), mat_pants))
    l_leg_parts.append(add_cube("L_Boot", (-0.13, 0.05, 0.07), (0.095, 0.18, 0.08), mat_boots))
    join_and_set_pivot(l_leg_parts, "LeftLeg", (-0.13, 0, 0.78), parent=root)

    r_leg_parts = []
    r_leg_parts.append(add_cube("R_Thigh", (0.13, 0, 0.62), (0.11, 0.13, 0.28), mat_pants))
    r_leg_parts.append(add_cube("R_Shin", (0.13, 0, 0.35), (0.10, 0.12, 0.28), mat_pants))
    r_leg_parts.append(add_cube("R_Boot", (0.13, 0.05, 0.07), (0.095, 0.18, 0.08), mat_boots))
    join_and_set_pivot(r_leg_parts, "RightLeg", (0.13, 0, 0.78), parent=root)

    # Export
    filepath = os.path.join(OUTPUT_DIR, "harriet.glb")
    bpy.ops.export_scene.gltf(filepath=filepath, export_format='GLB')
    print("Exported Harriet:", filepath)


if __name__ == "__main__":
    print("=== Generating Upgraded Stylized Characters ===")
    build_caesar()
    build_joan()
    build_harriet()
    print("=== All Models Generated Successfully! ===")
