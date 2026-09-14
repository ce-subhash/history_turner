## TrackManager.gd
## Procedural 3D endless runner track spawner.
## Manages chunk pooling, road mesh generation (gray road + 3 lane markers),
## and procedural placement of 3 obstacle types: Low Hurdle, High Arch, and Solid Block.
extends Node3D
class_name TrackManager

# --- Configuration Constants ---
const CHUNK_LENGTH: float = 30.0
const ROAD_WIDTH: float = 10.0
const ROAD_THICKNESS: float = 0.2
const MAX_ACTIVE_CHUNKS: int = 6
const LANES: Array[float] = [-2.5, 0.0, 2.5]

# Colors & Aesthetics (Low-Poly Cyber / Strategic runner palette)
const COLOR_ROAD: Color = Color(0.18, 0.20, 0.24)
const COLOR_LANE_MARKER: Color = Color(0.85, 0.90, 0.95, 0.8)
const COLOR_HURDLE: Color = Color(0.15, 0.75, 0.95)   # Cyan (Jump)
const COLOR_ARCH: Color = Color(0.95, 0.70, 0.10)     # Amber/Gold (Slide)
const COLOR_BLOCK: Color = Color(0.95, 0.25, 0.30)    # Crimson/Red (Dodge)
const COLOR_CURB: Color = Color(0.35, 0.38, 0.44)

# Obstacle Type Enum
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

# Cached Shared Materials for performance
var road_material: StandardMaterial3D
var lane_marker_material: StandardMaterial3D
var curb_material: StandardMaterial3D
var hurdle_material: StandardMaterial3D
var arch_material: StandardMaterial3D
var block_material: StandardMaterial3D


func _ready() -> void:
	_init_materials()

	# If player_node isn't assigned via inspector, try locating in scene tree
	if not player_node:
		player_node = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# Seed initial safe buffer zone then populate active chunks
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
		# If chunk is more than 1 chunk length behind player
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


## Spawns the starting sequence of track chunks.
func _spawn_initial_tracks() -> void:
	# Start slightly behind the player so they don't fall off the back
	next_spawn_z = 15.0

	for i in range(MAX_ACTIVE_CHUNKS):
		# First 2 chunks are safe runway zones without obstacles
		var allow_obstacles: bool = (chunks_spawned_count >= 2)
		_spawn_chunk_at(next_spawn_z, allow_obstacles)
		next_spawn_z -= CHUNK_LENGTH


## Spawns the next chunk ahead along -Z.
func _spawn_next_chunk() -> void:
	var allow_obstacles: bool = (chunks_spawned_count >= 2)
	_spawn_chunk_at(next_spawn_z, allow_obstacles)
	next_spawn_z -= CHUNK_LENGTH


## Retrieves a pooled chunk or builds a new one, then configures obstacles.
func _spawn_chunk_at(z_pos: float, allow_obstacles: bool) -> void:
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

	# Populate obstacles on this chunk
	_populate_chunk_obstacles(chunk, allow_obstacles)


## Recycles an old chunk by hiding it and returning to pool.
func _recycle_chunk(chunk: Node3D) -> void:
	# Clear obstacles from container
	var obstacles_container: Node3D = chunk.get_node_or_null("Obstacles")
	if obstacles_container:
		for child in obstacles_container.get_children():
			child.queue_free()

	chunk.visible = false
	chunk_pool.append(chunk)


## Constructs the base track chunk geometry using Primitive / Static meshes.
func _create_track_chunk() -> Node3D:
	var chunk: Node3D = Node3D.new()
	chunk.name = "TrackChunk"

	# 1. Road StaticBody3D for physics collision (floor support for player)
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "RoadBody"
	chunk.add_child(static_body)

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(ROAD_WIDTH, ROAD_THICKNESS, CHUNK_LENGTH)
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0.0, -ROAD_THICKNESS * 0.5, -CHUNK_LENGTH * 0.5)
	static_body.add_child(collision_shape)

	# 2. Road Visual Mesh (10 x 0.2 x 30 Gray Road Box)
	var road_mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var road_box: BoxMesh = BoxMesh.new()
	road_box.size = Vector3(ROAD_WIDTH, ROAD_THICKNESS, CHUNK_LENGTH)
	road_box.material = road_material
	road_mesh_inst.mesh = road_box
	road_mesh_inst.position = Vector3(0.0, -ROAD_THICKNESS * 0.5, -CHUNK_LENGTH * 0.5)
	chunk.add_child(road_mesh_inst)

	# 3. Curbs / Guardrails along Left and Right edges
	for side in [-1.0, 1.0]:
		var curb_inst: MeshInstance3D = MeshInstance3D.new()
		var curb_mesh: BoxMesh = BoxMesh.new()
		curb_mesh.size = Vector3(0.4, 0.4, CHUNK_LENGTH)
		curb_mesh.material = curb_material
		curb_inst.mesh = curb_mesh
		curb_inst.position = Vector3(side * (ROAD_WIDTH * 0.5 - 0.2), 0.1, -CHUNK_LENGTH * 0.5)
		chunk.add_child(curb_inst)

	# 4. 3 Distinct Lane Lines / Dividers
	# Lane divider stripes between lanes: X = -1.25 and X = 1.25
	for div_x in [-1.25, 1.25]:
		var num_dashes: int = 5
		var dash_len: float = 3.0
		var gap: float = 3.0
		for d in range(num_dashes):
			var dash_inst: MeshInstance3D = MeshInstance3D.new()
			var dash_mesh: BoxMesh = BoxMesh.new()
			dash_mesh.size = Vector3(0.12, 0.02, dash_len)
			dash_mesh.material = lane_marker_material
			dash_inst.mesh = dash_mesh
			var dash_z: float = - (d * (dash_len + gap) + dash_len * 0.5 + 1.5)
			dash_inst.position = Vector3(div_x, 0.01, dash_z)
			chunk.add_child(dash_inst)

	# 5. Lane center light pips (subtle futuristic runway dots along X = -2.5, 0.0, 2.5)
	for lane_x in LANES:
		for p in range(3):
			var dot_inst: MeshInstance3D = MeshInstance3D.new()
			var dot_mesh: BoxMesh = BoxMesh.new()
			dot_mesh.size = Vector3(0.3, 0.02, 0.3)
			dot_mesh.material = lane_marker_material
			dot_inst.mesh = dot_mesh
			dot_inst.position = Vector3(lane_x, 0.01, -(p * 10.0 + 5.0))
			chunk.add_child(dot_inst)

	# 6. Obstacles Container Node
	var obstacles_container: Node3D = Node3D.new()
	obstacles_container.name = "Obstacles"
	chunk.add_child(obstacles_container)

	return chunk


## Procedurally places obstacles on a chunk.
## Guarantees at least 1 lane is always open and navigable.
func _populate_chunk_obstacles(chunk: Node3D, allow_obstacles: bool) -> void:
	if not allow_obstacles:
		return

	var container: Node3D = chunk.get_node("Obstacles")

	# We place 1 or 2 obstacle gates per 30m chunk along Z
	var z_offsets: Array[float] = [-10.0, -22.0]

	for z_offset in z_offsets:
		# 75% chance to place obstacles at this Z gate
		if randf() > 0.85:
			continue

		# Randomize which lanes receive obstacles
		var lanes_shuffled: Array[float] = LANES.duplicate()
		lanes_shuffled.shuffle()

		# Number of blocked lanes: either 1 or 2 (NEVER 3, ensuring fair passage)
		var blocked_count: int = 1 if randf() < 0.65 else 2

		for i in range(blocked_count):
			var lane_x: float = lanes_shuffled[i]
			# Pick random obstacle type: Low Hurdle, High Arch, or Solid Block
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


## Instantiates one of the 3 obstacle archetypes with visual meshes & collision shapes.
func _create_obstacle(type: ObstacleType) -> Node3D:
	var obstacle_root: StaticBody3D = StaticBody3D.new()
	obstacle_root.add_to_group("obstacles")

	match type:
		ObstacleType.LOW_HURDLE:
			# Low Hurdle: Player must jump over it
			# Height: 0.65m, Width: 2.2m, Depth: 0.25m
			obstacle_root.name = "Obstacle_LowHurdle"

			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(2.2, 0.65, 0.25)
			col.shape = box
			col.position = Vector3(0.0, 0.325, 0.0)
			obstacle_root.add_child(col)

			# Visual Bar
			var bar_mesh: MeshInstance3D = MeshInstance3D.new()
			var bar: BoxMesh = BoxMesh.new()
			bar.size = Vector3(2.2, 0.25, 0.2)
			bar.material = hurdle_material
			bar_mesh.mesh = bar
			bar_mesh.position = Vector3(0.0, 0.5, 0.0)
			obstacle_root.add_child(bar_mesh)

			# Visual Stands
			for side in [-1.0, 1.0]:
				var stand_mesh: MeshInstance3D = MeshInstance3D.new()
				var stand: BoxMesh = BoxMesh.new()
				stand.size = Vector3(0.12, 0.65, 0.3)
				stand.material = curb_material
				stand_mesh.mesh = stand
				stand_mesh.position = Vector3(side * 1.0, 0.325, 0.0)
				obstacle_root.add_child(stand_mesh)

		ObstacleType.HIGH_ARCH:
			# High Arch: Crossbar starts at Y=1.15 to Y=2.3 (height 1.15m)
			# Clearance below is 1.15m.
			# Standing player (height 1.8m) crashes. Sliding player (height 0.9m) glides under.
			obstacle_root.name = "Obstacle_HighArch"

			# Crossbar Collider
			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(2.2, 1.0, 0.35)
			col.shape = box
			col.position = Vector3(0.0, 1.7, 0.0) # Covers Y from 1.2 to 2.2
			obstacle_root.add_child(col)

			# Crossbar Visual
			var bar_mesh: MeshInstance3D = MeshInstance3D.new()
			var bar: BoxMesh = BoxMesh.new()
			bar.size = Vector3(2.3, 0.6, 0.35)
			bar.material = arch_material
			bar_mesh.mesh = bar
			bar_mesh.position = Vector3(0.0, 1.8, 0.0)
			obstacle_root.add_child(bar_mesh)

			# Warning Stripe on Arch
			var stripe_mesh: MeshInstance3D = MeshInstance3D.new()
			var stripe: BoxMesh = BoxMesh.new()
			stripe.size = Vector3(2.0, 0.15, 0.37)
			stripe.material = lane_marker_material
			stripe_mesh.mesh = stripe
			stripe_mesh.position = Vector3(0.0, 1.55, 0.0)
			obstacle_root.add_child(stripe_mesh)

			# Side Pillar visual supports (non-blocking outside the lane clearance)
			for side in [-1.0, 1.0]:
				var pillar_mesh: MeshInstance3D = MeshInstance3D.new()
				var pillar: BoxMesh = BoxMesh.new()
				pillar.size = Vector3(0.15, 2.2, 0.3)
				pillar.material = curb_material
				pillar_mesh.mesh = pillar
				pillar_mesh.position = Vector3(side * 1.15, 1.1, 0.0)
				obstacle_root.add_child(pillar_mesh)

		ObstacleType.SOLID_BLOCK:
			# Solid Block: Impassable barrier (width 2.2, height 2.6, depth 1.4)
			# Player must change lane to avoid.
			obstacle_root.name = "Obstacle_SolidBlock"

			var col: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(2.2, 2.6, 1.4)
			col.shape = box
			col.position = Vector3(0.0, 1.3, 0.0)
			obstacle_root.add_child(col)

			# Primary Box Mesh
			var block_mesh: MeshInstance3D = MeshInstance3D.new()
			var block: BoxMesh = BoxMesh.new()
			block.size = Vector3(2.2, 2.6, 1.4)
			block.material = block_material
			block_mesh.mesh = block
			block_mesh.position = Vector3(0.0, 1.3, 0.0)
			obstacle_root.add_child(block_mesh)

			# Danger Warning Decal / Trim
			var trim_mesh: MeshInstance3D = MeshInstance3D.new()
			var trim: BoxMesh = BoxMesh.new()
			trim.size = Vector3(2.24, 0.3, 1.44)
			trim.material = lane_marker_material
			trim_mesh.mesh = trim
			trim_mesh.position = Vector3(0.0, 1.3, 0.0)
			obstacle_root.add_child(trim_mesh)

	return obstacle_root
