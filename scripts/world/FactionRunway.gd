## FactionRunway.gd
## High-Speed Faction Boost Runways.
## Replaces bulky physical archway gates with sleek, luminous floor boost carpets:
## - Left Lane (-2.5m): Luminous Crimson "People's Rally" Runway (+25% People, -10% Govt)
## - Right Lane (+2.5m): Luminous Sapphire "Imperial Decree" Runway (+25% Govt, -10% People)
## - Center Lane (0.0m): Open for unobstructed running or balanced golden tokens
## Completely flat, transparent, and non-obstructive — preserves 100% forward vision and continuous runner momentum!
extends Node3D
class_name FactionRunway

var has_triggered: bool = false
var time_accum: float = 0.0
var left_mat: StandardMaterial3D
var right_mat: StandardMaterial3D


func _init() -> void:
	name = "FactionRunway"
	_build_runways()


func _ready() -> void:
	pass


func _build_runways() -> void:
	# 1. Left Lane: People's Rally Runway (X = -2.5)
	var left_runway = _create_runway_strip(
		Vector3(-2.5, 0.02, 0.0),
		Color(1.0, 0.20, 0.20, 0.65),
		Color(1.0, 0.15, 0.15),
		"PeopleTrigger"
	)
	add_child(left_runway)

	# 2. Right Lane: Imperial Decree Runway (X = +2.5)
	var right_runway = _create_runway_strip(
		Vector3(2.5, 0.02, 0.0),
		Color(0.20, 0.60, 1.0, 0.65),
		Color(0.15, 0.50, 1.0),
		"GovtTrigger"
	)
	add_child(right_runway)

	# 3. Overhead Hologram Directional Floating Badges (Elevated at Y = 3.6m - zero head obstruction!)
	var left_badge = _create_floating_badge("✊ PEOPLE'S RALLY (+25%)", Vector3(-2.5, 3.6, 2.0), Color(1.0, 0.35, 0.35))
	add_child(left_badge)

	var right_badge = _create_floating_badge("🏛️ IMPERIAL DECREE (+25%)", Vector3(2.5, 3.6, 2.0), Color(0.4, 0.75, 1.0))
	add_child(right_badge)


func _create_runway_strip(pos: Vector3, albedo: Color, emission: Color, trigger_name: String) -> Node3D:
	var root = Node3D.new()
	root.position = pos

	# Ground Runway Mesh (Flat Box on asphalt)
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2.2, 0.03, 16.0)
	mesh_inst.mesh = box_mesh

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	root.add_child(mesh_inst)

	if trigger_name == "PeopleTrigger":
		left_mat = mat
	else:
		right_mat = mat

	# Area3D Trigger
	var area = Area3D.new()
	area.name = trigger_name
	var col = CollisionShape3D.new()
	var col_shape = BoxShape3D.new()
	col_shape.size = Vector3(2.2, 1.8, 16.0)
	col.shape = col_shape
	col.position = Vector3(0.0, 0.9, 0.0)
	area.add_child(col)

	if trigger_name == "PeopleTrigger":
		area.body_entered.connect(_on_people_runway_entered)
	else:
		area.body_entered.connect(_on_govt_runway_entered)

	root.add_child(area)
	return root


func _create_floating_badge(text: String, pos: Vector3, col: Color) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font_size = 28
	label.outline_size = 8
	label.modulate = col
	label.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	return label


func _process(delta: float) -> void:
	time_accum += delta
	# Pulsing luminous neon glow
	var pulse: float = 1.6 + sin(time_accum * 6.0) * 0.5
	if left_mat:
		left_mat.emission_energy_multiplier = pulse
	if right_mat:
		right_mat.emission_energy_multiplier = pulse


func _on_people_runway_entered(body: Node3D) -> void:
	if has_triggered or not body.is_in_group("player"):
		return
	has_triggered = true

	# Apply People boost (+25 People, -10 Govt)
	if GameManager:
		GameManager.apply_decision(25.0, -10.0, "🔴 The People Rose in Rally! (+25% People)")

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_gate()

	if body.has_method("_spawn_floating_text"):
		body._spawn_floating_text("✊ PEOPLE'S RALLY! +25%", Color(1.0, 0.35, 0.35))


func _on_govt_runway_entered(body: Node3D) -> void:
	if has_triggered or not body.is_in_group("player"):
		return
	has_triggered = true

	# Apply Government boost (+25 Govt, -10 People)
	if GameManager:
		GameManager.apply_decision(-10.0, 25.0, "🔵 Imperial Decree Enacted! (+25% Govt)")

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_gate()

	if body.has_method("_spawn_floating_text"):
		body._spawn_floating_text("🏛️ IMPERIAL DECREE! +25%", Color(0.35, 0.75, 1.0))
