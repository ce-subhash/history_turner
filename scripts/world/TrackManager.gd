## TrackManager.gd
## Procedural 3D endless runner track spawner for the Grand Capital Boulevard.
## Spawns 3-lane asphalt road with lane markings, yellow/black curbs,
## sidewalks with cheering crowds holding campaign signs, trees, lampposts,
## and parliament dome horizon backdrop.
## Obstacles include: Moving Bull Cart (People), Police K9 Dogs (Police),
## Police Riot Barricade, Wooden Roadblock, Slide Canopy, and Jump Ramp.
## Collectibles include: People Support Heart tokens and Govt Support Temple tokens.
extends Node3D
class_name TrackManager

# --- Preloaded Scripts & 3D Props ---
const DecisionGateScript = preload("res://scripts/world/DecisionGate.gd")
const CollectibleScript = preload("res://scripts/world/Collectible.gd")
const BossEncounterScript = preload("res://scripts/world/BossEncounter.gd")
const TemporalPortalScript = preload("res://scripts/world/TemporalPortal.gd")
const MovingObstacleScript = preload("res://scripts/world/MovingObstacle.gd")
const JumpRampScript = preload("res://scripts/world/JumpRamp.gd")
const PowerUpPickupScript = preload("res://scripts/world/PowerUpPickup.gd")
const WoodFireObstacleScript = preload("res://scripts/world/WoodFireObstacle.gd")



# 3D GLB Props
const BULL_CART_SCN = preload("res://assets/sprites/props/bull_cart.glb")
const POLICE_DOG_SCN = preload("res://assets/sprites/props/police_dog.glb")
const POLICE_BARRICADE_SCN = preload("res://assets/sprites/props/police_barricade.glb")
const WOODEN_ROADBLOCK_SCN = preload("res://assets/sprites/props/wooden_roadblock.glb")
const SLIDE_TUNNEL_SCN = preload("res://assets/sprites/props/slide_tunnel.glb")
const JUMP_RAMP_SCN = preload("res://assets/sprites/props/jump_ramp.glb")
const BOULEVARD_TREE_SCN = preload("res://assets/sprites/props/boulevard_tree.glb")
const LAMPPOST_SCN = preload("res://assets/sprites/props/street_lamppost.glb")
const CROWD_SIDEWALK_SCN = preload("res://assets/sprites/props/crowd_sidewalk.glb")
const PARLIAMENT_DOME_SCN = preload("res://assets/sprites/props/parliament_dome.glb")

# 2D Tokens & Stylized Props
const TOKEN_HEART_TEX = preload("res://assets/sprites/props/token_heart.png")
const TOKEN_TEMPLE_TEX = preload("res://assets/sprites/props/token_temple.png")
const POLICE_BARRICADE_TEX = preload("res://assets/sprites/props/police_barricade.png")
const JUMP_RAMP_TEX = preload("res://assets/sprites/props/jump_ramp.png")
const BULL_CART_TEX = preload("res://assets/sprites/props/bull_cart.png")
const STONE_BLOCK_TEX = preload("res://assets/sprites/props/stone_block.png")
const WOOD_FIRE_TEX = preload("res://assets/sprites/props/wood_fire.png")

# --- Configuration Constants ---
const CHUNK_LENGTH: float = 30.0
const ROAD_WIDTH: float = 8.6
const ROAD_THICKNESS: float = 0.25
const MAX_ACTIVE_CHUNKS: int = 6
const LANES: Array[float] = [-2.5, 0.0, 2.5]

const DECISION_GATE_INTERVAL: float = 350.0
const BOSS_ENCOUNTER_INTERVAL: float = 1500.0
const ERA_PORTAL_INTERVAL: float = 2500.0

enum ObstacleCategory {
	WOOD_FIRE,        # Three-wood tripod bonfire / campfire (People faction)
	BULL_CART = 0,    # Backwards-compatible alias for tests
	STONE_BLOCK,      # Classical Carved Stone Monument Block
	POLICE_BARRICADE, # Riot police barricade with shields (Police faction)
	WOODEN_ROADBLOCK, # Timber barricade with NO ENTRY plaque
	JUMP_RAMP         # Launch ramp
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

# Shared Materials
var asphalt_material: StandardMaterial3D
var lane_stripe_material: StandardMaterial3D
var curb_yellow_material: StandardMaterial3D
var curb_black_material: StandardMaterial3D
var sidewalk_stone_material: StandardMaterial3D
var ground_grass_material: StandardMaterial3D

# Horizon Parliament Backdrop instance
var horizon_parliament_node: Node3D = null


func _ready() -> void:
	_init_materials()

	if not player_node:
		player_node = get_tree().get_first_node_in_group("player") as CharacterBody3D

	if not world_env:
		world_env = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment

	if GameManager:
		GameManager.boss_ended.connect(func(_vic): is_boss_active = false)

	_spawn_horizon_parliament()
	_spawn_initial_tracks()


func _process(_delta: float) -> void:
	if not player_node:
		return

	var player_z: float = player_node.global_position.z

	# Keep horizon parliament dome centered in the far background
	if horizon_parliament_node:
		horizon_parliament_node.position.z = player_z - 120.0

	while next_spawn_z > player_z - (MAX_ACTIVE_CHUNKS * CHUNK_LENGTH):
		_spawn_next_chunk()

	if active_chunks.size() > 0:
		var oldest_chunk: Node3D = active_chunks[0]
		if oldest_chunk.position.z - CHUNK_LENGTH > player_z + 10.0:
			_recycle_chunk(oldest_chunk)
			active_chunks.remove_at(0)


func _init_materials() -> void:
	# 1. Asphalt Road Material
	asphalt_material = StandardMaterial3D.new()
	asphalt_material.albedo_color = Color(0.24, 0.25, 0.27)
	asphalt_material.roughness = 0.82
	asphalt_material.metallic = 0.05

	# 2. Crisp White Lane Stripe Material
	lane_stripe_material = StandardMaterial3D.new()
	lane_stripe_material.albedo_color = Color(0.96, 0.96, 0.94)
	lane_stripe_material.roughness = 0.4
	lane_stripe_material.emission_enabled = true
	lane_stripe_material.emission = Color(0.96, 0.96, 0.94) * 0.15

	# 3. Yellow and Black Curbs
	curb_yellow_material = StandardMaterial3D.new()
	curb_yellow_material.albedo_color = Color(0.95, 0.76, 0.12)
	curb_yellow_material.roughness = 0.5

	curb_black_material = StandardMaterial3D.new()
	curb_black_material.albedo_color = Color(0.12, 0.12, 0.14)
	curb_black_material.roughness = 0.6

	# 4. Sidewalk Stone Pavement
	sidewalk_stone_material = StandardMaterial3D.new()
	sidewalk_stone_material.albedo_color = Color(0.82, 0.78, 0.70)
	sidewalk_stone_material.roughness = 0.75

	# 5. Grass Ground Fill
	ground_grass_material = StandardMaterial3D.new()
	ground_grass_material.albedo_color = Color(0.28, 0.52, 0.22)
	ground_grass_material.roughness = 0.9


func _spawn_horizon_parliament() -> void:
	if PARLIAMENT_DOME_SCN:
		horizon_parliament_node = PARLIAMENT_DOME_SCN.instantiate()
		horizon_parliament_node.name = "HorizonParliament"
		horizon_parliament_node.position = Vector3(0.0, 0.0, -120.0)
		horizon_parliament_node.scale = Vector3(2.5, 2.5, 2.5)
		add_child(horizon_parliament_node)


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

	# 1. Chronos Fracture Portal (Every 2,500m)
	var is_portal_chunk: bool = false
	if distance_since_last_portal >= ERA_PORTAL_INTERVAL:
		is_portal_chunk = true
		distance_since_last_portal = 0.0

	# 2. Decision Gate (Every 350m)
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
		_populate_chunk_obstacles(chunk)
		_populate_chunk_collectibles(chunk)
		_maybe_spawn_powerup(chunk)



func _spawn_temporal_portal(chunk: Node3D) -> void:
	var container: Node3D = chunk.get_node("DynamicElements")
	var portal: Area3D = TemporalPortalScript.new()
	portal.position = Vector3(0.0, 0.0, -CHUNK_LENGTH * 0.5)
	container.add_child(portal)


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


## Constructs a Boulevard chunk: 3-lane road, lane markings, striped curbs, sidewalks, crowds, trees, and lampposts.
func _create_track_chunk() -> Node3D:
	var chunk: Node3D = Node3D.new()
	chunk.name = "TrackChunk"

	# Deep road collision body to prevent any physics tunneling
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "RoadBody"
	chunk.add_child(static_body)

	var road_col_depth: float = 4.0
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(ROAD_WIDTH + 6.0, road_col_depth, CHUNK_LENGTH)
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0.0, -road_col_depth * 0.5, -CHUNK_LENGTH * 0.5)
	static_body.add_child(collision_shape)

	# 1. Asphalt Road Surface
	var road_mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var road_box: BoxMesh = BoxMesh.new()
	road_box.size = Vector3(ROAD_WIDTH, ROAD_THICKNESS, CHUNK_LENGTH)
	road_box.material = asphalt_material
	road_mesh_inst.mesh = road_box
	road_mesh_inst.position = Vector3(0.0, -ROAD_THICKNESS * 0.5, -CHUNK_LENGTH * 0.5)
	chunk.add_child(road_mesh_inst)

	# 2. White Lane Dividers (Dashed markings between lanes)
	for div_x in [-1.25, 1.25]:
		for s in range(5):
			var stripe: MeshInstance3D = MeshInstance3D.new()
			var s_box: BoxMesh = BoxMesh.new()
			s_box.size = Vector3(0.14, 0.015, 3.2)
			s_box.material = lane_stripe_material
			stripe.mesh = s_box
			stripe.position = Vector3(div_x, 0.008, -(s * 6.0 + 3.0))
			chunk.add_child(stripe)

	# Solid White Road Edge Lines
	for edge_x in [-ROAD_WIDTH * 0.5 + 0.15, ROAD_WIDTH * 0.5 - 0.15]:
		var edge_line: MeshInstance3D = MeshInstance3D.new()
		var e_box: BoxMesh = BoxMesh.new()
		e_box.size = Vector3(0.14, 0.015, CHUNK_LENGTH)
		e_box.material = lane_stripe_material
		edge_line.mesh = e_box
		edge_line.position = Vector3(edge_x, 0.008, -CHUNK_LENGTH * 0.5)
		chunk.add_child(edge_line)

	# 3. Yellow and Black Striped Curbs
	for side in [-1.0, 1.0]:
		var curb_x: float = side * (ROAD_WIDTH * 0.5 + 0.18)
		for s in range(10):
			var curb_seg: MeshInstance3D = MeshInstance3D.new()
			var c_box: BoxMesh = BoxMesh.new()
			c_box.size = Vector3(0.36, 0.28, 3.0)
			c_box.material = curb_yellow_material if s % 2 == 0 else curb_black_material
			curb_seg.mesh = c_box
			curb_seg.position = Vector3(curb_x, 0.10, -(s * 3.0 + 1.5))
			chunk.add_child(curb_seg)

	# 4. Sidewalks on Left and Right
	for side in [-1.0, 1.0]:
		var sidewalk_x: float = side * (ROAD_WIDTH * 0.5 + 2.2)
		var sidewalk_mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var sw_box: BoxMesh = BoxMesh.new()
		sw_box.size = Vector3(3.6, 0.24, CHUNK_LENGTH)
		sw_box.material = sidewalk_stone_material
		sidewalk_mesh_inst.mesh = sw_box
		sidewalk_mesh_inst.position = Vector3(sidewalk_x, 0.08, -CHUNK_LENGTH * 0.5)
		chunk.add_child(sidewalk_mesh_inst)

		# Grass Park Lawn beyond sidewalk
		var grass_x: float = side * (ROAD_WIDTH * 0.5 + 12.0)
		var grass_inst: MeshInstance3D = MeshInstance3D.new()
		var grass_box: BoxMesh = BoxMesh.new()
		grass_box.size = Vector3(16.0, 0.20, CHUNK_LENGTH)
		grass_box.material = ground_grass_material
		grass_inst.mesh = grass_box
		grass_inst.position = Vector3(grass_x, 0.04, -CHUNK_LENGTH * 0.5)
		chunk.add_child(grass_inst)

		# Street Trees along sidewalk
		var tree1 = BOULEVARD_TREE_SCN.instantiate()
		tree1.name = "BoulevardTree1"
		tree1.position = Vector3(side * (ROAD_WIDTH * 0.5 + 3.2), 0.0, -8.0)
		chunk.add_child(tree1)

		var tree2 = BOULEVARD_TREE_SCN.instantiate()
		tree2.name = "BoulevardTree2"
		tree2.position = Vector3(side * (ROAD_WIDTH * 0.5 + 3.2), 0.0, -22.0)
		chunk.add_child(tree2)

		# Ornate Vintage Street Lampposts
		var lamp = LAMPPOST_SCN.instantiate()
		lamp.name = "StreetLamppost"
		lamp.position = Vector3(side * (ROAD_WIDTH * 0.5 + 1.2), 0.0, -15.0)
		chunk.add_child(lamp)

		# Cheering Crowds holding campaign signs along the outer sidewalk
		var crowd = CROWD_SIDEWALK_SCN.instantiate()
		crowd.name = "CrowdSidewalk"
		crowd.position = Vector3(side * (ROAD_WIDTH * 0.5 + 3.2), 0.0, -15.0)
		if side < 0:
			crowd.rotation_degrees.y = 180.0
		else:
			crowd.rotation_degrees.y = 0.0
		chunk.add_child(crowd)

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
			var obs_cat: ObstacleCategory = _pick_random_obstacle_category()
			var obstacle_node: Node3D = _create_obstacle(obs_cat)
			obstacle_node.position = Vector3(lane_x, 0.0, z_offset)
			container.add_child(obstacle_node)


func _pick_random_obstacle_category() -> ObstacleCategory:
	var roll: float = randf()
	if roll < 0.25:
		return ObstacleCategory.WOOD_FIRE        # Three-Wood Tripod Campfire (People)
	elif roll < 0.48:
		return ObstacleCategory.STONE_BLOCK      # Classical Carved Stone Block
	elif roll < 0.70:
		return ObstacleCategory.POLICE_BARRICADE # Police Riot Barricade (Police)
	elif roll < 0.88:
		return ObstacleCategory.WOODEN_ROADBLOCK # Wooden Roadblock
	else:
		return ObstacleCategory.JUMP_RAMP        # Jump Ramp



func _populate_chunk_collectibles(chunk: Node3D) -> void:
	var container: Node3D = chunk.get_node("DynamicElements")
	var collectible_z_positions: Array[float] = [-5.0, -16.0, -27.0]

	for z_pos in collectible_z_positions:
		if randf() > 0.60:
			continue

		var lane_x: float = LANES.pick_random()
		var is_heart: bool = randf() < 0.50
		var token: Area3D = _create_collectible(
			CollectibleScript.CollectibleType.PEOPLE_FIST if is_heart else CollectibleScript.CollectibleType.GOVT_CROWN
		)
		token.position = Vector3(lane_x, 0.9, z_pos)
		container.add_child(token)


## Periodically spawns a rare game-changing powerup pickup (Magnet, Shield, or Imperial Dash).
func _maybe_spawn_powerup(chunk: Node3D) -> void:
	# Truly rare arcade treat: only checks every 16 chunks (~480m) with 65% spawn chance
	if chunks_spawned_count < 8 or (chunks_spawned_count % 16 != 0) or randf() > 0.65:
		return


	var container: Node3D = chunk.get_node("DynamicElements")
	var powerup = PowerUpPickupScript.new()
	var types = [
		PowerUpPickupScript.PowerUpType.MAGNET,
		PowerUpPickupScript.PowerUpType.SHIELD,
		PowerUpPickupScript.PowerUpType.BOOST
	]

	powerup.powerup_type = types.pick_random()
	var lane_x: float = LANES.pick_random()
	powerup.position = Vector3(lane_x, 1.0, -CHUNK_LENGTH * 0.5)
	container.add_child(powerup)


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
	sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.pixel_size = 0.85 / 1024.0

	var light: OmniLight3D = OmniLight3D.new()
	light.omni_range = 5.0
	light.omni_attenuation = 1.3

	if type == CollectibleScript.CollectibleType.PEOPLE_FIST:
		sprite.texture = TOKEN_HEART_TEX
		light.light_color = Color(1.0, 0.22, 0.28)
		light.light_energy = 2.4
	else:
		sprite.texture = TOKEN_TEMPLE_TEX
		light.light_color = Color(0.15, 0.70, 1.0)
		light.light_energy = 2.4

	token.add_child(sprite)
	token.add_child(light)
	return token


func _create_obstacle(category: ObstacleCategory) -> Node3D:
	match category:
		ObstacleCategory.WOOD_FIRE:
			# Three-Wood Tripod Campfire Obstacle (Static, easy-to-jump hazard)
			var fire_obs: Node3D = WoodFireObstacleScript.new()
			return fire_obs


		ObstacleCategory.STONE_BLOCK:
			# Heavy Classical Carved Stone Monument Block (Ancient Republic Obstacle)
			var body: StaticBody3D = StaticBody3D.new()
			body.name = "Obstacle_StoneBlock"
			body.add_to_group("obstacles")

			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(1.6, 0.82, 0.5)
			col.shape = box
			col.position = Vector3(0.0, 0.41, 0.0)
			body.add_child(col)

			var sprite: Sprite3D = Sprite3D.new()
			sprite.name = "StoneBlockSprite"
			sprite.texture = STONE_BLOCK_TEX
			sprite.centered = true
			sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.pixel_size = 1.6 / 1024.0
			sprite.position = Vector3(0.0, 0.70, 0.0)
			sprite.rotation_degrees = Vector3.ZERO
			sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			body.add_child(sprite)

			return body

		ObstacleCategory.POLICE_BARRICADE:
			# High-Res 3D-Stylized Police Road Barricade with flashing sirens
			var body: StaticBody3D = StaticBody3D.new()
			body.name = "Obstacle_PoliceBarricade"
			body.add_to_group("obstacles")

			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(1.8, 0.80, 0.3)
			col.shape = box
			col.position = Vector3(0.0, 0.40, 0.0)
			body.add_child(col)

			var sprite: Sprite3D = Sprite3D.new()
			sprite.name = "BarricadeSprite"
			sprite.texture = POLICE_BARRICADE_TEX
			sprite.centered = true
			sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.pixel_size = 1.75 / 1024.0
			sprite.position = Vector3(0.0, 0.88, 0.0)
			body.add_child(sprite)

			# Red and Blue emergency flashing lights
			var red_siren: OmniLight3D = OmniLight3D.new()
			red_siren.light_color = Color(1.0, 0.15, 0.15)
			red_siren.light_energy = 3.2
			red_siren.omni_range = 4.5
			red_siren.position = Vector3(-0.45, 1.45, 0.1)
			body.add_child(red_siren)

			var blue_siren: OmniLight3D = OmniLight3D.new()
			blue_siren.light_color = Color(0.15, 0.45, 1.0)
			blue_siren.light_energy = 3.2
			blue_siren.omni_range = 4.5
			blue_siren.position = Vector3(0.45, 1.45, 0.1)
			body.add_child(blue_siren)

			return body

		ObstacleCategory.WOODEN_ROADBLOCK:
			# Heavy Timber Roadblock with NO ENTRY plaque
			var body: StaticBody3D = StaticBody3D.new()
			body.name = "Obstacle_WoodenRoadblock"
			body.add_to_group("obstacles")

			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(1.6, 0.80, 0.3)
			col.shape = box
			col.position = Vector3(0.0, 0.40, 0.0)
			body.add_child(col)

			var visual = WOODEN_ROADBLOCK_SCN.instantiate()
			body.add_child(visual)
			return body

		ObstacleCategory.JUMP_RAMP:
			# High-Res Stylized Speed Launch Boost Ramp
			var body: Node3D = Node3D.new()
			body.name = "Speed_JumpRamp"

			var ramp_area: Area3D = Area3D.new()
			ramp_area.name = "RampTrigger"
			ramp_area.set_script(JumpRampScript)
			ramp_area.set("launch_velocity", 13.5)
			ramp_area.set("speed_boost", 6.5)
			ramp_area.set("boost_duration", 2.5)

			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(2.2, 1.0, 2.8)
			col.shape = box
			col.position = Vector3(0.0, 0.5, 0.0)
			ramp_area.add_child(col)

			# 1. Inclined 3D Ramp Surface (Runs smoothly from road level Y=0.06 up to launch lip Y=0.84)
			var ramp_mesh: MeshInstance3D = MeshInstance3D.new()
			ramp_mesh.name = "RampSurface"
			var plane: PlaneMesh = PlaneMesh.new()
			plane.size = Vector2(2.1, 3.0)
			ramp_mesh.mesh = plane

			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_texture = JUMP_RAMP_TEX
			mat.emission_enabled = true
			mat.emission_texture = JUMP_RAMP_TEX
			mat.emission_energy_multiplier = 1.35
			mat.roughness = 0.25
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			ramp_mesh.material_override = mat

			ramp_mesh.position = Vector3(0.0, 0.45, 0.0)
			ramp_mesh.rotation_degrees = Vector3(15.0, 0.0, 0.0)
			body.add_child(ramp_mesh)

			# 2. Side Gold Guardrails (slope upward along the ramp)
			for side in [-1.0, 1.0]:
				var rail: MeshInstance3D = MeshInstance3D.new()
				var box_mesh: BoxMesh = BoxMesh.new()
				box_mesh.size = Vector3(0.12, 0.16, 3.0)
				rail.mesh = box_mesh
				var r_mat: StandardMaterial3D = StandardMaterial3D.new()
				r_mat.albedo_color = Color(1.0, 0.82, 0.22)
				r_mat.metallic = 0.8
				r_mat.roughness = 0.25
				r_mat.emission_enabled = true
				r_mat.emission = Color(1.0, 0.80, 0.20)
				r_mat.emission_energy_multiplier = 0.6
				rail.material_override = r_mat
				rail.position = Vector3(side * 1.02, 0.52, 0.0)
				rail.rotation_degrees = Vector3(15.0, 0.0, 0.0)
				body.add_child(rail)

			# 3. Vibrant Cyan/Gold Nitro Boost Underglow
			var boost_light: OmniLight3D = OmniLight3D.new()
			boost_light.light_color = Color(1.0, 0.82, 0.25)
			boost_light.light_energy = 3.5
			boost_light.omni_range = 5.5
			boost_light.position = Vector3(0.0, 0.4, 0.0)
			body.add_child(boost_light)

			body.add_child(ramp_area)
			return body

	# Default fallback
	var fallback: StaticBody3D = StaticBody3D.new()
	fallback.name = "Obstacle_SolidBlock"
	fallback.add_to_group("obstacles")
	var fcol: CollisionShape3D = CollisionShape3D.new()
	var fbox: BoxShape3D = BoxShape3D.new()
	fbox.size = Vector3(1.6, 1.2, 0.4)
	fcol.shape = fbox
	fcol.position = Vector3(0.0, 0.6, 0.0)
	fallback.add_child(fcol)
	return fallback
