## DecisionGate.gd
## High-stakes historic decision point spanning across the 3-lane track.
## Triggers bullet-time slowdown (time_scale = 0.22) on approach,
## renders a grand Roman Triumphal Archway with left (People) and right (Govt) portals,
## and offers a center Golden Transcendence Lane unlocked exclusively via Ruler Special Abilities!
extends Node3D
class_name DecisionGate

# --- Scenario Presets for Dynamic Historic Flavor ---
const SCENARIOS = [
	{
		"left_title": "BRIBE THE MOB",
		"left_details": "+20 People  |  -10 Govt",
		"left_people": 20.0,
		"left_govt": -10.0,
		"left_banner": "History Shifted: Caesar allied with the Plebs!",
		"right_title": "DEPLOY LEGIONS",
		"right_details": "+20 Govt  |  -10 People",
		"right_people": -10.0,
		"right_govt": 20.0,
		"right_banner": "History Shifted: The Senate crushed the uprising!"
	},
	{
		"left_title": "OPEN THE GRANARIES",
		"left_details": "+25 People  |  -15 Govt",
		"left_people": 25.0,
		"left_govt": -15.0,
		"left_banner": "History Shifted: Grain distributed freely to the masses!",
		"right_title": "COLLECT IMPERIAL TAX",
		"right_details": "+20 Govt  |  -15 People",
		"right_people": -15.0,
		"right_govt": 20.0,
		"right_banner": "History Shifted: Royal treasury replenished by imperial decree!"
	},
	{
		"left_title": "GRANT AMNESTY",
		"left_details": "+20 People  |  -10 Govt",
		"left_people": 20.0,
		"left_govt": -10.0,
		"left_banner": "History Shifted: Rebel leaders pardoned to soothe unrest!",
		"right_title": "DECLARE MARTIAL LAW",
		"right_details": "+25 Govt  |  -20 People",
		"right_people": -20.0,
		"right_govt": 25.0,
		"right_banner": "History Shifted: Curfew enforced by elite palace guards!"
	},
	{
		"left_title": "EMANCIPATION CHARTER",
		"left_details": "+25 People  |  -15 Govt",
		"left_people": 25.0,
		"left_govt": -15.0,
		"left_banner": "History Shifted: Liberty granted to all laborers!",
		"right_title": "EXPEDITION WAR BONDS",
		"right_details": "+25 Govt  |  -15 People",
		"right_people": -15.0,
		"right_govt": 25.0,
		"right_banner": "History Shifted: Frontiers expanded under iron discipline!"
	}
]

# --- State ---
var is_slowed: bool = false
var is_resolved: bool = false
var is_center_transcendent: bool = false
var current_scenario: Dictionary

# Node References
var left_label: Label3D
var right_label: Label3D
var center_label: Label3D
var center_divider_body: StaticBody3D
var center_col_shape: CollisionShape3D
var center_mesh_inst: MeshInstance3D
var center_curtain: MeshInstance3D
var center_select_area: Area3D
var arch_structure: Node3D
var portal_curtain_left: MeshInstance3D
var portal_curtain_right: MeshInstance3D


func _ready() -> void:
	current_scenario = SCENARIOS.pick_random()
	_build_gate_geometry()
	_setup_detection_areas()


func _process(delta: float) -> void:
	if is_resolved:
		return

	# Dynamic Transcendence Check: If player activates ability during approach, open center gate!
	var cm = get_node_or_null("/root/CharacterManager")
	if cm and cm.is_ability_active:
		if not is_center_transcendent:
			_enable_center_transcendence()
	elif is_center_transcendent:
		_disable_center_transcendence()

	# Subtle portal shimmer animation
	if portal_curtain_left and portal_curtain_right:
		var time: float = Time.get_ticks_msec() * 0.003
		portal_curtain_left.rotation.y = sin(time) * 0.05
		portal_curtain_right.rotation.y = -sin(time) * 0.05


## Constructs a grand Roman Triumphal Arch spanning the 3-lane boulevard.
func _build_gate_geometry() -> void:
	arch_structure = Node3D.new()
	arch_structure.name = "TriumphalArch"
	add_child(arch_structure)

	# --- Classical Roman Columns (X = -3.75, -1.25, +1.25, +3.75) ---
	var column_x_positions: Array[float] = [-3.75, -1.25, 1.25, 3.75]
	for x in column_x_positions:
		_build_roman_column(x)

	# --- Overhead Entablature & Frieze Across the 3 Lanes ---
	_build_entablature()

	# --- Left Portal: The People's Will (Crimson-Gold Energy Vortex) ---
	var left_portal = _build_portal_curtain(Color(1.0, 0.22, 0.25), Color(1.0, 0.6, 0.1), "LeftCurtain")
	left_portal.position = Vector3(-2.5, 1.8, 0.0)
	portal_curtain_left = left_portal
	arch_structure.add_child(left_portal)

	left_label = _create_floating_label(
		current_scenario["left_title"],
		current_scenario["left_details"] + "\n[+35% ABILITY CHARGE]",
		Color(1.0, 0.35, 0.35),
		Color(1.0, 0.85, 0.4)
	)
	left_label.position = Vector3(-2.5, 4.3, 0.0)
	arch_structure.add_child(left_label)

	# Left Emblem (Heart / People)
	var left_emblem = _create_medallion("❤️", Color(1.0, 0.3, 0.4))
	left_emblem.position = Vector3(-2.5, 3.2, 0.2)
	arch_structure.add_child(left_emblem)

	# --- Right Portal: The Imperial State (Sapphire-Cyan Energy Vortex) ---
	var right_portal = _build_portal_curtain(Color(0.2, 0.6, 1.0), Color(0.1, 0.9, 1.0), "RightCurtain")
	right_portal.position = Vector3(2.5, 1.8, 0.0)
	portal_curtain_right = right_portal
	arch_structure.add_child(right_portal)

	right_label = _create_floating_label(
		current_scenario["right_title"],
		current_scenario["right_details"] + "\n[+35% ABILITY CHARGE]",
		Color(0.35, 0.8, 1.0),
		Color(0.6, 0.95, 1.0)
	)
	right_label.position = Vector3(2.5, 4.3, 0.0)
	arch_structure.add_child(right_label)

	# Right Emblem (Temple / Crown)
	var right_emblem = _create_medallion("🏛️", Color(0.4, 0.85, 1.0))
	right_emblem.position = Vector3(2.5, 3.2, 0.2)
	arch_structure.add_child(right_emblem)

	# --- Center Lane: Chrono-Obelisk Barrier / Golden Transcendence Portal ---
	_build_center_lane_divider()


## Builds a marble column with base, fluted shaft, and golden Corinthian capital.
func _build_roman_column(x_pos: float) -> void:
	var col_root = Node3D.new()
	col_root.position = Vector3(x_pos, 0.0, 0.0)
	arch_structure.add_child(col_root)

	var marble_mat = StandardMaterial3D.new()
	marble_mat.albedo_color = Color(0.90, 0.87, 0.82)
	marble_mat.roughness = 0.35

	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.95, 0.78, 0.25)
	gold_mat.metallic = 0.85
	gold_mat.roughness = 0.25
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(0.85, 0.65, 0.15)
	gold_mat.emission_energy_multiplier = 0.6

	# 1. Base pedestal
	var base_mesh = MeshInstance3D.new()
	var base_box = BoxMesh.new()
	base_box.size = Vector3(0.65, 0.5, 0.65)
	base_mesh.mesh = base_box
	base_mesh.material_override = marble_mat
	base_mesh.position = Vector3(0.0, 0.25, 0.0)
	col_root.add_child(base_mesh)

	# 2. Main column shaft
	var shaft_mesh = MeshInstance3D.new()
	var shaft_cyl = CylinderMesh.new()
	shaft_cyl.top_radius = 0.22
	shaft_cyl.bottom_radius = 0.24
	shaft_cyl.height = 3.6
	shaft_cyl.radial_segments = 16
	shaft_mesh.mesh = shaft_cyl
	shaft_mesh.material_override = marble_mat
	shaft_mesh.position = Vector3(0.0, 2.1, 0.0)
	col_root.add_child(shaft_mesh)

	# 3. Gold capital
	var cap_mesh = MeshInstance3D.new()
	var cap_box = BoxMesh.new()
	cap_box.size = Vector3(0.6, 0.35, 0.6)
	cap_mesh.mesh = cap_box
	cap_mesh.material_override = gold_mat
	cap_mesh.position = Vector3(0.0, 3.8, 0.0)
	col_root.add_child(cap_mesh)


## Builds the upper entablature and glowing frieze spanning across the boulevard.
func _build_entablature() -> void:
	var entablature = MeshInstance3D.new()
	var ent_box = BoxMesh.new()
	ent_box.size = Vector3(8.5, 0.7, 0.8)
	entablature.mesh = ent_box

	var ent_mat = StandardMaterial3D.new()
	ent_mat.albedo_color = Color(0.85, 0.82, 0.77)
	ent_mat.roughness = 0.4
	entablature.material_override = ent_mat
	entablature.position = Vector3(0.0, 4.3, 0.0)
	arch_structure.add_child(entablature)

	# Glowing Architrave Text Banner
	var frieze_label = Label3D.new()
	frieze_label.text = "✦ HISTORIC CROSSROADS IN TIME ✦"
	frieze_label.font_size = 28
	frieze_label.outline_size = 6
	frieze_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	frieze_label.modulate = Color(1.0, 0.88, 0.35)
	frieze_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	frieze_label.position = Vector3(0.0, 4.3, 0.45)
	arch_structure.add_child(frieze_label)


## Creates a translucent shimmering energy portal curtain.
func _build_portal_curtain(primary_color: Color, emit_color: Color, curtain_name: String) -> MeshInstance3D:
	var curtain = MeshInstance3D.new()
	curtain.name = curtain_name
	var quad = QuadMesh.new()
	quad.size = Vector2(2.2, 3.5)
	curtain.mesh = quad

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(primary_color.r, primary_color.g, primary_color.b, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = emit_color
	mat.emission_energy_multiplier = 1.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	curtain.material_override = mat
	return curtain


## Center lane obstacle divider that transforms into the Golden Transcendence Portal.
func _build_center_lane_divider() -> void:
	center_divider_body = StaticBody3D.new()
	center_divider_body.name = "CenterDivider"
	center_divider_body.add_to_group("obstacles")
	add_child(center_divider_body)

	center_col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.8, 3.5, 1.2)
	center_col_shape.shape = box_shape
	center_col_shape.position = Vector3(0.0, 1.75, 0.0)
	center_divider_body.add_child(center_col_shape)

	# Chrono-Obelisk Visual
	center_mesh_inst = MeshInstance3D.new()
	var obelisk = BoxMesh.new()
	obelisk.size = Vector3(1.6, 3.5, 1.0)
	center_mesh_inst.mesh = obelisk

	var obelisk_mat = StandardMaterial3D.new()
	obelisk_mat.albedo_color = Color(0.24, 0.22, 0.20)
	obelisk_mat.roughness = 0.4
	obelisk_mat.emission_enabled = true
	obelisk_mat.emission = Color(0.9, 0.75, 0.2)
	obelisk_mat.emission_energy_multiplier = 0.5
	center_mesh_inst.material_override = obelisk_mat
	center_mesh_inst.position = Vector3(0.0, 1.75, 0.0)
	center_divider_body.add_child(center_mesh_inst)

	# Golden Curtain (hidden until ability is activated)
	center_curtain = _build_portal_curtain(Color(1.0, 0.85, 0.2), Color(1.0, 0.95, 0.5), "CenterCurtain")
	center_curtain.position = Vector3(0.0, 1.8, 0.0)
	center_curtain.visible = false
	arch_structure.add_child(center_curtain)

	# Center Label
	center_label = Label3D.new()
	center_label.text = "⚡ RULER'S MANDATE ⚡\n[ACTIVATE ABILITY TO TRANSCEND]"
	center_label.font_size = 24
	center_label.outline_size = 6
	center_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	center_label.modulate = Color(1.0, 0.85, 0.3)
	center_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	center_label.position = Vector3(0.0, 2.2, 0.7)
	arch_structure.add_child(center_label)


## Unlocks the center lane into a Golden Transcendence Portal when ruler ability is active!
func _enable_center_transcendence() -> void:
	is_center_transcendent = true
	if center_col_shape:
		center_col_shape.set_deferred("disabled", true)
	if center_mesh_inst:
		center_mesh_inst.visible = false
	if center_curtain:
		center_curtain.visible = true
	if center_label:
		center_label.text = "✦ GOLDEN TRANSCENDENCE ✦\n+25 People  |  +25 Govt\n(Ruler Mandate Active!)"
		center_label.modulate = Color(1.0, 0.95, 0.4)
		center_label.font_size = 28


## Relocks the center lane if ability expires while approaching.
func _disable_center_transcendence() -> void:
	is_center_transcendent = false
	if center_col_shape:
		center_col_shape.set_deferred("disabled", false)
	if center_mesh_inst:
		center_mesh_inst.visible = true
	if center_curtain:
		center_curtain.visible = false
	if center_label:
		center_label.text = "⚡ RULER'S MANDATE ⚡\n[ACTIVATE ABILITY TO TRANSCEND]"
		center_label.modulate = Color(1.0, 0.85, 0.3)
		center_label.font_size = 24


## Builds detection triggers for approach slowdown, lane choices, and clean exit.
func _setup_detection_areas() -> void:
	# --- Approach Slowdown Area (Triggers Bullet Time) ---
	var approach_area = Area3D.new()
	approach_area.name = "ApproachArea"
	var approach_col = CollisionShape3D.new()
	var approach_box = BoxShape3D.new()
	approach_box.size = Vector3(10.0, 6.0, 14.0)
	approach_col.shape = approach_box
	approach_col.position = Vector3(0.0, 2.5, 7.0)
	approach_area.add_child(approach_col)
	approach_area.body_entered.connect(_on_approach_entered)
	add_child(approach_area)

	# --- Left Gate Selection Area (X = -2.5) ---
	var left_select = Area3D.new()
	left_select.name = "LeftSelectArea"
	var left_col = CollisionShape3D.new()
	var left_box = BoxShape3D.new()
	left_box.size = Vector3(2.4, 5.0, 2.0)
	left_col.shape = left_box
	left_col.position = Vector3(-2.5, 2.0, 0.0)
	left_select.add_child(left_col)
	left_select.body_entered.connect(func(body): _on_lane_selected(body, "left"))
	add_child(left_select)

	# --- Right Gate Selection Area (X = 2.5) ---
	var right_select = Area3D.new()
	right_select.name = "RightSelectArea"
	var right_col = CollisionShape3D.new()
	var right_box = BoxShape3D.new()
	right_box.size = Vector3(2.4, 5.0, 2.0)
	right_col.shape = right_box
	right_col.position = Vector3(2.5, 2.0, 0.0)
	right_select.add_child(right_col)
	right_select.body_entered.connect(func(body): _on_lane_selected(body, "right"))
	add_child(right_select)

	# --- Center Gate Selection Area (X = 0.0) ---
	center_select_area = Area3D.new()
	center_select_area.name = "CenterSelectArea"
	var center_col = CollisionShape3D.new()
	var center_box = BoxShape3D.new()
	center_box.size = Vector3(2.0, 5.0, 2.0)
	center_col.shape = center_box
	center_col.position = Vector3(0.0, 2.0, 0.0)
	center_select_area.add_child(center_col)
	center_select_area.body_entered.connect(func(body): _on_lane_selected(body, "center"))
	add_child(center_select_area)

	# --- Exit / Cleanup Area (Guarantees time_scale reset) ---
	var exit_area = Area3D.new()
	exit_area.name = "ExitArea"
	var exit_col = CollisionShape3D.new()
	var exit_box = BoxShape3D.new()
	exit_box.size = Vector3(10.0, 6.0, 4.0)
	exit_col.shape = exit_box
	exit_col.position = Vector3(0.0, 2.5, -4.0)
	exit_area.add_child(exit_col)
	exit_area.body_entered.connect(_on_exit_entered)
	add_child(exit_area)


## Enters Bullet Time when player approaches the decision horizon.
func _on_approach_entered(body: Node3D) -> void:
	if is_resolved or not body.is_in_group("player"):
		return

	if not is_slowed:
		is_slowed = true
		var target_scale: float = 0.22
		# Relic Perk: Napoleon's Telescope
		var sm = get_node_or_null("/root/SaveManager")
		if sm and sm.is_relic_equipped("napoleon_telescope"):
			target_scale = 0.14

		Engine.time_scale = target_scale
		_pulse_labels()


## Resolves decision when player crosses Left, Right, or Center Transcendence portal.
func _on_lane_selected(body: Node3D, choice: String) -> void:
	if is_resolved or not body.is_in_group("player"):
		return

	# Center choice requires active transcendence
	if choice == "center" and not is_center_transcendent:
		return

	is_resolved = true
	is_slowed = false
	Engine.time_scale = 1.0

	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx_gate"):
		am.play_sfx_gate()

	var sm = get_node_or_null("/root/SaveManager")
	var cm = get_node_or_null("/root/CharacterManager")

	if choice == "left":
		GameManager.apply_decision(
			current_scenario["left_people"],
			current_scenario["left_govt"],
			current_scenario["left_banner"]
		)
		_animate_chosen_gate(left_label)
		if cm and cm.has_method("charge_ability"):
			cm.charge_ability(0.35)
		if sm:
			sm.unlock_card(
				"card_" + current_scenario["left_title"].to_snake_case(),
				current_scenario["left_title"],
				current_scenario["left_banner"]
			)

	elif choice == "right":
		GameManager.apply_decision(
			current_scenario["right_people"],
			current_scenario["right_govt"],
			current_scenario["right_banner"]
		)
		_animate_chosen_gate(right_label)
		if cm and cm.has_method("charge_ability"):
			cm.charge_ability(0.35)
		if sm:
			sm.unlock_card(
				"card_" + current_scenario["right_title"].to_snake_case(),
				current_scenario["right_title"],
				current_scenario["right_banner"]
			)

	elif choice == "center":
		# Golden Transcendence Bonus: +25 to BOTH factions, zero penalty!
		GameManager.apply_decision(
			25.0,
			25.0,
			"✦ TRANSCENDENCE: RULER UNITED CROWN & COMMONER! ✦"
		)
		_animate_chosen_gate(center_label)
		if am and am.has_method("play_sfx_ability"):
			am.play_sfx_ability()
		if sm:
			sm.unlock_card(
				"card_golden_transcendence",
				"The Golden Mandate",
				"History Transcended: United both Crown and Commoner!"
			)

	# Relic Perk: Tesla's Pocket Watch (Magnetizes all collectibles for 3.0s)
	if sm and sm.is_relic_equipped("tesla_watch"):
		if body.has_method("activate_tesla_magnet"):
			body.activate_tesla_magnet(3.0)

	# Track Milestone stat
	if sm and cm and cm.get("active_character"):
		if cm.get("active_character").get("character_name") == "Julius Caesar":
			sm.add_stat("caesar_gates_passed", 1)


## Safety callback if player passes gate without clean trigger.
func _on_exit_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if is_slowed:
		is_slowed = false
		Engine.time_scale = 1.0


## Pulses labels gently while in bullet time.
func _pulse_labels() -> void:
	if not left_label or not right_label:
		return
	var tween: Tween = create_tween().set_loops(4)
	tween.tween_property(left_label, "scale", Vector3(1.12, 1.12, 1.12), 0.08)
	tween.parallel().tween_property(right_label, "scale", Vector3(1.12, 1.12, 1.12), 0.08)
	if center_label and is_center_transcendent:
		tween.parallel().tween_property(center_label, "scale", Vector3(1.15, 1.15, 1.15), 0.08)
	tween.tween_property(left_label, "scale", Vector3.ONE, 0.08)
	tween.parallel().tween_property(right_label, "scale", Vector3.ONE, 0.08)
	if center_label and is_center_transcendent:
		tween.parallel().tween_property(center_label, "scale", Vector3.ONE, 0.08)


## Animates the chosen gate with an upward burst / fade.
func _animate_chosen_gate(label: Label3D) -> void:
	if not label:
		return
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.5, 0.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4)


## Helper: Creates a floating 3D medallion with emoji/symbol.
func _create_medallion(symbol: String, col: Color) -> Label3D:
	var label = Label3D.new()
	label.text = symbol
	label.font_size = 48
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.modulate = col
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label


## Helper: Creates a crisp, billboarded floating 3D text label.
func _create_floating_label(title: String, details: String, title_col: Color, detail_col: Color) -> Label3D:
	var label = Label3D.new()
	label.text = "%s\n%s" % [title, details]
	label.font_size = 30
	label.outline_size = 7
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.modulate = title_col
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	return label
