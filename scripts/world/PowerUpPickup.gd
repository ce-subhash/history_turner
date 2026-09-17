## PowerUpPickup.gd
## Rare, high-impact in-run arcade power-up pickup item.
## Spawns along the track and grants game-changing temporary abilities:
## - MAGNET (🧲): Vacuums all tokens across all 3 lanes for 8.0s
## - SHIELD (🛡️): Grants 1-hit collision absorption with glass shatter & recovery
## - BOOST (⚡): 5.0s super-speed invincibility rush auto-smashing obstacles
extends Area3D
class_name PowerUpPickup

enum PowerUpType {
	MAGNET,
	SHIELD,
	BOOST
}

@export var powerup_type: PowerUpType = PowerUpType.MAGNET

var is_collected: bool = false
var base_y: float = 1.0
var time_accum: float = 0.0

var icon_label: Label3D
var ring_mesh: MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	base_y = position.y
	_build_visuals()


func _build_visuals() -> void:
	# Collision Sphere
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.75
	col.shape = sphere
	add_child(col)

	# Rotating Halo Ring
	ring_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.60
	torus.rings = 20
	torus.ring_segments = 12
	ring_mesh.mesh = torus

	var ring_mat = StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission_energy_multiplier = 2.2

	var omni = OmniLight3D.new()
	omni.omni_range = 4.5
	omni.omni_attenuation = 1.2
	add_child(omni)

	# 3D Icon & Text
	icon_label = Label3D.new()
	icon_label.font_size = 46
	icon_label.outline_size = 8
	icon_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	icon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon_label.position = Vector3(0.0, 0.25, 0.0)
	add_child(icon_label)

	var title_label = Label3D.new()
	title_label.font_size = 22
	title_label.outline_size = 6
	title_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title_label.position = Vector3(0.0, 0.9, 0.0)
	add_child(title_label)

	match powerup_type:
		PowerUpType.MAGNET:
			ring_mat.albedo_color = Color(0.2, 0.7, 1.0, 0.7)
			ring_mat.emission = Color(0.2, 0.8, 1.0)
			omni.light_color = Color(0.2, 0.75, 1.0)
			icon_label.text = "🧲"
			title_label.text = "MAGNET"
			title_label.modulate = Color(0.4, 0.9, 1.0)

		PowerUpType.SHIELD:
			ring_mat.albedo_color = Color(0.2, 1.0, 0.5, 0.7)
			ring_mat.emission = Color(0.2, 1.0, 0.45)
			omni.light_color = Color(0.3, 1.0, 0.5)
			icon_label.text = "🛡️"
			title_label.text = "AEGIS SHIELD"
			title_label.modulate = Color(0.4, 1.0, 0.6)

		PowerUpType.BOOST:
			ring_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.8)
			ring_mat.emission = Color(1.0, 0.8, 0.2)
			omni.light_color = Color(1.0, 0.85, 0.3)
			icon_label.text = "⚡"
			title_label.text = "IMPERIAL DASH"
			title_label.modulate = Color(1.0, 0.9, 0.3)

	ring_mesh.material_override = ring_mat
	add_child(ring_mesh)


func _process(delta: float) -> void:
	if is_collected:
		return

	time_accum += delta * 3.2
	position.y = base_y + sin(time_accum) * 0.18

	if ring_mesh:
		ring_mesh.rotate_y(delta * 2.8)
		ring_mesh.rotate_x(delta * 1.2)


func _on_body_entered(body: Node3D) -> void:
	if is_collected or not body.is_in_group("player"):
		return

	is_collected = true

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_powerup()

	# Activate Power-Up on Player
	match powerup_type:
		PowerUpType.MAGNET:
			if body.has_method("activate_in_run_magnet"):
				body.activate_in_run_magnet(8.0)
			if GameManager:
				GameManager.decision_notification.emit("🧲 ROYAL MAGNET: All Tokens Attracted! (8s)")

		PowerUpType.SHIELD:
			if body.has_method("activate_chrono_shield"):
				body.activate_chrono_shield()
			if GameManager:
				GameManager.decision_notification.emit("🛡️ CHRONO SHIELD: Protected from next crash!")

		PowerUpType.BOOST:
			if body.has_method("activate_chariot_boost"):
				body.activate_chariot_boost(5.0)
			if GameManager:
				GameManager.decision_notification.emit("⚡ IMPERIAL DASH: Unstoppable Force! (5s)")

	# Upward burst animation
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.8, 1.8, 1.8), 0.15)
	tween.parallel().tween_property(self, "position:y", position.y + 1.2, 0.15)
	tween.tween_callback(queue_free)
