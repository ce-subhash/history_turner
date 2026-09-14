## TemporalPortal.gd
## Full-width glowing 3D Chronos Rift portal spanning all 3 lanes.
## Triggers an Era Shift on player contact.
extends Area3D
class_name TemporalPortal

signal portal_entered()

var is_activated: bool = false
var portal_mesh: MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_portal_geometry()


func _build_portal_geometry() -> void:
	# Spans all 3 lanes (10m wide, 4.5m high)
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 5.0, 2.0)
	col.shape = box
	col.position = Vector3(0.0, 2.5, 0.0)
	add_child(col)

	# Glowing swirling rift portal mesh
	portal_mesh = MeshInstance3D.new()
	var quad: BoxMesh = BoxMesh.new()
	quad.size = Vector3(10.0, 4.8, 0.3)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.3, 1.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.4, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.roughness = 0.1
	portal_mesh.mesh = quad
	portal_mesh.material_override = mat
	portal_mesh.position = Vector3(0.0, 2.4, 0.0)
	add_child(portal_mesh)

	# Floating Title
	var label: Label3D = Label3D.new()
	label.text = "🌀 CHRONOS FRACTURE\nENTER TEMPORAL RIFT"
	label.font_size = 32
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0)
	label.modulate = Color(0.9, 0.6, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 5.2, 0.0)
	add_child(label)

	# Idle shimmer tween
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(portal_mesh, "scale", Vector3(1.02, 1.05, 1.0), 0.5)
	tween.tween_property(portal_mesh, "scale", Vector3.ONE, 0.5)


func _on_body_entered(body: Node3D) -> void:
	if is_activated or not body.is_in_group("player"):
		return

	is_activated = true
	portal_entered.emit()

	# Warp expansion effect before removal
	var tween: Tween = create_tween()
	tween.tween_property(portal_mesh, "scale", Vector3(2.0, 2.0, 2.0), 0.3)
	tween.parallel().tween_property(portal_mesh, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
