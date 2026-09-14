## BossEncounter.gd
## Mid-run 30-second historical Nemesis pursuit state machine.
## Pursues the player from behind, telegraphs lane attacks, and rewards a massive Relic Chest upon survival.
extends Node3D
class_name BossEncounter

# --- Boss Archetype Configurations ---
enum BossType {
	BRUTUS,        # Caesar Nemesis: Throws daggers across lanes
	ROBESPIERRE,   # Joan / Antoinette Nemesis: Drives mobile guillotine
	BOUNTY_HUNTER  # Harriet Tubman Nemesis: Sweeps searchlight beams
}

enum BossState {
	SPAWNING,
	PURSUING,
	ATTACKING,
	DEFEATED,
	EXITING
}

# --- Configuration Constants ---
const ENCOUNTER_DURATION: float = 30.0
const ATTACK_INTERVAL: float = 3.2
const LANES: Array[float] = [-2.5, 0.0, 2.5]

# --- State Variables ---
var boss_type: BossType = BossType.BRUTUS
var current_state: BossState = BossState.SPAWNING
var time_remaining: float = ENCOUNTER_DURATION
var attack_timer: float = 1.5
var boss_name: String = "Brutus"

var target_player: CharacterBody3D
var boss_mesh: Node3D
var searchlight_cone: MeshInstance3D
var warning_marker: MeshInstance3D


func _ready() -> void:
	_determine_nemesis()
	_build_boss_visuals()
	_create_warning_marker()

	var gm = _get_game_manager()
	if gm and gm.has_signal("boss_started"):
		gm.boss_started.emit(boss_name, ENCOUNTER_DURATION)


func _get_game_manager() -> Node:
	if is_inside_tree() and get_tree().root and get_tree().root.has_node("GameManager"):
		return get_tree().root.get_node("GameManager")
	return null


func _get_character_manager() -> Node:
	if is_inside_tree() and get_tree().root and get_tree().root.has_node("CharacterManager"):
		return get_tree().root.get_node("CharacterManager")
	return null


func _determine_nemesis() -> void:
	var cm = _get_character_manager()
	if cm and cm.get("active_character"):
		var char_res = cm.get("active_character")
		match char_res.get("character_name"):
			"Julius Caesar":
				boss_type = BossType.BRUTUS
				boss_name = "Brutus"
			"Joan of Arc":
				boss_type = BossType.ROBESPIERRE
				boss_name = "Robespierre"
			"Harriet Tubman":
				boss_type = BossType.BOUNTY_HUNTER
				boss_name = "Bounty Hunter"
			_:
				boss_type = BossType.BRUTUS
				boss_name = "Brutus"
	else:
		boss_type = BossType.BRUTUS
		boss_name = "Brutus"


func _build_boss_visuals() -> void:
	boss_mesh = Node3D.new()
	boss_mesh.name = "BossVehicle"
	add_child(boss_mesh)

	var body_inst: MeshInstance3D = MeshInstance3D.new()
	var body_box: BoxMesh = BoxMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()

	match boss_type:
		BossType.BRUTUS:
			body_box.size = Vector3(2.4, 1.4, 2.8)
			mat.albedo_color = Color(0.7, 0.15, 0.15)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.2, 0.1) * 0.5

		BossType.ROBESPIERRE:
			body_box.size = Vector3(2.2, 2.8, 2.6)
			mat.albedo_color = Color(0.2, 0.22, 0.25)
			mat.metallic = 0.8
			mat.roughness = 0.2

			var blade: MeshInstance3D = MeshInstance3D.new()
			var blade_mesh: BoxMesh = BoxMesh.new()
			blade_mesh.size = Vector3(1.8, 0.4, 0.1)
			var blade_mat: StandardMaterial3D = StandardMaterial3D.new()
			blade_mat.albedo_color = Color(0.9, 0.9, 0.95)
			blade_mat.metallic = 1.0
			blade.mesh = blade_mesh
			blade.material_override = blade_mat
			blade.position = Vector3(0.0, 1.2, -1.0)
			boss_mesh.add_child(blade)

		BossType.BOUNTY_HUNTER:
			body_box.size = Vector3(2.2, 1.6, 3.0)
			mat.albedo_color = Color(0.15, 0.3, 0.25)
			mat.roughness = 0.4

			searchlight_cone = MeshInstance3D.new()
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.top_radius = 0.2
			cylinder.bottom_radius = 1.4
			cylinder.height = 10.0
			var light_mat: StandardMaterial3D = StandardMaterial3D.new()
			light_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			light_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.35)
			light_mat.emission_enabled = true
			light_mat.emission = Color(1.0, 0.85, 0.2)
			searchlight_cone.mesh = cylinder
			searchlight_cone.material_override = light_mat
			searchlight_cone.rotation_degrees = Vector3(-90, 0, 0)
			searchlight_cone.position = Vector3(0.0, 1.2, -5.0)
			boss_mesh.add_child(searchlight_cone)

	body_inst.mesh = body_box
	body_inst.material_override = mat
	body_inst.position = Vector3(0.0, body_box.size.y * 0.5, 0.0)
	boss_mesh.add_child(body_inst)

	var label: Label3D = Label3D.new()
	label.text = "⚠️ NEMESIS: %s" % boss_name.to_upper()
	label.font_size = 28
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0)
	label.modulate = Color(1.0, 0.25, 0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 3.6, 0.0)
	boss_mesh.add_child(label)


func _create_warning_marker() -> void:
	warning_marker = MeshInstance3D.new()
	var quad: BoxMesh = BoxMesh.new()
	quad.size = Vector3(2.2, 0.05, 12.0)
	var warn_mat: StandardMaterial3D = StandardMaterial3D.new()
	warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warn_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.45)
	warn_mat.emission_enabled = true
	warn_mat.emission = Color(1.0, 0.2, 0.1)
	warning_marker.mesh = quad
	warning_marker.material_override = warn_mat
	warning_marker.visible = false
	add_child(warning_marker)


func _process(delta: float) -> void:
	var gm = _get_game_manager()
	if gm and gm.get("is_game_over"):
		return

	if not target_player:
		target_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if not target_player:
			return

	var desired_z: float = target_player.global_position.z + 8.5
	global_position.z = lerpf(global_position.z, desired_z, 10.0 * delta)

	match current_state:
		BossState.SPAWNING:
			global_position.x = 0.0
			current_state = BossState.PURSUING

		BossState.PURSUING, BossState.ATTACKING:
			time_remaining -= delta
			global_position.x = lerpf(global_position.x, target_player.global_position.x * 0.7, 4.0 * delta)

			attack_timer -= delta
			if attack_timer <= 0.0 and time_remaining > 3.0:
				attack_timer = ATTACK_INTERVAL
				_execute_boss_attack()

			if time_remaining <= 0.0:
				_trigger_boss_defeat()

		BossState.DEFEATED:
			global_position.z += 18.0 * delta
			rotate_z(delta * 2.0)

		BossState.EXITING:
			pass


func _execute_boss_attack() -> void:
	var target_lane: float = LANES.pick_random()
	warning_marker.position = Vector3(target_lane, 0.05, target_player.global_position.z - 12.0)
	warning_marker.visible = true

	var tween: Tween = create_tween()
	tween.tween_property(warning_marker, "scale", Vector3(1.2, 1.0, 1.0), 0.15)
	tween.tween_property(warning_marker, "scale", Vector3.ONE, 0.15)
	tween.set_loops(3)

	await get_tree().create_timer(1.1).timeout

	if current_state != BossState.PURSUING and current_state != BossState.ATTACKING:
		warning_marker.visible = false
		return

	warning_marker.visible = false
	_spawn_attack_projectile(target_lane)


func _spawn_attack_projectile(lane_x: float) -> void:
	var projectile: StaticBody3D = StaticBody3D.new()
	projectile.name = "Obstacle_BossAttack"
	projectile.add_to_group("obstacles")

	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.2, 1.2, 0.8)
	col.shape = box
	col.position = Vector3(0.0, 0.6, 0.0)
	projectile.add_child(col)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(2.2, 0.8, 0.8)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.1) * 1.5
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, 0.5, 0.0)
	projectile.add_child(mesh_inst)

	projectile.position = Vector3(lane_x, 0.0, target_player.global_position.z - 18.0)
	get_parent().add_child(projectile)

	var clean_tween = create_tween()
	clean_tween.tween_interval(3.0)
	clean_tween.tween_callback(projectile.queue_free)


func _trigger_boss_defeat() -> void:
	current_state = BossState.DEFEATED
	warning_marker.visible = false

	print("[BossEncounter] VICTORY! Nemesis %s was repelled!" % boss_name)
	var gm = _get_game_manager()
	if gm:
		if gm.has_signal("boss_ended"):
			gm.boss_ended.emit(true)
		if gm.has_method("apply_decision"):
			gm.apply_decision(30.0, 30.0, "NEMESIS DEFEATED: %s fell! Relic Chest Claimed!" % boss_name)
		gm.set("distance_traveled", gm.get("distance_traveled") + 500.0)

	_spawn_relic_chest()

	var tween: Tween = create_tween()
	tween.tween_property(boss_mesh, "scale", Vector3.ZERO, 1.5)
	tween.tween_callback(queue_free)


func _spawn_relic_chest() -> void:
	if not target_player:
		return

	var chest: Node3D = Node3D.new()
	chest.name = "RelicChest"
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.4, 1.2, 1.2)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.metallic = 0.9
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, 0.6, 0.0)
	chest.add_child(mesh_inst)

	var label: Label3D = Label3D.new()
	label.text = "🏆 RELIC CHEST\n+30 Favor  |  +500m"
	label.font_size = 28
	label.outline_size = 6
	label.modulate = Color(1.0, 0.9, 0.2)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 2.2, 0.0)
	chest.add_child(label)

	chest.position = Vector3(0.0, 0.0, target_player.global_position.z - 20.0)
	get_parent().add_child(chest)

	var tween: Tween = create_tween().set_loops(8)
	tween.tween_property(chest, "rotation:y", PI * 2, 2.0).as_relative()
