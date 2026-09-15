## TrackManager.gd
## Procedural 3D endless runner track spawner.
## Manages chunk pooling, road mesh generation, procedural obstacles,
## collectible power tokens, Decision Gates, Chronos Fracture Era Shifts, and Boss Encounters.
extends Node3D
class_name TrackManager

# --- Preloaded Scripts & Textures ---
const DecisionGateScript = preload("res://scripts/world/DecisionGate.gd")
const CollectibleScript = preload("res://scripts/world/Collectible.gd")
const BossEncounterScript = preload("res://scripts/world/BossEncounter.gd")
const TemporalPortalScript = preload("res://scripts/world/TemporalPortal.gd")

const PILLAR_SCN = preload("res://assets/sprites/props/roman_pillar.glb")
const AQUEDUCT_SCN = preload("res://assets/sprites/props/roman_aqueduct.glb")
const BRAZIER_SCN = preload("res://assets/sprites/props/curbside_brazier.glb")

const ROAD_ROMAN_TEX = preload("res://assets/sprites/environment/road_roman_pbr.png")
const COLLECTIBLE_FIST_TEX = preload("res://assets/sprites/props/collectible_fist.png")
const COLLECTIBLE_CROWN_TEX = preload("res://assets/sprites/props/collectible_crown.png")
const BARRICADE_TEX = preload("res://assets/sprites/props/obstacle_barricade.png")

# --- Configuration Constants ---
const CHUNK_LENGTH: float = 30.0
const ROAD_WIDTH: float = 10.0
const ROAD_THICKNESS: float = 0.2
const MAX_ACTIVE_CHUNKS: int = 6
const LANES: Array[float] = [-2.5, 0.0, 2.5]

const DECISION_GATE_INTERVAL: float = 300.0
const BOSS_ENCOUNTER_INTERVAL: float = 1500.0
const ERA_PORTAL_INTERVAL: float = 2000.0

# --- Historical Eras ---
enum EraTheme {
	ROMAN_MARBLE,      # Roman Republic (Default)
	FEUDAL_BAMBOO,     # Feudal Dynasty
	INDUSTRIAL_STEEL   # Industrial Revolution
}

var current_era: EraTheme = EraTheme.ROMAN_MARBLE

# Obstacle Type Enum
enum ObstacleType {
	NONE,
	LOW_HURDLE,
	HIGH_ARCH,
	SOLID_BLOCK
}

# --- Exported Properties ---
@export var player_node: CharacterBody3D
@export var world_env: WorldEnvironment

# --- Internal Pool & Tracking ---
var active_chunks: Array[Node3D] = []
var chunk_pool: Array[Node3D] = []
var next_spawn_z: float = 0.0
var chunks_spawned_count: int = 0

var distance_since_last_gate: float = 0.0
var distance_since_last_boss: float = 0.0
var distance_since_last_portal: float = 0.0
var is_boss_active: bool = false

# Cached Materials
var road_material: StandardMaterial3D
var lane_marker_material: StandardMaterial3D
var valley_material: StandardMaterial3D
var curb_material: StandardMaterial3D
var hurdle_material: StandardMaterial3D
var arch_material: StandardMaterial3D
var block_material: StandardMaterial3D
var fist_material: StandardMaterial3D
var crown_material: StandardMaterial3D


func _ready() -> void:
	_init_materials()

	if not player_node:
		player_node = get_tree().get_first_node_in_group("player") as CharacterBody3D

	if not world_env:
		world_env = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment

	if GameManager:
		GameManager.boss_ended.connect(func(_vic): is_boss_active = false)

	_apply_era_styling(current_era)
	_spawn_initial_tracks()


func _process(_delta: float) -> void:
	if not player_node:
		return

	var player_z: float = player_node.global_position.z

	while next_spawn_z > player_z - (MAX_ACTIVE_CHUNKS * CHUNK_LENGTH):
		_spawn_next_chunk()

	if active_chunks.size() > 0:
		var oldest_chunk: Node3D = active_chunks[0]
		if oldest_chunk.position.z - CHUNK_LENGTH > player_z + 10.0:
			_recycle_chunk(oldest_chunk)
			active_chunks.remove_at(0)


## Initializes shared materials with baseline properties.
func _init_materials() -> void:
	road_material = StandardMaterial3D.new()
	road_material.albedo_texture = ROAD_ROMAN_TEX
	road_material.uv1_scale = Vector3(2.5, 7.5, 1.0)
	road_material.roughness = 0.70
	road_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	lane_marker_material = StandardMaterial3D.new()
	lane_marker_material.albedo_color = Color(0.95, 0.78, 0.35)
	lane_marker_material.metallic = 0.85
	lane_marker_material.roughness = 0.30
	lane_marker_material.emission_enabled = true
	lane_marker_material.emission = Color(0.95, 0.75, 0.3) * 0.35

	valley_material = StandardMaterial3D.new()
	valley_material.albedo_color = Color(0.14, 0.12, 0.16)
	valley_material.roughness = 0.95

	curb_material = StandardMaterial3D.new()
	curb_material.albedo_color = Color(0.80, 0.78, 0.75)
	curb_material.roughness = 0.6

	hurdle_material = StandardMaterial3D.new()
	hurdle_material.emission_enabled = true

	arch_material = StandardMaterial3D.new()
	arch_material.emission_enabled = true

	block_material = StandardMaterial3D.new()
	block_material.emission_enabled = true

	# Collectibles
	fist_material = StandardMaterial3D.new()
	fist_material.albedo_color = Color(1.0, 0.22, 0.28)
	fist_material.emission_enabled = true
	fist_material.emission = Color(1.0, 0.22, 0.28)
	fist_material.emission_energy_multiplier = 1.2

	crown_material = StandardMaterial3D.new()
	crown_material.albedo_color = Color(0.25, 0.65, 1.0)
	crown_material.emission_enabled = true
	crown_material.emission = Color(0.25, 0.65, 1.0)
	crown_material.emission_energy_multiplier = 1.2


## Dynamic Era Morphing: Updates materials, colors, and skybox lighting.
func _apply_era_styling(era: EraTheme) -> void:
	current_era = era
	var era_title: String = ""

	match era:
		EraTheme.ROMAN_MARBLE:
			era_title = "Roman Republic"
			# Polished gray/white marble flagstones
			road_material.albedo_color = Color(1.0, 1.0, 1.0)
			lane_marker_material.albedo_color = Color(0.95, 0.85, 0.2)
			lane_marker_material.emission = Color(0.95, 0.8, 0.2) * 0.5
			curb_material.albedo_color = Color(0.7, 0.72, 0.76)
			hurdle_material.albedo_color = Color(0.15, 0.75, 0.95)
			hurdle_material.emission = Color(0.15, 0.75, 0.95) * 0.6
			arch_material.albedo_color = Color(0.95, 0.7, 0.1)
			arch_material.emission = Color(0.95, 0.7, 0.1) * 0.6
			block_material.albedo_color = Color(0.95, 0.25, 0.3)
			block_material.emission = Color(0.95, 0.25, 0.3) * 0.5

			_update_skybox(Color(0.12, 0.15, 0.22), Color(0.25, 0.30, 0.40), Color(0.18, 0.22, 0.30))

		EraTheme.FEUDAL_BAMBOO:
			era_title = "Feudal Dynasty"
			# Mossy dark stone & timber road tint
			road_material.albedo_color = Color(0.65, 0.78, 0.60)
			lane_marker_material.albedo_color = Color(0.95, 0.25, 0.15)
			lane_marker_material.emission = Color(0.95, 0.25, 0.15) * 0.6
			curb_material.albedo_color = Color(0.4, 0.3, 0.18)
			hurdle_material.albedo_color = Color(0.4, 0.8, 0.3)
			hurdle_material.emission = Color(0.3, 0.75, 0.2) * 0.6
			arch_material.albedo_color = Color(0.9, 0.2, 0.1) # Torii red
			arch_material.emission = Color(0.9, 0.2, 0.1) * 0.6
			block_material.albedo_color = Color(0.7, 0.5, 0.25)
			block_material.emission = Color(0.7, 0.45, 0.2) * 0.5

			_update_skybox(Color(0.28, 0.12, 0.22), Color(0.55, 0.25, 0.20), Color(0.35, 0.18, 0.20))

		EraTheme.INDUSTRIAL_STEEL:
			era_title = "Industrial Revolution"
			# Dark industrial cobblestone tint
			road_material.albedo_color = Color(0.45, 0.48, 0.55)
			lane_marker_material.albedo_color = Color(1.0, 0.75, 0.1)
			lane_marker_material.emission = Color(1.0, 0.7, 0.1) * 0.8
			curb_material.albedo_color = Color(0.25, 0.28, 0.32)
			hurdle_material.albedo_color = Color(0.9, 0.5, 0.1)
			hurdle_material.emission = Color(0.9, 0.45, 0.1) * 0.7
			arch_material.albedo_color = Color(0.2, 0.7, 0.8) # Steam pipe cyan
			arch_material.emission = Color(0.2, 0.7, 0.8) * 0.6
			block_material.albedo_color = Color(0.85, 0.2, 0.2)
			block_material.emission = Color(0.85, 0.2, 0.2) * 0.6

			_update_skybox(Color(0.15, 0.14, 0.12), Color(0.35, 0.26, 0.18), Color(0.25, 0.20, 0.15))

	if GameManager:
		GameManager.era_shifted.emit(era_title)


func _update_skybox(top_col: Color, horizon_col: Color, fog_col: Color) -> void:
	if not world_env or not world_env.environment:
		return
	var env: Environment = world_env.environment
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat: ProceduralSkyMaterial = env.sky.sky_material
		var tween: Tween = create_tween()
		tween.tween_property(sky_mat, "sky_top_color", top_col, 1.5)
		tween.parallel().tween_property(sky_mat, "sky_horizon_color", horizon_col, 1.5)
		tween.parallel().tween_property(env, "fog_light_color", fog_col, 1.5)


func _spawn_initial_tracks() -> void:
	next_spawn_z = 15.0
	distance_since_last_gate = 0.0
	distance_since_last_boss = 0.0
	distance_since_last_portal = 0.0

	for i in range(MAX_ACTIVE_CHUNKS):
		var allow_content: bool = (chunks_spawned_count >= 2)
		_spawn_chunk_at(next_spawn_z, allow_content, false, false)
		next_spawn_z -= CHUNK_LENGTH


func _spawn_next_chunk() -> void:
	var allow_content: bool = (chunks_spawned_count >= 2)
	distance_since_last_gate += CHUNK_LENGTH
	distance_since_last_boss += CHUNK_LENGTH
	distance_since_last_portal += CHUNK_LENGTH

	# 1. Chronos Fracture Portal (Every 2,000m)
	var is_portal_chunk: bool = false
	if distance_since_last_portal >= ERA_PORTAL_INTERVAL:
		is_portal_chunk = true
		distance_since_last_portal = 0.0

	# 2. Decision Gate (Every 300m)
	var is_decision_chunk: bool = false
	if not is_portal_chunk and distance_since_last_gate >= DECISION_GATE_INTERVAL:
		is_decision_chunk = true
		distance_since_last_gate = 0.0

	# 3. Boss Encounter (Every 1,500m)
	if not is_boss_active and distance_since_last_boss >= BOSS_ENCOUNTER_INTERVAL:
		distance_since_last_boss = 0.0
		_trigger_boss_encounter()

	_spawn_chunk_at(next_spawn_z, allow_content, is_decision_chunk, is_portal_chunk)
	next_spawn_z -= CHUNK_LENGTH


func _spawn_chunk_at(z_pos: float, allow_content: bool, is_decision_chunk: bool, is_portal_chunk: bool) -> void:
	var chunk: Node3D
	if chunk_pool.size() > 0:
		chunk = chunk_pool.pop_back()
		chunk.visible = true
	else:
		chunk = _create_track_chunk()
		add_child(chunk)

	chunk.position = Vector3(0.0, 0.0, z_pos)
	active_chunks.append(chunk)
	chunks_spawned_count += 1

	if is_portal_chunk:
		_spawn_temporal_portal(chunk)
	elif is_decision_chunk:
		_spawn_decision_gate(chunk)
	elif allow_content:
		if chunks_spawned_count % 2 == 0:
			var container: Node3D = chunk.get_node("DynamicElements")
			var aqueduct = AQUEDUCT_SCN.instantiate()
			aqueduct.position = Vector3(0.0, 0.0, -CHUNK_LENGTH * 0.5)
			container.add_child(aqueduct)
		_populate_chunk_obstacles(chunk)
		_populate_chunk_collectibles(chunk)


func _spawn_temporal_portal(chunk: Node3D) -> void:
	var container: Node3D = chunk.get_node("DynamicElements")
	var portal: Area3D = TemporalPortalScript.new()
	portal.position = Vector3(0.0, 0.0, -CHUNK_LENGTH * 0.5)
	portal.connect("portal_entered", _on_portal_entered)
	container.add_child(portal)


func _on_portal_entered() -> void:
	# Cycle to next era
	var next_era = (current_era + 1) % 3
	_apply_era_styling(next_era)


func _trigger_boss_encounter() -> void:
	if is_boss_active:
		return
	is_boss_active = true
	var boss: Node3D = BossEncounterScript.new()
	boss.position = Vector3(0.0, 0.0, player_node.global_position.z + 8.0)
	add_child(boss)


func _spawn_decision_gate(chunk: Node3D) -> void:
	var container: Node3D = chunk.get_node("DynamicElements")
	var gate: Node3D = DecisionGateScript.new()
	gate.position = Vector3(0.0, 0.0, -CHUNK_LENGTH * 0.5)
	container.add_child(gate)


func _recycle_chunk(chunk: Node3D) -> void:
	var dynamic_container: Node3D = chunk.get_node_or_null("DynamicElements")
	if dynamic_container:
		for child in dynamic_container.get_children():
			child.queue_free()

	chunk.visible = false
	chunk_pool.append(chunk)


func _create_track_chunk() -> Node3D:
	var chunk: Node3D = Node3D.new()
	chunk.name = "TrackChunk"

	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "RoadBody"
	chunk.add_child(static_body)

	var road_col_depth: float = 4.0
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(ROAD_WIDTH, road_col_depth, CHUNK_LENGTH)
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0.0, -road_col_depth * 0.5, -CHUNK_LENGTH * 0.5)
	static_body.add_child(collision_shape)

	var road_mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var road_box: BoxMesh = BoxMesh.new()
	road_box.size = Vector3(ROAD_WIDTH, 0.25, CHUNK_LENGTH)
	road_box.material = road_material
	road_mesh_inst.mesh = road_box
	road_mesh_inst.position = Vector3(0.0, -0.125, -CHUNK_LENGTH * 0.5)
	chunk.add_child(road_mesh_inst)

	# 1. Distant Valley Floor (eliminates the empty void underneath)
	var valley_inst: MeshInstance3D = MeshInstance3D.new()
	var valley_mesh: BoxMesh = BoxMesh.new()
	valley_mesh.size = Vector3(140.0, 1.0, CHUNK_LENGTH)
	valley_mesh.material = valley_material
	valley_inst.mesh = valley_mesh
	valley_inst.position = Vector3(0.0, -14.0, -CHUNK_LENGTH * 0.5)
	chunk.add_child(valley_inst)

	# 2. Roman Marble Curbs
	for side in [-1.0, 1.0]:
		var curb_inst: MeshInstance3D = MeshInstance3D.new()
		var curb_mesh: BoxMesh = BoxMesh.new()
		curb_mesh.size = Vector3(0.45, 0.35, CHUNK_LENGTH)
		curb_mesh.material = curb_material
		curb_inst.mesh = curb_mesh
		curb_inst.position = Vector3(side * (ROAD_WIDTH * 0.5 - 0.22), 0.1, -CHUNK_LENGTH * 0.5)
		chunk.add_child(curb_inst)

	# 3. Ancient Bronze Lane Dividers & Marble Inlay Grooves (Replacing modern yellow dashed lines)
	for div_x in [-1.25, 1.25]:
		var groove_inst: MeshInstance3D = MeshInstance3D.new()
		var groove_mesh: BoxMesh = BoxMesh.new()
		groove_mesh.size = Vector3(0.06, 0.015, CHUNK_LENGTH)
		groove_mesh.material = lane_marker_material
		groove_inst.mesh = groove_mesh
		groove_inst.position = Vector3(div_x, 0.008, -CHUNK_LENGTH * 0.5)
		chunk.add_child(groove_inst)

		for s in range(10):
			var stud_inst: MeshInstance3D = MeshInstance3D.new()
			var stud_mesh: CylinderMesh = CylinderMesh.new()
			stud_mesh.top_radius = 0.09
			stud_mesh.bottom_radius = 0.12
			stud_mesh.height = 0.035
			stud_mesh.material = lane_marker_material
			stud_inst.mesh = stud_mesh
			stud_inst.position = Vector3(div_x, 0.018, -(s * 3.0 + 1.5))
			chunk.add_child(stud_inst)

	# 4. Roman Colonnade (Pillars & Fire Braziers along track borders)
	for side in [-1.0, 1.0]:
		var col_x: float = side * (ROAD_WIDTH * 0.5 + 1.4)
		# Fluted Roman Columns
		for p_i in range(4):
			var pillar = PILLAR_SCN.instantiate()
			pillar.position = Vector3(col_x, 0.0, -(p_i * 7.5 + 3.75))
			chunk.add_child(pillar)

		# Curbside Fire Braziers with warm point lights
		for b_i in range(2):
			var brazier = BRAZIER_SCN.instantiate()
			var b_z: float = -(b_i * 15.0 + 7.5)
			brazier.position = Vector3(col_x, 0.0, b_z)
			chunk.add_child(brazier)

			var flame_light = OmniLight3D.new()
			flame_light.light_color = Color(1.0, 0.65, 0.25)
			flame_light.light_energy = 1.6
			flame_light.omni_range = 8.0
			flame_light.omni_attenuation = 1.4
			flame_light.position = Vector3(col_x, 1.4, b_z)
			chunk.add_child(flame_light)

	var dynamic_container: Node3D = Node3D.new()
	dynamic_container.name = "DynamicElements"
	chunk.add_child(dynamic_container)

	return chunk


func _populate_chunk_obstacles(chunk: Node3D) -> void:
	var container: Node3D = chunk.get_node("DynamicElements")
	var z_offsets: Array[float] = [-10.0, -22.0]

	for z_offset in z_offsets:
		if randf() > 0.85:
			continue

		var lanes_shuffled: Array[float] = LANES.duplicate()
		lanes_shuffled.shuffle()

		var blocked_count: int = 1 if randf() < 0.65 else 2

		for i in range(blocked_count):
			var lane_x: float = lanes_shuffled[i]
			var type_roll: float = randf()
			var obs_type: ObstacleType
			if type_roll < 0.35:
				obs_type = ObstacleType.LOW_HURDLE
			elif type_roll < 0.70:
				obs_type = ObstacleType.HIGH_ARCH
			else:
				obs_type = ObstacleType.SOLID_BLOCK

			var obstacle_node: Node3D = _create_obstacle(obs_type)
			obstacle_node.position = Vector3(lane_x, 0.0, z_offset)
			container.add_child(obstacle_node)


func _populate_chunk_collectibles(chunk: Node3D) -> void:
	var container: Node3D = chunk.get_node("DynamicElements")
	var collectible_z_positions: Array[float] = [-5.0, -16.0, -27.0]

	for z_pos in collectible_z_positions:
		if randf() > 0.60:
			continue

		var lane_x: float = LANES.pick_random()
		var is_fist: bool = randf() < 0.50
		var token: Area3D = _create_collectible(
			CollectibleScript.CollectibleType.PEOPLE_FIST if is_fist else CollectibleScript.CollectibleType.GOVT_CROWN
		)
		token.position = Vector3(lane_x, 0.9, z_pos)
		container.add_child(token)


func _create_collectible(type: int) -> Area3D:
	var token: Area3D = CollectibleScript.new()
	token.set("type", type)

	var col: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 0.55
	col.shape = sphere_shape
	token.add_child(col)

	var sprite: Sprite3D = Sprite3D.new()
	sprite.name = "CollectibleSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.pixel_size = 0.85 / 1024.0

	var light: OmniLight3D = OmniLight3D.new()
	light.omni_range = 5.0
	light.omni_attenuation = 1.3

	if type == CollectibleScript.CollectibleType.PEOPLE_FIST:
		sprite.texture = COLLECTIBLE_FIST_TEX
		light.light_color = Color(1.0, 0.22, 0.28)
		light.light_energy = 2.4
	else:
		sprite.texture = COLLECTIBLE_CROWN_TEX
		light.light_color = Color(0.28, 0.72, 1.0)
		light.light_energy = 2.4

	token.add_child(sprite)
	token.add_child(light)
	return token


func _create_obstacle(type: ObstacleType) -> Node3D:
	var obstacle_root: StaticBody3D = StaticBody3D.new()
	obstacle_root.add_to_group("obstacles")

	match type:
		ObstacleType.LOW_HURDLE:
			obstacle_root.name = "Obstacle_LowHurdle"
			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(2.2, 0.65, 0.25)
			col.shape = box
			col.position = Vector3(0.0, 0.325, 0.0)
			obstacle_root.add_child(col)

			var bar_mesh: MeshInstance3D = MeshInstance3D.new()
			var bar: BoxMesh = BoxMesh.new()
			bar.size = Vector3(2.2, 0.25, 0.2)
			bar.material = hurdle_material
			bar_mesh.mesh = bar
			bar_mesh.position = Vector3(0.0, 0.5, 0.0)
			obstacle_root.add_child(bar_mesh)

			for side in [-1.0, 1.0]:
				var stand_mesh: MeshInstance3D = MeshInstance3D.new()
				var stand: BoxMesh = BoxMesh.new()
				stand.size = Vector3(0.12, 0.65, 0.3)
				stand.material = curb_material
				stand_mesh.mesh = stand
				stand_mesh.position = Vector3(side * 1.0, 0.325, 0.0)
				obstacle_root.add_child(stand_mesh)

		ObstacleType.HIGH_ARCH:
			obstacle_root.name = "Obstacle_HighArch"
			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(2.2, 1.0, 0.35)
			col.shape = box
			col.position = Vector3(0.0, 1.7, 0.0)
			obstacle_root.add_child(col)

			var bar_mesh: MeshInstance3D = MeshInstance3D.new()
			var bar: BoxMesh = BoxMesh.new()
			bar.size = Vector3(2.3, 0.6, 0.35)
			bar.material = arch_material
			bar_mesh.mesh = bar
			bar_mesh.position = Vector3(0.0, 1.8, 0.0)
			obstacle_root.add_child(bar_mesh)

			var stripe_mesh: MeshInstance3D = MeshInstance3D.new()
			var stripe: BoxMesh = BoxMesh.new()
			stripe.size = Vector3(2.0, 0.15, 0.37)
			stripe.material = lane_marker_material
			stripe_mesh.mesh = stripe
			stripe_mesh.position = Vector3(0.0, 1.55, 0.0)
			obstacle_root.add_child(stripe_mesh)

			for side in [-1.0, 1.0]:
				var pillar_mesh: MeshInstance3D = MeshInstance3D.new()
				var pillar: BoxMesh = BoxMesh.new()
				pillar.size = Vector3(0.15, 2.2, 0.3)
				pillar.material = curb_material
				pillar_mesh.mesh = pillar
				pillar_mesh.position = Vector3(side * 1.15, 1.1, 0.0)
				obstacle_root.add_child(pillar_mesh)

		ObstacleType.SOLID_BLOCK:
			obstacle_root.name = "Obstacle_SolidBlock"
			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(2.2, 2.4, 0.6)
			col.shape = box
			col.position = Vector3(0.0, 1.2, 0.0)
			obstacle_root.add_child(col)

			# AAA Roman Fortified Barricade Sprite with 3D shadow casting
			var barricade_sprite: Sprite3D = Sprite3D.new()
			barricade_sprite.name = "BarricadeSprite3D"
			barricade_sprite.texture = BARRICADE_TEX
			barricade_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISCARD
			barricade_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			barricade_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			barricade_sprite.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
			barricade_sprite.pixel_size = 2.4 / 1024.0
			barricade_sprite.position = Vector3(0.0, 1.2, 0.0)
			obstacle_root.add_child(barricade_sprite)

	return obstacle_root
