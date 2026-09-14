## DecisionGate.gd
## High-stakes historic decision point spanning across the 3-lane track.
## Triggers bullet-time slowdown (time_scale = 0.2) on approach,
## renders glowing left (People) and right (Govt) archways with floating 3D labels,
## and applies political balance shifts when the player chooses a lane.
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
	}
]

# --- State ---
var is_slowed: bool = false
var is_resolved: bool = false
var current_scenario: Dictionary

# Node References created procedurally
var left_label: Label3D
var right_label: Label3D
var center_monument: Node3D


func _ready() -> void:
	# Randomize scenario
	current_scenario = SCENARIOS.pick_random()
	_build_gate_geometry()
	_setup_detection_areas()


## Constructs glowing 3D archways, center pylon, and floating 3D labels.
func _build_gate_geometry() -> void:
	# 1. Left Archway (Red / People) at X = -2.5
	var left_arch: Node3D = _create_arch(Color(1.0, 0.2, 0.25), "LeftArch")
	left_arch.position = Vector3(-2.5, 0.0, 0.0)
	add_child(left_arch)

	left_label = _create_floating_label(
		current_scenario["left_title"],
		current_scenario["left_details"],
		Color(1.0, 0.35, 0.35)
	)
	left_label.position = Vector3(-2.5, 3.8, 0.0)
	add_child(left_label)

	# 2. Right Archway (Blue / Govt) at X = 2.5
	var right_arch: Node3D = _create_arch(Color(0.2, 0.55, 1.0), "RightArch")
	right_arch.position = Vector3(2.5, 0.0, 0.0)
	add_child(right_arch)

	right_label = _create_floating_label(
		current_scenario["right_title"],
		current_scenario["right_details"],
		Color(0.35, 0.75, 1.0)
	)
	right_label.position = Vector3(2.5, 3.8, 0.0)
	add_child(right_label)

	# 3. Center Barrier / Monument at X = 0.0 (Forces lane choice)
	center_monument = _create_center_divider()
	center_monument.position = Vector3(0.0, 0.0, 0.0)
	add_child(center_monument)


## Builds an Area3D hierarchy for bullet-time entry, lane choices, and exit safety.
func _setup_detection_areas() -> void:
	# --- Approach Slowdown Area (Triggers Bullet Time) ---
	var approach_area: Area3D = Area3D.new()
	approach_area.name = "ApproachArea"
	var approach_col: CollisionShape3D = CollisionShape3D.new()
	var approach_box: BoxShape3D = BoxShape3D.new()
	# Spans 10m wide, 5m high, 12m long ahead of the gate (Z: +2 to +14)
	approach_box.size = Vector3(10.0, 6.0, 12.0)
	approach_col.shape = approach_box
	approach_col.position = Vector3(0.0, 2.5, 6.0)
	approach_area.add_child(approach_col)
	approach_area.body_entered.connect(_on_approach_entered)
	add_child(approach_area)

	# --- Left Gate Selection Area (X = -2.5) ---
	var left_select: Area3D = Area3D.new()
	left_select.name = "LeftSelectArea"
	var left_col: CollisionShape3D = CollisionShape3D.new()
	var left_box: BoxShape3D = BoxShape3D.new()
	left_box.size = Vector3(2.4, 5.0, 2.0)
	left_col.shape = left_box
	left_col.position = Vector3(-2.5, 2.0, 0.0)
	left_select.add_child(left_col)
	left_select.body_entered.connect(func(body): _on_lane_selected(body, "left"))
	add_child(left_select)

	# --- Right Gate Selection Area (X = 2.5) ---
	var right_select: Area3D = Area3D.new()
	right_select.name = "RightSelectArea"
	var right_col: CollisionShape3D = CollisionShape3D.new()
	var right_box: BoxShape3D = BoxShape3D.new()
	right_box.size = Vector3(2.4, 5.0, 2.0)
	right_col.shape = right_box
	right_col.position = Vector3(2.5, 2.0, 0.0)
	right_select.add_child(right_col)
	right_select.body_entered.connect(func(body): _on_lane_selected(body, "right"))
	add_child(right_select)

	# --- Exit / Cleanup Area (Guarantees time_scale reset if missed) ---
	var exit_area: Area3D = Area3D.new()
	exit_area.name = "ExitArea"
	var exit_col: CollisionShape3D = CollisionShape3D.new()
	var exit_box: BoxShape3D = BoxShape3D.new()
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
		var target_scale: float = 0.2
		# Relic Perk: Napoleon's Telescope (Slows time down by an extra 30%)
		if has_node("/root/SaveManager"):
			var sm = get_node("/root/SaveManager")
			if sm.is_relic_equipped("napoleon_telescope"):
				target_scale = 0.14

		Engine.time_scale = target_scale
		_pulse_labels()


## Resolves decision when player crosses either Left or Right gate.
func _on_lane_selected(body: Node3D, choice: String) -> void:
	if is_resolved or not body.is_in_group("player"):
		return

	is_resolved = true
	is_slowed = false
	Engine.time_scale = 1.0

	var sm = get_node_or_null("/root/SaveManager")
	var cm = get_node_or_null("/root/CharacterManager")

	if choice == "left":
		GameManager.apply_decision(
			current_scenario["left_people"],
			current_scenario["left_govt"],
			current_scenario["left_banner"]
		)
		_animate_chosen_gate(left_label)

		# Unlock Timeline Codex Card
		if sm:
			sm.unlock_card(
				"card_" + current_scenario["left_title"].to_snake_case(),
				current_scenario["left_title"],
				current_scenario["left_banner"]
			)
	else:
		GameManager.apply_decision(
			current_scenario["right_people"],
			current_scenario["right_govt"],
			current_scenario["right_banner"]
		)
		_animate_chosen_gate(right_label)

		# Unlock Timeline Codex Card
		if sm:
			sm.unlock_card(
				"card_" + current_scenario["right_title"].to_snake_case(),
				current_scenario["right_title"],
				current_scenario["right_banner"]
			)

	# Relic Perk: Tesla's Pocket Watch (Magnetizes all collectibles for 3.0s)
	if sm and sm.is_relic_equipped("tesla_watch"):
		if body.has_method("activate_tesla_magnet"):
			body.activate_tesla_magnet(3.0)

	# Track Milestone stat (e.g. Caesar gates passed)
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
	tween.tween_property(left_label, "scale", Vector3(1.15, 1.15, 1.15), 0.08)
	tween.parallel().tween_property(right_label, "scale", Vector3(1.15, 1.15, 1.15), 0.08)
	tween.tween_property(left_label, "scale", Vector3.ONE, 0.08)
	tween.parallel().tween_property(right_label, "scale", Vector3.ONE, 0.08)


## Animates the chosen gate with an upward burst / fade.
func _animate_chosen_gate(label: Label3D) -> void:
	if not label:
		return
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.5, 0.4)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4)


## Helper: Generates a glowing low-poly archway.
func _create_arch(glow_color: Color, node_name: String) -> Node3D:
	var arch: Node3D = Node3D.new()
	arch.name = node_name

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = glow_color
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 1.8
	mat.roughness = 0.2

	# Left Pillar
	var p1: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.3, 3.2, 0.4)
	box.material = mat
	p1.mesh = box
	p1.position = Vector3(-1.1, 1.6, 0.0)
	arch.add_child(p1)

	# Right Pillar
	var p2: MeshInstance3D = MeshInstance3D.new()
	p2.mesh = box
	p2.position = Vector3(1.1, 1.6, 0.0)
	arch.add_child(p2)

	# Top Crossbar Arch
	var top: MeshInstance3D = MeshInstance3D.new()
	var top_box: BoxMesh = BoxMesh.new()
	top_box.size = Vector3(2.5, 0.4, 0.5)
	top_box.material = mat
	top.mesh = top_box
	top.position = Vector3(0.0, 3.2, 0.0)
	arch.add_child(top)

	return arch


## Helper: Generates an impassable center divider pylon.
func _create_center_divider() -> Node3D:
	var divider: StaticBody3D = StaticBody3D.new()
	divider.name = "CenterDivider"
	divider.add_to_group("obstacles")

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(1.8, 3.5, 1.5)
	col.shape = box_shape
	col.position = Vector3(0.0, 1.75, 0.0)
	divider.add_child(col)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.8, 3.5, 1.5)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.26)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.8, 0.2) * 0.4
	mat.roughness = 0.5
	mesh.material = mat

	mesh_inst.mesh = mesh
	mesh_inst.position = Vector3(0.0, 1.75, 0.0)
	divider.add_child(mesh_inst)

	# Floating icon or emblem on center pylon
	var emblem_label: Label3D = Label3D.new()
	emblem_label.text = "CHOOSE\nPATH"
	emblem_label.font_size = 28
	emblem_label.outline_size = 6
	emblem_label.modulate = Color(1.0, 0.85, 0.2)
	emblem_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	emblem_label.position = Vector3(0.0, 2.2, 0.8)
	divider.add_child(emblem_label)

	return divider


## Helper: Creates a crisp, billboarded floating 3D text label.
func _create_floating_label(title: String, details: String, font_color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = "%s\n%s" % [title, details]
	label.font_size = 32
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	label.modulate = font_color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	return label
