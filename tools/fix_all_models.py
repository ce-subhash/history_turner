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

def add_bevel(obj, width=0.02, segments=2):
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

def add_sphere(name, loc, radius, mat=None, rot=(0,0,0), segs=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=radius, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    smooth_object(obj)
    if mat:
        apply_mat(obj, mat)
    return obj

def export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False, export_apply=True)
    print(f"Exported clean prop: {path}")

# =========================================================================
# 1. CROWD SIDEWALK (Runs PARALLEL to road along Y axis! Never across X!)
# =========================================================================
def build_crowd_sidewalk():
    clear_scene()

    mat_stone = create_mat("StoneWall", (0.85, 0.82, 0.76, 1.0), roughness=0.6)
    mat_sign_wood = create_mat("SignPole", (0.48, 0.30, 0.18, 1.0), roughness=0.8)
    mat_sign_board = create_mat("SignBoard", (0.96, 0.94, 0.90, 1.0), roughness=0.4)
    mat_sign_text_red = create_mat("SignTextRed", (0.88, 0.10, 0.14, 1.0), roughness=0.3)
    mat_sign_text_black = create_mat("SignTextBlack", (0.10, 0.10, 0.10, 1.0), roughness=0.3)
    mat_flag_saffron = create_mat("FlagSaffron", (1.0, 0.50, 0.10, 1.0), roughness=0.5)
    mat_flag_green = create_mat("FlagGreen", (0.10, 0.65, 0.20, 1.0), roughness=0.5)
    mat_skin = create_mat("CrowdSkin", (0.82, 0.62, 0.48, 1.0), roughness=0.6)

    # NO WALL OR BARRIER: The crowd stands freely and clearly on the sidewalk.
    # Spectators with torsos, heads, legs, cheering hands, signs, and flags.
    mat_pants = create_mat("CrowdPants", (0.20, 0.22, 0.25, 1.0), roughness=0.7)

    crowd_colors = [
        (0.85, 0.25, 0.20, 1.0),
        (0.20, 0.45, 0.85, 1.0),
        (0.95, 0.85, 0.15, 1.0),
        (0.25, 0.75, 0.35, 1.0),
        (0.95, 0.95, 0.95, 1.0),
        (0.80, 0.40, 0.70, 1.0),
    ]

    # Cheering spectators standing along sidewalk (at x = 0.0)
    for i, cy in enumerate([-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]):
        m_shirt = create_mat(f"Shirt_{i}", crowd_colors[i % len(crowd_colors)], roughness=0.5)
        # Legs
        add_cube(f"CrowdLegs_{i}", (0.0, cy, 0.42), (0.14, 0.18, 0.42), mat_pants)
        # Body
        add_cube(f"CrowdTorso_{i}", (0.0, cy, 1.15), (0.16, 0.20, 0.32), m_shirt, bevel=0.03)
        # Head
        add_sphere(f"CrowdHead_{i}", (0.0, cy, 1.62), 0.15, mat_skin)
        # Cheering raised hands
        add_cylinder(f"HandL_{i}", (0.0, cy - 0.22, 1.70), radius=0.04, depth=0.42, mat=m_shirt, rot=(math.radians(-30), 0, 0))
        add_cylinder(f"HandR_{i}", (0.0, cy + 0.22, 1.70), radius=0.04, depth=0.42, mat=m_shirt, rot=(math.radians(30), 0, 0))

    # Campaign signs facing road (facing -X)
    signs = [
        (-4.0, 2.0, "Sign_Jobs", mat_sign_text_black),
        (0.0, 2.1, "Sign_Leadership", mat_sign_text_red),
        (4.0, 1.9, "Sign_Support", mat_sign_text_black),
    ]
    for sy, sz, sname, stext_mat in signs:
        add_cylinder(f"{sname}_Pole", (0.15, sy, sz - 0.6), radius=0.03, depth=1.6, mat=mat_sign_wood)
        add_cube(f"{sname}_Board", (0.15, sy, sz), (0.02, 0.55, 0.32), mat_sign_board, bevel=0.02)
        add_cube(f"{sname}_Text", (0.12, sy, sz), (0.01, 0.45, 0.18), stext_mat)

    # Flags
    for fy, fz in [(-2.0, 2.2), (2.0, 2.2)]:
        add_cylinder(f"FlagPole_{fy}", (0.15, fy, fz - 0.6), radius=0.025, depth=1.7, mat=mat_sign_wood)
        add_cube(f"FlagSaffron_{fy}", (0.14, fy + 0.20, fz + 0.10), (0.01, 0.25, 0.08), mat_flag_saffron)
        add_cube(f"FlagWhite_{fy}", (0.14, fy + 0.20, fz), (0.01, 0.25, 0.08), mat_sign_board)
        add_cube(f"FlagGreen_{fy}", (0.14, fy + 0.20, fz - 0.10), (0.01, 0.25, 0.08), mat_flag_green)

# =========================================================================
# 2. POLICE RIOT BARRICADE (Width 2.1m strictly inside lane)
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

    # Width 2.1m (scale x=1.05)
    add_cube("TopBar", (0, 0, 1.15), (1.05, 0.04, 0.04), mat_blue_steel)
    add_cube("BotBar", (0, 0, 0.15), (1.05, 0.04, 0.04), mat_blue_steel)
    add_cube("LeftPost", (-1.02, 0, 0.65), (0.04, 0.04, 0.50), mat_blue_steel)
    add_cube("RightPost", (1.02, 0, 0.65), (0.04, 0.04, 0.50), mat_blue_steel)
    for fx in [-0.95, 0.95]:
        add_cube(f"Foot_{fx}", (fx, 0, 0.06), (0.04, 0.35, 0.03), mat_blue_steel)

    # Front POLICE Plate (width 1.5m)
    add_cube("PolicePlate", (0, -0.06, 0.65), (0.75, 0.02, 0.22), mat_blue_steel, bevel=0.02)
    add_cube("PoliceWhitePlate", (0, -0.08, 0.65), (0.65, 0.01, 0.14), mat_sign)
    add_cube("PoliceTextBar", (0, -0.09, 0.65), (0.50, 0.01, 0.08), mat_sign_text)

    # 3 Riot Police Officers behind barricade
    for cx in [-0.60, 0.0, 0.60]:
        add_cube(f"CopTorso_{cx}", (cx, 0.25, 1.05), (0.22, 0.15, 0.25), mat_cop_suit, bevel=0.03)
        add_cube(f"CopVest_{cx}", (cx, 0.22, 1.08), (0.23, 0.14, 0.19), mat_helmet, bevel=0.02)
        add_sphere(f"CopHead_{cx}", (cx, 0.25, 1.48), 0.16, mat_cop_suit)
        add_sphere(f"CopHelmet_{cx}", (cx, 0.25, 1.52), 0.18, mat_helmet)
        add_cube(f"CopVisor_{cx}", (cx, 0.11, 1.48), (0.14, 0.04, 0.06), mat_visor, bevel=0.02)
        add_cube(f"Shield_{cx}", (cx, 0.05, 0.95), (0.24, 0.02, 0.45), mat_shield, bevel=0.02)

# =========================================================================
# 3. WOODEN ROADBLOCK (Width 2.0m strictly inside lane)
# =========================================================================
def build_wooden_roadblock():
    clear_scene()

    mat_timber = create_mat("TimberWood", (0.55, 0.36, 0.20, 1.0), roughness=0.8)
    mat_cross = create_mat("CrossWood", (0.42, 0.26, 0.14, 1.0), roughness=0.9)
    mat_sign = create_mat("NoEntrySign", (0.92, 0.90, 0.85, 1.0), roughness=0.4)
    mat_sign_text = create_mat("SignRedText", (0.85, 0.12, 0.15, 1.0), roughness=0.4)
    mat_bolt = create_mat("IronBolt", (0.2, 0.2, 0.2, 1.0), metallic=0.8, roughness=0.3)

    for px in [-0.95, 0.95]:
        add_cube(f"LegF_{px}", (px, 0.22, 0.65), (0.06, 0.05, 0.65), mat_timber, rot=(math.radians(20), 0, 0))
        add_cube(f"LegB_{px}", (px, -0.22, 0.65), (0.06, 0.05, 0.65), mat_timber, rot=(math.radians(-20), 0, 0))
        add_cube(f"Tie_{px}", (px, 0, 0.35), (0.07, 0.22, 0.04), mat_cross)

    # Horizontal planks (width 2.0m)
    add_cube("PlankTop", (0, 0, 1.05), (1.00, 0.04, 0.10), mat_timber, bevel=0.02)
    add_cube("PlankMid", (0, 0, 0.70), (1.00, 0.04, 0.10), mat_timber, bevel=0.02)
    add_cube("PlankBot", (0, 0, 0.35), (1.00, 0.04, 0.08), mat_timber, bevel=0.02)

    add_cube("DiagL", (0, -0.05, 0.70), (0.05, 0.03, 0.58), mat_cross, rot=(0, math.radians(48), 0))
    add_cube("DiagR", (0, -0.05, 0.70), (0.05, 0.03, 0.58), mat_cross, rot=(0, math.radians(-48), 0))

    # NO ENTRY sign plaque
    add_cube("SignBoard", (0, -0.10, 0.72), (0.55, 0.02, 0.16), mat_sign, bevel=0.02)
    add_cube("SignText", (0, -0.12, 0.72), (0.45, 0.01, 0.09), mat_sign_text)

# =========================================================================
# 4. JUMP RAMP (Width 1.9m strictly inside lane)
# =========================================================================
def build_jump_ramp():
    clear_scene()

    mat_steel = create_mat("RampSteel", (0.10, 0.32, 0.65, 1.0), metallic=0.5, roughness=0.3)
    mat_trim = create_mat("RampTrim", (0.18, 0.18, 0.20, 1.0), metallic=0.7, roughness=0.3)
    mat_arrow = create_mat("RampArrow", (0.96, 0.96, 0.96, 1.0), roughness=0.2, emit_color=(1,1,1,1), emit_val=0.4)

    ramp_angle = math.radians(20)
    add_cube("RampSurface", (0, 0, 0.42), (0.92, 1.25, 0.05), mat_steel, rot=(ramp_angle, 0, 0), bevel=0.02)

    for sx in [-0.95, 0.95]:
        add_cube(f"RampSide_{sx}", (sx, 0, 0.42), (0.04, 1.25, 0.22), mat_trim)

    for i, ay in enumerate([-0.5, 0.1, 0.7]):
        az = 0.42 - ay * math.sin(ramp_angle)
        add_cube(f"ChevL_{i}", (-0.15, ay, az + 0.06), (0.06, 0.20, 0.01), mat_arrow, rot=(ramp_angle, math.radians(35), 0))
        add_cube(f"ChevR_{i}", (0.15, ay, az + 0.06), (0.06, 0.20, 0.01), mat_arrow, rot=(ramp_angle, math.radians(-35), 0))

# =========================================================================
# 5. MOVING BULL CART (Width 1.9m strictly inside lane)
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

    for wx in [-0.90, 0.90]:
        add_cylinder(f"WheelRim_{wx}", (wx, 0, 0.70), radius=0.65, depth=0.08, mat=mat_iron, rot=(0, math.radians(90), 0))
        add_cylinder(f"WheelWood_{wx}", (wx, 0, 0.70), radius=0.61, depth=0.07, mat=mat_wood, rot=(0, math.radians(90), 0))
        add_cylinder(f"WheelHub_{wx}", (wx, 0, 0.70), radius=0.15, depth=0.14, mat=mat_dark_wood, rot=(0, math.radians(90), 0))
        for s in range(8):
            ang = s * (math.pi / 4)
            add_cylinder(f"Spoke_{wx}_{s}", (wx, 0.30 * math.cos(ang), 0.70 + 0.30 * math.sin(ang)), radius=0.025, depth=0.58, mat=mat_wood, rot=(ang, 0, 0))

    add_cylinder("Axle", (0, 0, 0.70), radius=0.06, depth=1.85, mat=mat_iron, rot=(0, math.radians(90), 0))
    add_cube("BedPlatform", (0, 0, 0.80), (0.78, 1.2, 0.06), mat_wood, bevel=0.03)

    for sx in [-0.76, 0.76]:
        add_cube(f"SideRail_Top_{sx}", (sx, 0, 1.25), (0.04, 1.2, 0.04), mat_dark_wood)
        for sy in [-1.0, -0.5, 0.0, 0.5, 1.0]:
            add_cube(f"SideSlat_{sx}_{sy}", (sx, sy, 1.05), (0.03, 0.04, 0.20), mat_wood)

    add_cube("HayBale1", (-0.32, -0.4, 1.05), (0.32, 0.45, 0.25), mat_hay, bevel=0.05)
    add_cube("HayBale2", (-0.28, -0.3, 1.35), (0.28, 0.40, 0.20), mat_hay, rot=(0,0,math.radians(10)), bevel=0.05)

    add_sphere("GrainSack1", (0.32, -0.3, 1.0), 0.24, mat_sack)
    add_sphere("GrainSack2", (0.28, 0.25, 1.0), 0.22, mat_sack)

    pot_body = add_sphere("ClayPot", (0.0, 0.5, 0.98), 0.18, mat_clay)
    pot_body.scale = (1.0, 1.0, 1.2)
    add_cylinder("PotNeck", (0.0, 0.5, 1.15), radius=0.08, depth=0.06, mat=mat_clay)

    add_cylinder("DraftBeamL", (-0.35, 1.6, 0.70), radius=0.05, depth=1.4, mat=mat_wood, rot=(math.radians(85), 0, 0))
    add_cylinder("DraftBeamR", (0.35, 1.6, 0.70), radius=0.05, depth=1.4, mat=mat_wood, rot=(math.radians(85), 0, 0))
    add_cylinder("YokeCrossbar", (0, 2.3, 0.82), radius=0.06, depth=1.4, mat=mat_dark_wood, rot=(0, math.radians(90), 0))

    ox_body = add_sphere("OxBody", (0, 2.9, 0.85), 0.38, mat_ox_skin)
    ox_body.scale = (0.65, 1.1, 0.75)
    add_sphere("OxHump", (0, 2.7, 1.18), 0.20, mat_ox_skin)
    add_cylinder("OxNeck", (0, 3.4, 1.02), radius=0.18, depth=0.38, mat=mat_ox_skin, rot=(math.radians(35), 0, 0))
    ox_head = add_sphere("OxHead", (0, 3.6, 1.16), 0.22, mat_ox_skin)
    ox_head.scale = (0.75, 1.0, 0.80)
    for hx in [-0.18, 0.18]:
        add_cylinder(f"Horn_{hx}", (hx, 3.6, 1.36), radius=0.035, depth=0.28, mat=mat_horn, rot=(math.radians(-25), math.radians(30 if hx>0 else -30), 0))
    for lx, ly in [(-0.20, 2.5), (0.20, 2.5), (-0.20, 3.2), (0.20, 3.2)]:
        add_cylinder(f"OxLeg_{lx}_{ly}", (lx, ly, 0.40), radius=0.065, depth=0.75, mat=mat_ox_skin)
        add_cylinder(f"OxHoof_{lx}_{ly}", (lx, ly, 0.05), radius=0.075, depth=0.10, mat=mat_horn)

def run():
    props_dir = "/Users/subhash/Games/assets/sprites/props"
    build_crowd_sidewalk()
    export_glb(f"{props_dir}/crowd_sidewalk.glb")

    build_police_barricade()
    export_glb(f"{props_dir}/police_barricade.glb")

    build_wooden_roadblock()
    export_glb(f"{props_dir}/wooden_roadblock.glb")

    build_jump_ramp()
    export_glb(f"{props_dir}/jump_ramp.glb")

    build_bull_cart()
    export_glb(f"{props_dir}/bull_cart.glb")
    print("\n>>> ALL MODELS PERFECTLY RESCALED & ALIGNED ALONG SIDEWALK! <<<")

run()
