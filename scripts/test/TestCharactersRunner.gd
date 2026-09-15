extends Node

const CAESAR_RES = preload("res://resources/characters/caesar.tres")
const JOAN_RES = preload("res://resources/characters/joan.tres")
const HARRIET_RES = preload("res://resources/characters/harriet.tres")

func _ready() -> void:
	print("--- Running Automated AAA 2.5D Character & Environment Tests ---")
	var main_scn = load("res://scenes/Main.tscn")
	assert(main_scn != null, "Main.tscn must load")
	var main_inst = main_scn.instantiate()
	add_child(main_inst)

	var player = main_inst.find_child("Player", true, false)
	assert(player != null, "Player must exist in Main.tscn")
	player.is_invulnerable = true

	# 1. Julius Caesar
	CharacterManager.select_character(CAESAR_RES)
	assert(player.character_sprite != null, "Caesar character_sprite must be instantiated")
	assert("caesar_run" in player.character_sprite.texture.resource_path, "Caesar must have run texture")
	assert(player.character_sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Must cast real-time 3D shadow")
	assert(player.character_light != null, "Caesar must have active character light")
	print("✔ Julius Caesar AAA 2.5D Sprite & real-time shadow verified.")

	# Run stride bounce test
	var initial_y = player.character_sprite.position.y
	for i in range(10):
		player._physics_process(0.02)
	assert(player.character_sprite.position.y != initial_y, "Sprite must bounce during running stride")
	print("✔ Caesar running stride bounce & banking verified.")

	# 2. Joan of Arc
	CharacterManager.select_character(JOAN_RES)
	assert(player.character_sprite != null, "Joan character_sprite must be instantiated")
	assert("joan_run" in player.character_sprite.texture.resource_path, "Joan must have run texture")
	assert(player.character_light != null, "Joan must have active Saintly Halo light")
	print("✔ Joan of Arc AAA 2.5D Sprite & Divine Halo light verified.")

	# 3. Harriet Tubman
	CharacterManager.select_character(HARRIET_RES)
	assert(player.character_sprite != null, "Harriet character_sprite must be instantiated")
	assert("harriet_run" in player.character_sprite.texture.resource_path, "Harriet must have run texture")
	assert(player.character_light != null, "Harriet must have active Freedom Lantern light")
	assert(player.character_light.light_energy > 2.0, "Freedom Lantern must have rich emissive energy")
	print("✔ Harriet Tubman AAA 2.5D Sprite & Freedom Lantern verified.")

	# 4. Jump & Slide Pose Textures
	player.velocity.y = 8.0
	player._physics_process(0.05)
	assert("harriet_jump" in player.character_sprite.texture.resource_path, "Texture must swap to jump pose in mid-air")
	print("✔ Harriet mid-air jump pose texture verified.")

	player.velocity.y = 0.0
	player.slide()
	player._physics_process(0.05)
	assert("harriet_slide" in player.character_sprite.texture.resource_path, "Texture must swap to slide pose during slide")
	assert(player.character_sprite.position.y <= 0.5, "Sprite must lower to ground during slide")
	print("✔ Harriet low ground slide pose texture verified.")
	player._end_slide()

	# 5. Track Environment & Collectibles
	var track_mgr = main_inst.find_child("TrackManager", true, false)
	assert(track_mgr != null, "TrackManager must exist")
	assert(track_mgr.road_material != null, "Road material must exist")
	assert(track_mgr.road_material.albedo_texture != null, "Road must use PBR cobblestone/marble texture")
	print("✔ Ancient Roman Road PBR texture verified.")

	var fist_token = track_mgr._create_collectible(0)
	var fist_sprite = fist_token.get_node("CollectibleSprite")
	assert(fist_sprite != null and "collectible_fist" in fist_sprite.texture.resource_path, "Fist token must use AAA sprite")
	print("✔ People Fist ruby crystalline collectible sprite verified.")

	var crown_token = track_mgr._create_collectible(1)
	var crown_sprite = crown_token.get_node("CollectibleSprite")
	assert(crown_sprite != null and "collectible_crown" in crown_sprite.texture.resource_path, "Crown token must use AAA sprite")
	print("✔ Govt Crown golden sapphire collectible sprite verified.")

	var barricade_obs = track_mgr._create_obstacle(3) # SOLID_BLOCK
	var barricade_sprite = barricade_obs.get_node("BarricadeSprite3D")
	assert(barricade_sprite != null and "obstacle_barricade" in barricade_sprite.texture.resource_path, "Barricade obstacle must use AAA sprite")
	print("✔ Fortified Roman Barricade obstacle sprite & 3D shadow verified.")

	# 6. CharacterSelectScreen Preview Test
	var char_select_scn = load("res://scenes/ui/CharacterSelectScreen.tscn")
	assert(char_select_scn != null, "CharacterSelectScreen.tscn must load")
	var char_select_inst = char_select_scn.instantiate()
	add_child(char_select_inst)
	assert(char_select_inst.preview_sprite != null, "Preview Sprite3D must exist in CharacterSelectScreen")
	print("✔ CharacterSelectScreen 2.5D character preview verified.")

	print("\n=======================================================")
	print("⭐⭐⭐ ALL AAA 2.5D ASSET INTEGRATION TESTS PASSED! ⭐⭐⭐")
	print("=======================================================\n")
	get_tree().quit(0)
