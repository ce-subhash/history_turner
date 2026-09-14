"""
generate_characters.py
Headless Blender script to procedurally model and export high-quality, stylized 3D
characters for "Timetracks: Rulers & Rebels":
  1. Julius Caesar  -> res://assets/characters/caesar.glb
  2. Joan of Arc    -> res://assets/characters/joan.glb
  3. Harriet Tubman -> res://assets/characters/harriet.glb

Coordinate mapping from Blender to glTF/Godot:
  Blender +X -> glTF +X (Right)
  Blender -X -> glTF -X (Left)
  Blender +Z -> glTF +Y (Up)
  Blender +Y -> glTF -Z (Forward / Direction runner travels)
  Blender -Y -> glTF +Z (Backward / Facing runner camera)
"""

import bpy
import math
import os

OUTPUT_DIR = "/Users/subhash/Games/assets/characters"
os.makedirs(OUTPUT_DIR, exist_ok=True)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Ensure a collection exists
    if not bpy.data.collections:
        col = bpy.data.collections.new("Collection")
        bpy.context.scene.collection.children.link(col)


def create_material(name, color, metallic=0.0, roughness=0.5, emission_color=(0, 0, 0, 1), emission_strength=0.0):
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
                bsdf.inputs["Emission Color"].default_value = emission_color
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def add_cube(name, location, scale, material=None, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if material:
        obj.data.materials.append(material)
    return obj


def add_cylinder(name, location, radius, depth, material=None, rotation=(0, 0, 0), vertices=12):
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
    if material:
        obj.data.materials.append(material)
    return obj


def add_sphere(name, location, radius, material=None, segments=12, ring_count=8):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=ring_count,
        radius=radius,
        location=location
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if material:
        obj.data.materials.append(material)
    return obj


def add_torus(name, location, major_radius, minor_radius, material=None, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=16,
        minor_segments=8,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=location,
        rotation=rotation
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
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
    return obj


# ==============================================================================
# 1. JULIUS CAESAR
# ==============================================================================
def build_caesar():
    reset_scene()

    # Materials
    mat_skin = create_material("CaesarSkin", (0.85, 0.68, 0.55, 1.0), roughness=0.6)
    mat_hair = create_material("CaesarHair", (0.28, 0.22, 0.18, 1.0), roughness=0.7)
    mat_tunic = create_material("RomanTunic", (0.95, 0.93, 0.90, 1.0), roughness=0.5)
    mat_lorica = create_material("LoricaBronze", (0.82, 0.58, 0.22, 1.0), metallic=0.88, roughness=0.22)
    mat_gold = create_material("ImperialGold", (1.0, 0.82, 0.18, 1.0), metallic=0.95, roughness=0.18,
                               emission_color=(1.0, 0.78, 0.15, 1.0), emission_strength=0.3)
    mat_leather = create_material("RomanLeather", (0.35, 0.18, 0.08, 1.0), roughness=0.5)
    mat_cape = create_material("TyrianCrimson", (0.78, 0.06, 0.14, 1.0), roughness=0.65)
    mat_steel = create_material("GladiusSteel", (0.85, 0.88, 0.90, 1.0), metallic=0.92, roughness=0.15)

    root = bpy.data.objects.new("Caesar", None)
    bpy.context.scene.collection.objects.link(root)

    # --- TORSO ---
    torso_parts = []
    # Under-tunic
    torso_parts.append(add_cube("TunicBase", (0, 0, 0.92), (0.42, 0.26, 0.36), mat_tunic))
    # Lorica Segmentata (Cuirass)
    torso_parts.append(add_cube("LoricaChest", (0, 0, 1.08), (0.46, 0.30, 0.40), mat_lorica))
    # Golden Imperial Eagle on chest (+Y is forward)
    torso_parts.append(add_cube("EagleWings", (0, 0.16, 1.14), (0.28, 0.04, 0.10), mat_gold))
    torso_parts.append(add_cube("EagleBody", (0, 0.165, 1.10), (0.08, 0.04, 0.16), mat_gold))
    # Roman Leather Belt (Cingulum)
    torso_parts.append(add_cube("Cingulum", (0, 0, 0.86), (0.48, 0.31, 0.08), mat_leather))
    torso_parts.append(add_cube("CingulumBuckle", (0, 0.16, 0.86), (0.12, 0.04, 0.09), mat_gold))
    # Pteruges (Hanging leather battle skirt straps)
    for i in range(5):
        x_pos = -0.16 + i * 0.08
        torso_parts.append(add_cube(f"Pteruges_{i}", (x_pos, 0.14, 0.74), (0.06, 0.03, 0.20), mat_leather))
        torso_parts.append(add_cube(f"PterugesStud_{i}", (x_pos, 0.156, 0.67), (0.04, 0.02, 0.04), mat_gold))
    # Neck
    torso_parts.append(add_cylinder("Neck", (0, 0, 1.34), 0.09, 0.14, mat_skin))
    # Bronze Shoulder Pauldrons
    torso_parts.append(add_cube("LeftPuldron", (-0.26, 0, 1.28), (0.14, 0.28, 0.08), mat_lorica, (0, 0.2, 0)))
    torso_parts.append(add_cube("RightPuldron", (0.26, 0, 1.28), (0.14, 0.28, 0.08), mat_lorica, (0, -0.2, 0)))

    torso_obj = join_and_set_pivot(torso_parts, "Torso", (0, 0, 0.86), parent=root)

    # --- HEAD ---
    head_parts = []
    # Face & Head
    head_parts.append(add_sphere("HeadBase", (0, 0.02, 1.54), 0.18, mat_skin))
    # Roman Brow & Nose
    head_parts.append(add_cube("RomanNose", (0, 0.20, 1.54), (0.04, 0.06, 0.10), mat_skin))
    # Cropped Roman Hair
    head_parts.append(add_sphere("HairBack", (0, -0.04, 1.58), 0.19, mat_hair))
    head_parts.append(add_cube("HairBangs", (0, 0.08, 1.68), (0.20, 0.14, 0.06), mat_hair))
    # Golden Laurel Wreath (Crown of Victory)
    head_parts.append(add_torus("LaurelRing", (0, 0.02, 1.62), 0.20, 0.025, mat_gold, (0.15, 0, 0)))
    # Golden leaves around wreath
    for angle in [-45, -20, 0, 20, 45]:
        rad = math.radians(angle)
        lx = math.sin(rad) * 0.20
        ly = math.cos(rad) * 0.20 + 0.02
        head_parts.append(add_cube(f"LaurelLeaf_{angle}", (lx, ly, 1.63), (0.05, 0.03, 0.015), mat_gold, (0, 0, -rad)))

    join_and_set_pivot(head_parts, "Head", (0, 0, 1.34), parent=torso_obj)

    # --- LEFT ARM --- (Shoulder pivot at -0.34, 0, 1.24)
    l_arm_parts = []
    l_arm_parts.append(add_cube("L_Shoulder", (-0.34, 0, 1.16), (0.12, 0.14, 0.18), mat_tunic))
    l_arm_parts.append(add_cylinder("L_UpperArm", (-0.34, 0, 1.02), 0.065, 0.18, mat_skin))
    l_arm_parts.append(add_cube("L_Bracer", (-0.34, 0, 0.88), (0.10, 0.11, 0.14), mat_lorica))
    l_arm_parts.append(add_sphere("L_Hand", (-0.34, 0.02, 0.76), 0.065, mat_skin))
    join_and_set_pivot(l_arm_parts, "LeftArm", (-0.34, 0, 1.24), parent=root)

    # --- RIGHT ARM --- (Shoulder pivot at +0.34, 0, 1.24)
    r_arm_parts = []
    r_arm_parts.append(add_cube("R_Shoulder", (0.34, 0, 1.16), (0.12, 0.14, 0.18), mat_tunic))
    r_arm_parts.append(add_cylinder("R_UpperArm", (0.34, 0, 1.02), 0.065, 0.18, mat_skin))
    r_arm_parts.append(add_cube("R_Bracer", (0.34, 0, 0.88), (0.10, 0.11, 0.14), mat_lorica))
    r_arm_parts.append(add_sphere("R_Hand", (0.34, 0.02, 0.76), 0.065, mat_skin))
    join_and_set_pivot(r_arm_parts, "RightArm", (0.34, 0, 1.24), parent=root)

    # --- LEFT LEG --- (Hip pivot at -0.16, 0, 0.75)
    l_leg_parts = []
    l_leg_parts.append(add_cube("L_Thigh", (-0.16, 0, 0.58), (0.14, 0.16, 0.32), mat_tunic))
    l_leg_parts.append(add_cube("L_Greave", (-0.16, 0.01, 0.28), (0.13, 0.14, 0.32), mat_lorica))
    l_leg_parts.append(add_cube("L_Foot", (-0.16, 0.06, 0.06), (0.12, 0.22, 0.10), mat_leather))
    join_and_set_pivot(l_leg_parts, "LeftLeg", (-0.16, 0, 0.75), parent=root)

    # --- RIGHT LEG --- (Hip pivot at +0.16, 0, 0.75)
    r_leg_parts = []
    r_leg_parts.append(add_cube("R_Thigh", (0.16, 0, 0.58), (0.14, 0.16, 0.32), mat_tunic))
    r_leg_parts.append(add_cube("R_Greave", (0.16, 0.01, 0.28), (0.13, 0.14, 0.32), mat_lorica))
    r_leg_parts.append(add_cube("R_Foot", (0.16, 0.06, 0.06), (0.12, 0.22, 0.10), mat_leather))
    join_and_set_pivot(r_leg_parts, "RightLeg", (0.16, 0, 0.75), parent=root)

    # --- CRIMSON CAPE --- (Pivot at upper back: 0, -0.16, 1.26)
    # Angled back (-Y in Blender = +Z in Godot)
    cape_parts = []
    cape_parts.append(add_cube("CapeTop", (0, -0.16, 1.25), (0.42, 0.04, 0.10), mat_cape))
    # Golden shoulder clasps (Fibulae)
    cape_parts.append(add_sphere("FibulaL", (-0.18, -0.14, 1.27), 0.035, mat_gold))
    cape_parts.append(add_sphere("FibulaR", (0.18, -0.14, 1.27), 0.035, mat_gold))
    # Flowing cloth draped down
    cape_parts.append(add_cube("CapeMid", (0, -0.20, 0.88), (0.48, 0.03, 0.65), mat_cape, (-0.08, 0, 0)))
    cape_parts.append(add_cube("CapeLow", (0, -0.24, 0.44), (0.54, 0.03, 0.36), mat_cape, (-0.14, 0, 0)))
    join_and_set_pivot(cape_parts, "Cape", (0, -0.16, 1.26), parent=torso_obj)

    # --- GLADIUS (Accessory at left hip) ---
    sword_parts = []
    sword_parts.append(add_cube("Scabbard", (-0.28, 0.02, 0.78), (0.06, 0.08, 0.42), mat_leather, (0.3, 0.1, 0)))
    sword_parts.append(add_cube("SwordHilt", (-0.28, 0.06, 1.01), (0.04, 0.04, 0.12), mat_gold, (0.3, 0.1, 0)))
    sword_parts.append(add_sphere("SwordPommel", (-0.28, 0.09, 1.08), 0.035, mat_gold))
    join_and_set_pivot(sword_parts, "Gladius", (-0.28, 0.02, 0.86), parent=torso_obj)

    # Export GLB
    filepath = os.path.join(OUTPUT_DIR, "caesar.glb")
    bpy.ops.export_scene.gltf(filepath=filepath, export_format='GLB')
    print("Exported:", filepath)


# ==============================================================================
# 2. JOAN OF ARC
# ==============================================================================
def build_joan():
    reset_scene()

    # Materials
    mat_skin = create_material("JoanSkin", (0.92, 0.76, 0.68, 1.0), roughness=0.6)
    mat_hair = create_material("JoanDarkHair", (0.12, 0.09, 0.08, 1.0), roughness=0.8)
    mat_steel = create_material("FrenchPlate", (0.86, 0.90, 0.94, 1.0), metallic=0.92, roughness=0.18)
    mat_dark_steel = create_material("DarkSteelJoints", (0.45, 0.48, 0.52, 1.0), metallic=0.85, roughness=0.3)
    mat_tabard = create_material("RoyalAzure", (0.08, 0.28, 0.75, 1.0), roughness=0.55)
    mat_fleur = create_material("FleurDeLisGold", (1.0, 0.84, 0.20, 1.0), metallic=0.9, roughness=0.2,
                                emission_color=(1.0, 0.82, 0.20, 1.0), emission_strength=0.25)
    mat_halo = create_material("SaintHalo", (1.0, 0.95, 0.4, 1.0), metallic=0.2, roughness=0.1,
                               emission_color=(1.0, 0.92, 0.35, 1.0), emission_strength=2.2)

    root = bpy.data.objects.new("JoanOfArc", None)
    bpy.context.scene.collection.objects.link(root)

    # --- TORSO ---
    torso_parts = []
    # Steel Cuirass under-layer
    torso_parts.append(add_cube("SteelCuirass", (0, 0, 1.04), (0.44, 0.28, 0.42), mat_steel))
    # Royal Azure Tabard (front and back cloth draped over armor)
    torso_parts.append(add_cube("TabardFront", (0, 0.15, 0.98), (0.34, 0.03, 0.52), mat_tabard))
    torso_parts.append(add_cube("TabardBack", (0, -0.15, 0.98), (0.34, 0.03, 0.52), mat_tabard))
    # Gold Fleur-de-lis on chest
    torso_parts.append(add_cube("FleurCenter", (0, 0.17, 1.12), (0.05, 0.02, 0.16), mat_fleur))
    torso_parts.append(add_cube("FleurLeftPetal", (-0.08, 0.17, 1.10), (0.08, 0.02, 0.08), mat_fleur, (0, 0, 0.5)))
    torso_parts.append(add_cube("FleurRightPetal", (0.08, 0.17, 1.10), (0.08, 0.02, 0.08), mat_fleur, (0, 0, -0.5)))
    # Steel Belt & Faulds (waist armor)
    torso_parts.append(add_cube("SteelBelt", (0, 0, 0.86), (0.46, 0.29, 0.08), mat_dark_steel))
    torso_parts.append(add_cube("FauldsArmor", (0, 0, 0.78), (0.44, 0.28, 0.12), mat_steel))
    # Steel Pauldrons (layered shoulder armor)
    torso_parts.append(add_cube("LeftShoulderGuard", (-0.26, 0, 1.28), (0.16, 0.26, 0.10), mat_steel, (0, 0.25, 0)))
    torso_parts.append(add_cube("RightShoulderGuard", (0.26, 0, 1.28), (0.16, 0.26, 0.10), mat_steel, (0, -0.25, 0)))
    # Neck Gorget (steel neck protection)
    torso_parts.append(add_cylinder("Gorget", (0, 0, 1.34), 0.10, 0.12, mat_steel))

    torso_obj = join_and_set_pivot(torso_parts, "Torso", (0, 0, 0.86), parent=root)

    # --- HEAD (Knight Sallet Helmet & Halo) ---
    head_parts = []
    # Face visible in open visor
    head_parts.append(add_sphere("FaceBase", (0, 0.03, 1.52), 0.16, mat_skin))
    # Flowing dark hair strands out from under helmet
    head_parts.append(add_cube("HairLeft", (-0.16, -0.02, 1.44), (0.06, 0.12, 0.22), mat_hair))
    head_parts.append(add_cube("HairRight", (0.16, -0.02, 1.44), (0.06, 0.12, 0.22), mat_hair))
    head_parts.append(add_cube("HairBack", (0, -0.14, 1.42), (0.24, 0.08, 0.26), mat_hair))
    # Steel Sallet Helmet Dome
    head_parts.append(add_sphere("SalletDome", (0, 0, 1.58), 0.19, mat_steel))
    # Sallet Visor Rim / Brow
    head_parts.append(add_cube("VisorRim", (0, 0.16, 1.58), (0.26, 0.08, 0.06), mat_steel, (0.2, 0, 0)))
    # Flared Sallet Neck Guard (historic French sallet flared tail at back)
    head_parts.append(add_cube("SalletTail", (0, -0.16, 1.48), (0.28, 0.10, 0.14), mat_steel, (-0.35, 0, 0)))
    # Golden Fleur-de-lis crest on helmet peak
    head_parts.append(add_cube("HelmetCrest", (0, 0.06, 1.76), (0.04, 0.10, 0.10), mat_fleur))
    # Holy Golden Saint's Halo (floating luminous ring above head)
    head_parts.append(add_torus("HolyHalo", (0, 0, 1.84), 0.24, 0.02, mat_halo, (0.1, 0, 0)))

    join_and_set_pivot(head_parts, "Head", (0, 0, 1.34), parent=torso_obj)

    # --- LEFT ARM --- (Shoulder pivot at -0.34, 0, 1.24)
    l_arm_parts = []
    l_arm_parts.append(add_cube("L_UpperArmor", (-0.34, 0, 1.14), (0.12, 0.14, 0.18), mat_steel))
    l_arm_parts.append(add_cylinder("L_Elbow", (-0.34, 0, 1.00), 0.065, 0.12, mat_dark_steel))
    l_arm_parts.append(add_cube("L_Vambrace", (-0.34, 0, 0.88), (0.11, 0.12, 0.16), mat_steel))
    l_arm_parts.append(add_cube("L_Gauntlet", (-0.34, 0.02, 0.74), (0.10, 0.11, 0.12), mat_steel))
    join_and_set_pivot(l_arm_parts, "LeftArm", (-0.34, 0, 1.24), parent=root)

    # --- RIGHT ARM --- (Shoulder pivot at +0.34, 0, 1.24)
    r_arm_parts = []
    r_arm_parts.append(add_cube("R_UpperArmor", (0.34, 0, 1.14), (0.12, 0.14, 0.18), mat_steel))
    r_arm_parts.append(add_cylinder("R_Elbow", (0.34, 0, 1.00), 0.065, 0.12, mat_dark_steel))
    r_arm_parts.append(add_cube("R_Vambrace", (0.34, 0, 0.88), (0.11, 0.12, 0.16), mat_steel))
    r_arm_parts.append(add_cube("R_Gauntlet", (0.34, 0.02, 0.74), (0.10, 0.11, 0.12), mat_steel))
    join_and_set_pivot(r_arm_parts, "RightArm", (0.34, 0, 1.24), parent=root)

    # --- LEFT LEG --- (Hip pivot at -0.16, 0, 0.75)
    l_leg_parts = []
    l_leg_parts.append(add_cube("L_Cuisses", (-0.16, 0, 0.58), (0.14, 0.16, 0.32), mat_steel))
    l_leg_parts.append(add_sphere("L_Poleyn", (-0.16, 0.08, 0.42), 0.075, mat_dark_steel))  # Knee poleyn
    l_leg_parts.append(add_cube("L_Greave", (-0.16, 0.01, 0.26), (0.13, 0.14, 0.30), mat_steel))
    l_leg_parts.append(add_cube("L_Sabaton", (-0.16, 0.07, 0.06), (0.12, 0.22, 0.10), mat_steel))  # Steel sabaton
    join_and_set_pivot(l_leg_parts, "LeftLeg", (-0.16, 0, 0.75), parent=root)

    # --- RIGHT LEG --- (Hip pivot at +0.16, 0, 0.75)
    r_leg_parts = []
    r_leg_parts.append(add_cube("R_Cuisses", (0.16, 0, 0.58), (0.14, 0.16, 0.32), mat_steel))
    r_leg_parts.append(add_sphere("R_Poleyn", (0.16, 0.08, 0.42), 0.075, mat_dark_steel))
    r_leg_parts.append(add_cube("R_Greave", (0.16, 0.01, 0.26), (0.13, 0.14, 0.30), mat_steel))
    r_leg_parts.append(add_cube("R_Sabaton", (0.16, 0.07, 0.06), (0.12, 0.22, 0.10), mat_steel))
    join_and_set_pivot(r_leg_parts, "RightLeg", (0.16, 0, 0.75), parent=root)

    # --- ROYAL AZURE CAPE --- (Pivot at upper back: 0, -0.16, 1.26)
    cape_parts = []
    cape_parts.append(add_cube("CapeTop", (0, -0.16, 1.25), (0.42, 0.04, 0.10), mat_tabard))
    cape_parts.append(add_sphere("CapeClaspL", (-0.18, -0.14, 1.27), 0.035, mat_fleur))
    cape_parts.append(add_sphere("CapeClaspR", (0.18, -0.14, 1.27), 0.035, mat_fleur))
    cape_parts.append(add_cube("CapeMid", (0, -0.20, 0.88), (0.46, 0.03, 0.65), mat_tabard, (-0.08, 0, 0)))
    cape_parts.append(add_cube("CapeLow", (0, -0.24, 0.44), (0.52, 0.03, 0.36), mat_tabard, (-0.14, 0, 0)))
    join_and_set_pivot(cape_parts, "Cape", (0, -0.16, 1.26), parent=torso_obj)

    # --- KNIGHT LONGSWORD (At left hip) ---
    sword_parts = []
    sword_parts.append(add_cube("Scabbard", (-0.28, 0.02, 0.72), (0.05, 0.08, 0.54), mat_dark_steel, (0.3, 0.1, 0)))
    sword_parts.append(add_cube("Crossguard", (-0.28, 0.06, 0.98), (0.20, 0.04, 0.04), mat_fleur, (0.3, 0.1, 0)))
    sword_parts.append(add_cylinder("SwordGrip", (-0.28, 0.08, 1.08), 0.025, 0.16, mat_steel, (0.3, 0.1, 0)))
    sword_parts.append(add_sphere("SwordPommel", (-0.28, 0.11, 1.18), 0.04, mat_fleur))
    join_and_set_pivot(sword_parts, "Sword", (-0.28, 0.02, 0.86), parent=torso_obj)

    # Export GLB
    filepath = os.path.join(OUTPUT_DIR, "joan.glb")
    bpy.ops.export_scene.gltf(filepath=filepath, export_format='GLB')
    print("Exported:", filepath)


# ==============================================================================
# 3. HARRIET TUBMAN
# ==============================================================================
def build_harriet():
    reset_scene()

    # Materials
    mat_skin = create_material("HarrietSkin", (0.30, 0.19, 0.14, 1.0), roughness=0.65)
    mat_coat = create_material("TravelerCoat", (0.24, 0.20, 0.17, 1.0), roughness=0.7)
    mat_collar = create_material("CoatCollar", (0.18, 0.15, 0.12, 1.0), roughness=0.6)
    mat_wrap = create_material("HeadwrapPattern", (0.22, 0.40, 0.28, 1.0), roughness=0.6)  # Deep emerald fabric
    mat_wrap_accent = create_material("HeadwrapAccent", (0.76, 0.52, 0.18, 1.0), roughness=0.55)  # Ochre fabric
    mat_brass = create_material("AntiqueBrass", (0.88, 0.70, 0.26, 1.0), metallic=0.88, roughness=0.25)
    mat_pants = create_material("RuggedTrousers", (0.18, 0.18, 0.20, 1.0), roughness=0.7)
    mat_boots = create_material("TravelBoots", (0.12, 0.08, 0.06, 1.0), roughness=0.55)
    mat_lantern_flame = create_material("LanternFlame", (1.0, 0.85, 0.35, 1.0), metallic=0.0, roughness=0.1,
                                        emission_color=(1.0, 0.75, 0.25, 1.0), emission_strength=4.0)
    mat_glass = create_material("LanternGlass", (0.95, 0.90, 0.80, 0.5), roughness=0.1)

    root = bpy.data.objects.new("HarrietTubman", None)
    bpy.context.scene.collection.objects.link(root)

    # --- TORSO ---
    torso_parts = []
    # Heavy Traveler's Wool Overcoat
    torso_parts.append(add_cube("OvercoatBody", (0, 0, 1.04), (0.46, 0.30, 0.44), mat_coat))
    # Coat Skirt flared out around hips
    torso_parts.append(add_cube("CoatSkirt", (0, 0, 0.74), (0.48, 0.32, 0.26), mat_coat))
    # Overcoat Collar & Lapels
    torso_parts.append(add_cube("LapelLeft", (-0.12, 0.16, 1.22), (0.12, 0.04, 0.18), mat_collar, (0, 0, 0.2)))
    torso_parts.append(add_cube("LapelRight", (0.12, 0.16, 1.22), (0.12, 0.04, 0.18), mat_collar, (0, 0, -0.2)))
    # Warm Scarf around neck
    torso_parts.append(add_cylinder("NeckScarf", (0, 0, 1.34), 0.12, 0.14, mat_wrap_accent))
    # Double-Breasted Brass Buttons down front
    for row in range(3):
        z_pos = 1.18 - row * 0.12
        torso_parts.append(add_sphere(f"BtnL_{row}", (-0.08, 0.16, z_pos), 0.022, mat_brass))
        torso_parts.append(add_sphere(f"BtnR_{row}", (0.08, 0.16, z_pos), 0.022, mat_brass))
    # Waist Belt & Utility Pouch
    torso_parts.append(add_cube("Belt", (0, 0, 0.88), (0.48, 0.31, 0.08), mat_collar))
    torso_parts.append(add_cube("BeltBuckle", (0, 0.16, 0.88), (0.08, 0.03, 0.08), mat_brass))
    torso_parts.append(add_cube("UtilityPouch", (0.24, 0.06, 0.86), (0.08, 0.14, 0.12), mat_collar))

    torso_obj = join_and_set_pivot(torso_parts, "Torso", (0, 0, 0.88), parent=root)

    # --- HEAD (Headwrap & Features) ---
    head_parts = []
    # Face Base
    head_parts.append(add_sphere("FaceBase", (0, 0.03, 1.52), 0.17, mat_skin))
    head_parts.append(add_cube("Nose", (0, 0.20, 1.52), (0.045, 0.05, 0.06), mat_skin))
    # Iconic Sculpted Headwrap (Tignon / Scarf)
    head_parts.append(add_sphere("HeadwrapMain", (0, -0.03, 1.58), 0.20, mat_wrap))
    # Fabric fold rings wrapping around forehead & crown
    head_parts.append(add_torus("WrapFold1", (0, 0.02, 1.62), 0.20, 0.035, mat_wrap_accent, (0.2, 0, 0)))
    head_parts.append(add_torus("WrapFold2", (0, -0.02, 1.66), 0.18, 0.035, mat_wrap, (-0.1, 0, 0)))
    # Knotted fabric gather at back / top
    head_parts.append(add_cube("WrapKnot", (0, -0.16, 1.62), (0.12, 0.08, 0.10), mat_wrap_accent, (0.3, 0, 0)))

    join_and_set_pivot(head_parts, "Head", (0, 0, 1.34), parent=torso_obj)

    # --- LEFT ARM --- (Shoulder pivot at -0.35, 0, 1.24)
    l_arm_parts = []
    l_arm_parts.append(add_cube("L_CoatSleeveUpper", (-0.35, 0, 1.14), (0.13, 0.15, 0.18), mat_coat))
    l_arm_parts.append(add_cube("L_CoatSleeveForearm", (-0.35, 0, 0.94), (0.12, 0.14, 0.22), mat_coat))
    l_arm_parts.append(add_cube("L_Cuff", (-0.35, 0, 0.81), (0.13, 0.15, 0.06), mat_collar))
    l_arm_parts.append(add_sphere("L_Hand", (-0.35, 0.02, 0.74), 0.065, mat_skin))
    join_and_set_pivot(l_arm_parts, "LeftArm", (-0.35, 0, 1.24), parent=root)

    # --- RIGHT ARM (Holds the Freedom Lantern!) --- (Shoulder pivot at +0.35, 0, 1.24)
    r_arm_parts = []
    r_arm_parts.append(add_cube("R_CoatSleeveUpper", (0.35, 0, 1.14), (0.13, 0.15, 0.18), mat_coat))
    # Forearm angled slightly forward (+Y) to hold lantern forward
    r_arm_parts.append(add_cube("R_CoatSleeveForearm", (0.35, 0.04, 0.94), (0.12, 0.14, 0.22), mat_coat, (0.2, 0, 0)))
    r_arm_parts.append(add_cube("R_Cuff", (0.35, 0.08, 0.82), (0.13, 0.15, 0.06), mat_collar, (0.2, 0, 0)))
    r_arm_parts.append(add_sphere("R_Hand", (0.35, 0.12, 0.76), 0.065, mat_skin))

    # --- THE FREEDOM LANTERN (Attached to Right Hand) ---
    # Lantern handle held in hand
    r_arm_parts.append(add_torus("LanternHandle", (0.35, 0.12, 0.74), 0.06, 0.012, mat_brass, (0, 1.57, 0)))
    # Brass Top Cap
    r_arm_parts.append(add_cylinder("LanternCap", (0.35, 0.12, 0.65), 0.08, 0.04, mat_brass))
    # 4 Brass protective cage bars
    for bar_idx, (bx, by) in enumerate([(-0.06, -0.06), (0.06, -0.06), (-0.06, 0.06), (0.06, 0.06)]):
        r_arm_parts.append(add_cylinder(f"CageBar_{bar_idx}", (0.35 + bx, 0.12 + by, 0.54), 0.008, 0.18, mat_brass))
    # Glass Cylinder Housing
    r_arm_parts.append(add_cylinder("LanternGlass", (0.35, 0.12, 0.54), 0.07, 0.17, mat_glass))
    # Glowing Freedom Flame Core!
    r_arm_parts.append(add_sphere("FreedomFlame", (0.35, 0.12, 0.54), 0.04, mat_lantern_flame))
    # Brass Base
    r_arm_parts.append(add_cylinder("LanternBase", (0.35, 0.12, 0.44), 0.08, 0.04, mat_brass))

    join_and_set_pivot(r_arm_parts, "RightArm", (0.35, 0, 1.24), parent=root)

    # --- LEFT LEG --- (Hip pivot at -0.16, 0, 0.75)
    l_leg_parts = []
    l_leg_parts.append(add_cube("L_Thigh", (-0.16, 0, 0.58), (0.14, 0.16, 0.32), mat_pants))
    l_leg_parts.append(add_cube("L_Shin", (-0.16, 0, 0.28), (0.13, 0.15, 0.32), mat_pants))
    l_leg_parts.append(add_cube("L_Boot", (-0.16, 0.05, 0.06), (0.12, 0.22, 0.10), mat_boots))
    join_and_set_pivot(l_leg_parts, "LeftLeg", (-0.16, 0, 0.75), parent=root)

    # --- RIGHT LEG --- (Hip pivot at +0.16, 0, 0.75)
    r_leg_parts = []
    r_leg_parts.append(add_cube("R_Thigh", (0.16, 0, 0.58), (0.14, 0.16, 0.32), mat_pants))
    r_leg_parts.append(add_cube("R_Shin", (0.16, 0, 0.28), (0.13, 0.15, 0.32), mat_pants))
    r_leg_parts.append(add_cube("R_Boot", (0.16, 0.05, 0.06), (0.12, 0.22, 0.10), mat_boots))
    join_and_set_pivot(r_leg_parts, "RightLeg", (0.16, 0, 0.75), parent=root)

    # Export GLB
    filepath = os.path.join(OUTPUT_DIR, "harriet.glb")
    bpy.ops.export_scene.gltf(filepath=filepath, export_format='GLB')
    print("Exported:", filepath)


if __name__ == "__main__":
    print("--- Building Julius Caesar ---")
    build_caesar()
    print("--- Building Joan of Arc ---")
    build_joan()
    print("--- Building Harriet Tubman ---")
    build_harriet()
    print("--- All Characters Generated Successfully! ---")
