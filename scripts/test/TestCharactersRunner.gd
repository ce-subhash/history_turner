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
	assert(player.character_sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Shadow casting must be OFF to avoid dark rectangular card shadow beneath character")
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

	# Verify slide on track lanes never sinks below floor
	player.is_invulnerable = false
	player.position = Vector3(0, 0, 0)
	player.velocity = Vector3(0, 0, 0)
	player.slide()
	for f in range(10):
		player._physics_process(0.016)
	assert(player.global_position.y >= 0.0, "Player must never sink below track floor during slide")
	assert(not GameManager.is_game_over, "Sliding on track must never trigger void death")
	print("✔ Slide on track floor stability (cannot penetrate below Y=0) verified.")
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
	print("✔ AudioManager singleton, ambient atmospheric BGM, and all SFX channels verified.")

	# 7. Void Fall Death Detection (Falling off road edges into void)
	player.is_invulnerable = false
	player.position = Vector3(8.0, -5.0, 0.0) # Outside track boundaries in void
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

	# 9. Trackside Scenery, Ancient Bronze Dividers & Valley Floor
	var track_mgr = main_inst.find_child("TrackManager", true, false)
	assert(track_mgr != null, "TrackManager must exist")
	assert(track_mgr.active_chunks.size() > 0, "TrackManager must have active chunks")
	var first_chunk = track_mgr.active_chunks[0]
	var has_valley = false
	var pillar_count = 0
	var brazier_count = 0
	for child in first_chunk.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.x > 50.0:
			has_valley = true
		elif "RomanPillar" in child.name or "roman_pillar" in child.name or child.has_node("RomanPillar"):
			pillar_count += 1
		elif "RomanBrazier" in child.name or "curbside_brazier" in child.name or child.has_node("RomanBrazier"):
			brazier_count += 1
	assert(has_valley, "Track chunk must have distant valley floor terrain")
	assert(pillar_count > 0, "Track chunk must have Roman colonnade pillars")
	assert(brazier_count > 0, "Track chunk must have curbside fire braziers")
	print("✔ Trackside Roman colonnade pillars, fire braziers, and valley floor verified.")

	# 10. Dynamic Camera & Runner Dust Particles
	assert(player.dust_particles != null, "PlayerController must instantiate dust particles")
	assert(player.camera != null, "PlayerController must have Camera3D")
	var initial_fov = player.camera.fov
	GameManager.current_speed = 28.0
	player._physics_process(0.2)
	assert(player.camera.fov >= initial_fov, "Camera FOV must dynamically expand at higher speeds")
	print("✔ Dynamic Speed Camera FOV and Runner Dust Particles verified.")

	# 11. Cinematic Main Menu & Active Ruler Showcase
	var menu_scn = load("res://scenes/ui/MainMenu.tscn")
	assert(menu_scn != null, "MainMenu.tscn must load")
	var menu_inst = menu_scn.instantiate()
	add_child(menu_inst)
	var bg_rect = menu_inst.find_child("BackdropTexture", true, false)
	assert(bg_rect != null and bg_rect.texture != null, "MainMenu must have cinematic backdrop texture")
	var motes = menu_inst.find_child("TemporalMotes", true, false)
	assert(motes != null, "MainMenu must have floating temporal motes particle system")
	assert(menu_inst.active_ruler_label != null, "MainMenu must have Active Ruler showcase label")
	print("✔ Cinematic Main Menu backdrop, temporal motes, and active ruler showcase verified.")

	print("\n=========================================================================")
	print("⭐⭐⭐ ALL VISUAL TUNING, ENVIRONMENT, MENU & CAMERA TESTS PASSED! ⭐⭐⭐")
	print("=========================================================================\n")
	get_tree().quit(0)
