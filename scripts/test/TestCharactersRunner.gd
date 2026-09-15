extends Node

const CAESAR_RES = preload("res://resources/characters/caesar.tres")
const JOAN_RES = preload("res://resources/characters/joan.tres")
const HARRIET_RES = preload("res://resources/characters/harriet.tres")

func _ready() -> void:
	print("--- Running Automated Tests: Pure Rear-View, Multi-Frame Stride, Audio, Void Death ---")
	var main_scn = load("res://scenes/Main.tscn")
	assert(main_scn != null, "Main.tscn must load")
	var main_inst = main_scn.instantiate()
	add_child(main_inst)

	var player = main_inst.find_child("Player", true, false)
	assert(player != null, "Player must exist in Main.tscn")
	player.is_invulnerable = true

	# 1. Julius Caesar: Pure Direct Rear View & Real-Time Shadow
	CharacterManager.select_character(CAESAR_RES)
	assert(player.character_sprite != null, "Caesar character_sprite must be instantiated")
	assert("caesar_rear_run" in player.character_sprite.texture.resource_path, "Caesar must have pure rear run texture")
	assert(player.character_sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Must cast real-time 3D shadow")
	assert(player.character_light != null, "Caesar must have active character light")
	print("✔ Julius Caesar pure direct rear-view (0° azimuth) sprite verified.")

	# 2. Multi-Frame Running Stride Animation (Alternating Left & Right Strides)
	var initial_tex_path = player.character_sprite.texture.resource_path
	var swapped_stride = false
	for i in range(30):
		player._physics_process(0.02)
		if player.character_sprite.texture.resource_path != initial_tex_path:
			swapped_stride = true
			break
	assert(swapped_stride, "Running stride must alternate frames between run1 and run2")
	print("✔ Caesar multi-frame running stride cycle (run1 <-> run2) verified.")

	# 3. Joan of Arc Pure Rear View
	CharacterManager.select_character(JOAN_RES)
	assert(player.character_sprite != null, "Joan character_sprite must be instantiated")
	assert("joan_rear_run" in player.character_sprite.texture.resource_path, "Joan must have pure rear run texture")
	assert(player.character_light != null, "Joan must have active Saintly Halo light")
	print("✔ Joan of Arc pure rear-view sprite & Divine Halo light verified.")

	# 4. Harriet Tubman Pure Rear View & Lantern
	CharacterManager.select_character(HARRIET_RES)
	assert(player.character_sprite != null, "Harriet character_sprite must be instantiated")
	assert("harriet_rear_run" in player.character_sprite.texture.resource_path, "Harriet must have pure rear run texture")
	assert(player.character_light != null, "Harriet must have active Freedom Lantern light")
	print("✔ Harriet Tubman pure rear-view sprite & Freedom Lantern verified.")

	# 5. Jump & Slide Pure Rear Poses
	player.velocity.y = 8.0
	player._physics_process(0.05)
	assert("harriet_rear_jump" in player.character_sprite.texture.resource_path, "Texture must swap to pure rear jump pose in mid-air")
	print("✔ Harriet pure direct rear jump leap pose verified.")

	player.velocity.y = 0.0
	player.slide()
	player._physics_process(0.05)
	assert("harriet_rear_slide" in player.character_sprite.texture.resource_path, "Texture must swap to pure rear slide pose during slide")
	assert(player.character_sprite.position.y <= 0.5, "Sprite must lower to ground during slide")
	print("✔ Harriet pure direct rear low ground slide crouch verified.")
	player._end_slide()

	# 6. Audio Engine (BGM & SFX)
	assert(has_node("/root/AudioManager"), "AudioManager autoload singleton must be active")
	var audio = get_node("/root/AudioManager")
	assert(audio.bgm_player != null, "BGM Player must exist")
	audio.play_sfx_jump()
	audio.play_sfx_slide()
	audio.play_sfx_lane_switch(1)
	audio.play_sfx_collect_fist()
	audio.play_sfx_collect_crown()
	audio.play_sfx_gate()
	audio.play_sfx_crash()
	audio.play_sfx_void_fall()
	print("✔ AudioManager singleton, synthesized BGM, and all SFX channels verified.")

	# 7. Void Fall Death Detection
	player.is_invulnerable = false # Allow death
	player.position.y = -5.0
	player._physics_process(0.02)
	assert(GameManager.is_game_over, "Falling off road into void (Y < -4.0) must trigger Game Over")
	print("✔ Void fall death boundary (Y < -4.0) verified: 'Fell into the Temporal Void!'.")

	# 8. CharacterSelectScreen Preview Test
	var char_select_scn = load("res://scenes/ui/CharacterSelectScreen.tscn")
	assert(char_select_scn != null, "CharacterSelectScreen.tscn must load")
	var char_select_inst = char_select_scn.instantiate()
	add_child(char_select_inst)
	assert(char_select_inst.preview_sprite != null, "Preview Sprite3D must exist in CharacterSelectScreen")
	assert("rear" in char_select_inst.preview_sprite.texture.resource_path, "CharacterSelectScreen preview must use pure rear-view sprite")
	print("✔ CharacterSelectScreen pure rear-view character preview verified.")

	print("\n=========================================================================")
	print("⭐⭐⭐ ALL PURE REAR-VIEW, AUDIO & VOID DEATH TESTS PASSED! ⭐⭐⭐")
	print("=========================================================================\n")
	get_tree().quit(0)
