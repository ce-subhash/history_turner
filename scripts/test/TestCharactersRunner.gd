extends Node

const CAESAR_RES = preload("res://resources/characters/caesar.tres")
const JOAN_RES = preload("res://resources/characters/joan.tres")
const HARRIET_RES = preload("res://resources/characters/harriet.tres")

func _ready() -> void:
	print("--- Running Automated In-Engine 3D Character Tests ---")
	var main_scn = load("res://scenes/Main.tscn")
	assert(main_scn != null, "Main.tscn must load")
	var main_inst = main_scn.instantiate()
	add_child(main_inst)

	var player = main_inst.find_child("Player", true, false)
	assert(player != null, "Player must exist in Main.tscn")

	# 1. Julius Caesar
	CharacterManager.select_character(CAESAR_RES)
	assert(player.current_model_root != null, "Caesar model root must be instantiated")
	assert(player.cape_node != null, "Caesar must have cape node")
	assert(player.left_arm_node != null and player.right_arm_node != null, "Caesar arms must be bound")
	assert(player.left_leg_node != null and player.right_leg_node != null, "Caesar legs must be bound")
	print("✔ Julius Caesar 3D model & rig verified.")

	# Run stride test
	for i in range(15):
		player._update_procedural_animations(0.016)
	assert(player.cape_node.rotation.x != 0.0, "Cape must flutter during run")
	print("✔ Caesar running stride & cape flutter verified.")

	# 2. Joan of Arc
	CharacterManager.select_character(JOAN_RES)
	assert(player.current_model_root != null, "Joan model root must be instantiated")
	assert(player.cape_node != null, "Joan must have royal cape node")
	print("✔ Joan of Arc 3D model & rig verified.")

	# 3. Harriet Tubman
	CharacterManager.select_character(HARRIET_RES)
	assert(player.current_model_root != null, "Harriet model root must be instantiated")
	assert(player.lantern_light != null, "Harriet must have active Freedom Lantern light")
	assert(player.lantern_light.light_energy > 2.0, "Freedom Lantern must have rich emissive energy")
	print("✔ Harriet Tubman 3D model, attire & Freedom Lantern light verified.")

	# 4. Jump & Slide Poses
	player.velocity.y = 10.0
	player._update_procedural_animations(0.05)
	assert(player.left_leg_node.rotation.x < 0.0, "Legs must tuck up during jump")
	print("✔ Jump tuck pose verified.")

	player.velocity.y = 0.0
	player.slide()
	player._update_procedural_animations(0.05)
	assert(player.left_leg_node.rotation.x > 0.5, "Legs must extend forward in slide")
	print("✔ Slide crouch pose verified.")
	player._end_slide()

	print("\n=== ALL IN-ENGINE 3D CHARACTER TESTS PASSED! ===")
	get_tree().quit(0)
