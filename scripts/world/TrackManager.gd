## TrackManager.gd
## Procedural 3D endless runner track spawner.
## Manages chunk pooling, road mesh generation, procedural obstacles,
## collectible power tokens (People Fist & Govt Crown), and every 300m Decision Gates.
extends Node3D
class_name TrackManager

# --- Configuration Constants ---
const CHUNK_LENGTH: float = 30.0
const ROAD_WIDTH: float = 10.0
const ROAD_THICKNESS: float = 0.2
const MAX_ACTIVE_CHUNKS: int = 6
const LANES: Array[float] = [-2.5, 0.0, 2.5]
const DECISION_GATE_INTERVAL: float = 300.0

# Colors & Aesthetics (Low-Poly Cyber / Strategic runner palette)
const COLOR_ROAD: Color = Color(0.18, 0.20, 0.24)
const COLOR_LANE_MARKER: Color = Color(0.85, 0.90, 0.95, 0.8)
const COLOR_HURDLE: Color = Color(0.15, 0.75, 0.95)   # Cyan (Jump)
const COLOR_ARCH: Color = Color(0.95, 0.70, 0.10)     # Amber/Gold (Slide)
const COLOR_BLOCK: Color = Color(0.95, 0.25, 0.30)    # Crimson/Red (Dodge)
const COLOR_CURB: Color = Color(0.35, 0.38, 0.44)

# Collectible Colors
const COLOR_FIST: Color = Color(1.0, 0.22, 0.28)     # Red Sphere (People +5)
const COLOR_CROWN: Color = Color(0.25, 0.65, 1.0)    # Blue Cube (Govt +5)

# Preloaded Scripts
const DecisionGateScript = preload("res://scripts/world/DecisionGate.gd")
const CollectibleScript = preload("res://scripts/world/Collectible.gd")

enum ObstacleType {
	NONE,
	LOW_HURDLE,  # Jump over
	HIGH_ARCH,   # Slide under
	SOLID_BLOCK  # Switch lanes
}

# --- Exported Properties ---
@export var player_node: CharacterBody3D

# --- Internal Pool & Tracking ---
var active_chunks: Array[Node3D] = []
var chunk_pool: Array[Node3D] = []
var next_spawn_z: float = 0.0
var chunks_spawned_count: int = 0
var distance_since_last_gate: float = 0.0

# Cached Shared Materials for performance
var road_material: StandardMaterial3D
var lane_marker_material: StandardMaterial3D
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

	_spawn_initial_tracks()


func _process(_delta: float) -> void:
	if not player_node:
		return

	var player_z: float = player_node.global_position.z

	# Spawn new chunks ahead of player as they advance along -Z
	while next_spawn_z > player_z - (MAX_ACTIVE_CHUNKS * CHUNK_LENGTH):
		_spawn_next_chunk()

	# Recycle / Free chunks that are safely behind the player
	if active_chunks.size() > 0:
		var oldest_chunk: Node3D = active_chunks[0]
		if oldest_chunk.position.z - CHUNK_LENGTH > player_z + 10.0:
			_recycle_chunk(oldest_chunk)
			active_chunks.remove_at(0)


## Initializes shared materials with low-poly stylized shading.
func _init_materials() -> void:
	road_material = StandardMaterial3D.new()
	road_material.albedo_color = COLOR_ROAD
	road_material.roughness = 0.85

	lane_marker_material = StandardMaterial3D.new()
	lane_marker_material.albedo_color = COLOR_LANE_MARKER
	lane_marker_material.emission_enabled = true
	lane_marker_material.emission = COLOR_LANE_MARKER * 0.4
	lane_marker_material.roughness = 0.3

	curb_material = StandardMaterial3D.new()
	curb_material.albedo_color = COLOR_CURB
	curb_material.roughness = 0.6

	hurdle_material = StandardMaterial3D.new()
	hurdle_material.albedo_color = COLOR_HURDLE
	hurdle_material.emission_enabled = true
	hurdle_material.emission = COLOR_HURDLE * 0.6

	arch_material = StandardMaterial3D.new()
	arch_material.albedo_color = COLOR_ARCH
	arch_material.emission_enabled = true
	arch_material.emission = COLOR_ARCH * 0.6

	block_material = StandardMaterial3D.new()
	block_material.albedo_color = COLOR_BLOCK
	block_material.emission_enabled = true
	block_material.emission = COLOR_BLOCK * 0.5

	# Collectible Materials
	fist_material = StandardMaterial3D.new()
	fist_material.albedo_color = COLOR_FIST
	fist_material.emission_enabled = true
	fist_material.emission = COLOR_FIST
	fist_material.emission_energy_multiplier = 1.2
	fist_material.roughness = 0.2

	crown_material = StandardMaterial3D.new()
	crown_material.albedo_color = COLOR_CROWN
	crown_material.emission_enabled = true
	crown_material.emission = COLOR_CROWN
	crown_material.emission_energy_multiplier = 1.2
	crown_material.roughness = 0.2


## Spawns the starting sequence of track chunks.
func _spawn_initial_tracks() -> void:
	next_spawn_z = 15.0
	distance_since_last_gate = 0.0

	for i in range(MAX_ACTIVE_CHUNKS):
		var allow_content: bool = (chunks_spawned_count >= 2)
		_spawn_chunk_at(next_spawn_z, allow_content, false)
		next_spawn_z -= CHUNK_LENGTH


## Spawns the next chunk ahead along -Z, checking for Decision Gate interval (every 300m).
func _spawn_next_chunk() -> void:
	var allow_content: bool = (chunks_spawned_count >= 2)
	distance_since_last_gate += CHUNK_LENGTH

	var is_decision_chunk: bool = false
	if distance_since_last_gate >= DECISION_GATE_INTERVAL:
		is_decision_chunk = true
		distance_since_last_gate = 0.0

	_spawn_chunk_at(next_spawn_z, allow_content, is_decision_chunk)
	next_spawn_z -= CHUNK_LENGTH


## Retrieves a pooled chunk or builds a new one, then populates obstacles or Decision Gate.
func _spawn_chunk_at(z_pos: float, allow_content: bool, is_decision_chunk: bool) -> void:
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

	if is_decision_chunk:
		_spawn_decision_gate(chunk)
	elif allow_content:
		_populate_chunk_obstacles(chunk)
		_populate_chunk_collectibles(chunk)


## Instantiates a Decision Gate at the center of the specified chunk.
func _spawn_decision_gate(chunk: Node3D) -> void:
	var container: Node3D = chunk.get_node("DynamicElements")
	var gate: Node3D = DecisionGateScript.new()
	gate.position = Vector3(0.0, 0.0, -CHUNK_LENGTH * 0.5)
	container.add_child(gate)


## Recycles an old chunk by clearing dynamic content and returning to pool.
func _recycle_chunk(chunk: Node3D) -> void:
	var dynamic_container: Node3D = chunk.get_node_or_null("DynamicElements")
	if dynamic_container:
		for child in dynamic_container.get_children():
			child.queue_free()

	chunk.visible = false
	chunk_pool.append(chunk)


## Constructs the base track chunk geometry using Primitive / Static meshes.
func _create_track_chunk() -> Node3D:
	var chunk: Node3D = Node3D.new()
	chunk.name = "TrackChunk"

	# Road StaticBody3D for physics collision
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "RoadBody"
	chunk.add_child(static_body)

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(ROAD_WIDTH, ROAD_THICKNESS, CHUNK_LENGTH)
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0.0, -ROAD_THICKNESS * 0.5, -CHUNK_LENGTH * 0.5)
	static_body.add_child(collision_shape)

	# Road Visual Mesh
	var road_mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var road_box: BoxMesh = BoxMesh.new()
	road_box.size = Vector3(ROAD_WIDTH, ROAD_THICKNESS, CHUNK_LENGTH)
	road_box.material = road_material
	road_mesh_inst.mesh = road_box
	road_mesh_inst.position = Vector3(0.0, -ROAD_THICKNESS * 0.5, -CHUNK_LENGTH * 0.5)
	chunk.add_child(road_mesh_inst)

	# Curbs
	for side in [-1.0, 1.0]:
		var curb_inst: MeshInstance3D = MeshInstance3D.new()
		var curb_mesh: BoxMesh = BoxMesh.new()
		curb_mesh.size = Vector3(0.4, 0.4, CHUNK_LENGTH)
		curb_mesh.material = curb_material
		curb_inst.mesh = curb_mesh
		curb_inst.position = Vector3(side * (ROAD_WIDTH * 0.5 - 0.2), 0.1, -CHUNK_LENGTH * 0.5)
		chunk.add_child(curb_inst)

	# 3 Distinct Lane Lines
	for div_x in [-1.25, 1.25]:
		for d in range(5):
			var dash_inst: MeshInstance3D = MeshInstance3D.new()
			var dash_mesh: BoxMesh = BoxMesh.new()
			dash_mesh.size = Vector3(0.12, 0.02, 3.0)
			dash_mesh.material = lane_marker_material
			dash_inst.mesh = dash_mesh
			dash_inst.position = Vector3(div_x, 0.01, -(d * 6.0 + 3.0))
			chunk.add_child(dash_inst)

	# Lane Runway Dots
	for lane_x in LANES:
		for p in range(3):
			var dot_inst: MeshInstance3D = MeshInstance3D.new()
			var dot_mesh: BoxMesh = BoxMesh.new()
			dot_mesh.size = Vector3(0.3, 0.02, 0.3)
			dot_mesh.material = lane_marker_material
			dot_inst.mesh = dot_mesh
			dot_inst.position = Vector3(lane_x, 0.01, -(p * 10.0 + 5.0))
			chunk.add_child(dot_inst)

	# Dynamic Elements Container (Obstacles, Collectibles, Decision Gates)
	var dynamic_container: Node3D = Node3D.new()
	dynamic_container.name = "DynamicElements"
	chunk.add_child(dynamic_container)

	return chunk


## Procedurally places obstacles on a chunk (guaranteeing >= 1 navigable lane).
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


## Procedurally places floating collectible power tokens on open lanes.
func _populate_chunk_collectibles(chunk: Node3D) -> void:
	var container: Node3D = chunk.get_node("DynamicElements")
	# Check lanes at intermediate Z positions
	var collectible_z_positions: Array[float] = [-5.0, -16.0, -27.0]

	for z_pos in collectible_z_positions:
		# 60% spawn chance per zone
		if randf() > 0.60:
			continue

		var lane_x: float = LANES.pick_random()
		var is_fist: bool = randf() < 0.50
		var token: Area3D = _create_collectible(
			CollectibleScript.CollectibleType.PEOPLE_FIST if is_fist else CollectibleScript.CollectibleType.GOVT_CROWN
		)
		token.position = Vector3(lane_x, 0.9, z_pos)
		container.add_child(token)


## Helper: Generates a 3D collectible token instance.
## People Fist: Red Mesh Sphere | Govt Crown: Blue Mesh Cube.
func _create_collectible(type: int) -> Area3D:
	var token: Area3D = CollectibleScript.new()
	token.set("type", type)

	var col: CollisionShape3D = CollisionShape3D.new()
	var sphere_shape: SphereShape3D = SphereShape3D.new()
	sphere_shape.radius = 0.5
	col.shape = sphere_shape
	token.add_child(col)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()

	if type == CollectibleScript.CollectibleType.PEOPLE_FIST:
		# Red Mesh Sphere (People Fist)
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.35
		sphere.height = 0.7
		sphere.material = fist_material
		mesh_inst.mesh = sphere
	else:
		# Blue Mesh Cube (Govt Crown)
		var cube: BoxMesh = BoxMesh.new()
		cube.size = Vector3(0.6, 0.6, 0.6)
		cube.material = crown_material
		mesh_inst.mesh = cube

	token.add_child(mesh_inst)
	return token


## Instantiates one of the 3 obstacle archetypes.
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
			box.size = Vector3(2.2, 2.6, 1.4)
			col.shape = box
			col.position = Vector3(0.0, 1.3, 0.0)
			obstacle_root.add_child(col)

			var block_mesh: MeshInstance3D = MeshInstance3D.new()
			var block: BoxMesh = BoxMesh.new()
			block.size = Vector3(2.2, 2.6, 1.4)
			block.material = block_material
			block_mesh.mesh = block
			block_mesh.position = Vector3(0.0, 1.3, 0.0)
			obstacle_root.add_child(block_mesh)

			var trim_mesh: MeshInstance3D = MeshInstance3D.new()
			var trim: BoxMesh = BoxMesh.new()
			trim.size = Vector3(2.24, 0.3, 1.44)
			trim.material = lane_marker_material
			trim_mesh.mesh = trim
			trim_mesh.position = Vector3(0.0, 1.3, 0.0)
			obstacle_root.add_child(trim_mesh)

	return obstacle_root
