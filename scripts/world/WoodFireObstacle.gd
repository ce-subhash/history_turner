## WoodFireObstacle.gd
## Stylized 2.5D three-wood tripod campfire obstacle.
## Matches the game's 2.5D sprite art style (Subway Surfers aesthetic).
## Features:
## - Crisp 2.5D PNG sprite of rustic 3-wood tripod campfire with leaping flames & stone hearth
## - Low, forgiving decreased collider box (easy, clean jump clearance)
## - Dynamic flickering firelight (OmniLight3D) & ambient ember sparks
extends Node3D
class_name WoodFireObstacle

const WOOD_FIRE_TEX = preload("res://assets/sprites/props/wood_fire.png")

var fire_light: OmniLight3D
var fire_sprite: Sprite3D
var _time: float = 0.0


func _init() -> void:
	name = "Obstacle_WoodFire"
	add_to_group("obstacles")
	_build_campfire_structure()


func _ready() -> void:
	pass


func _build_campfire_structure() -> void:
	if has_node("FireBody"):
		return

	# 1. Physics Body & Jump-Friendly Collision Box
	var body = StaticBody3D.new()
	body.name = "FireBody"
	body.add_to_group("obstacles")
	add_child(body)

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	# Safe collision box: 1.0m width, 0.52m height, 0.70m depth along track to prevent tunneling
	box.size = Vector3(1.0, 0.52, 0.70)
	col.shape = box
	col.position = Vector3(0.0, 0.26, 0.0)
	body.add_child(col)

	# 2. Stylized 2.5D Campfire PNG Sprite (Tilted to match -18 deg camera pitch)
	fire_sprite = Sprite3D.new()
	fire_sprite.name = "WoodFireSprite"
	fire_sprite.texture = WOOD_FIRE_TEX
	fire_sprite.centered = true
	fire_sprite.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	fire_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fire_sprite.pixel_size = 1.25 / 1024.0
	fire_sprite.position = Vector3(0.0, 0.52, 0.0)
	fire_sprite.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	fire_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	body.add_child(fire_sprite)

	# 3. Dynamic Flickering Campfire OmniLight3D
	fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.58, 0.18)
	fire_light.light_energy = 2.4
	fire_light.omni_range = 5.0
	fire_light.omni_attenuation = 1.3
	fire_light.position = Vector3(0.0, 0.45, 0.0)
	body.add_child(fire_light)

	# 4. Floating Ember Sparks (CPUParticles3D)
	var sparks = CPUParticles3D.new()
	sparks.amount = 8
	sparks.lifetime = 0.6
	sparks.preprocess = 0.2
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.20
	sparks.direction = Vector3(0.0, 1.0, 0.0)
	sparks.spread = 20.0
	sparks.gravity = Vector3(0.0, 0.6, 0.0)
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.0
	sparks.scale_amount_min = 0.03
	sparks.scale_amount_max = 0.06

	var spark_mat = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.68, 0.15)
	sparks.material_override = spark_mat
	sparks.position = Vector3(0.0, 0.30, 0.0)
	body.add_child(sparks)


func _process(delta: float) -> void:
	_time += delta

	# Flickering fire light effect
	if fire_light:
		fire_light.light_energy = 2.2 + sin(_time * 16.0) * 0.4 + cos(_time * 27.0) * 0.2
