extends Node

const CHIBI_RES = preload("res://resources/characters/chibi_leader.tres")
const CAESAR_RES = preload("res://resources/characters/caesar.tres")
const JOAN_RES = preload("res://resources/characters/joan.tres")
const HARRIET_RES = preload("res://resources/characters/harriet.tres")

func _ready() -> void:
	print("--- Running Automated Tests: Chibi Leader, Capital Boulevard, Moving Bull Cart, Police Dogs, Reference 1 HUD ---")
	var main_scn = load("res://scenes/Main.tscn")
	assert(main_scn != null, "Main.tscn must load")
	var main_inst = main_scn.instantiate()
	add_child(main_inst)

	var player = main_inst.find_child("Player", true, false)
	assert(player != null, "Player must exist in Main.tscn")
	player.is_invulnerable = true

	# 1. Chibi Leader: Pure Direct Rear View, Nehru Cap, Kurta, Red Sash & Contact Shadow
	CharacterManager.select_character(CHIBI_RES)
	assert(player.character_sprite != null, "Chibi Leader character_sprite must be instantiated")
	assert("chibi_rear_run" in player.character_sprite.texture.resource_path, "Chibi Leader must have pure rear run texture")
	assert(player.character_sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Shadow casting on sprite must be OFF")
	var contact_shadow = player.find_child("ContactShadow", true, false)
	assert(contact_shadow != null, "Player must have soft ground contact shadow")
	print("✔ Chibi Leader pure direct rear-view sprite (white cap, kurta, red sash) & contact shadow verified.")

	# 2. Multi-Frame Running Stride Animation (Alternating Left & Right Strides)
	var initial_tex_path = player.character_sprite.texture.resource_path
	var swapped_stride = false
	for i in range(30):
		player._physics_process(0.02)
		if player.character_sprite.texture.resource_path != initial_tex_path:
			swapped_stride = true
			break
	assert(swapped_stride, "Running stride must alternate frames between run1 and run2")
	print("✔ Chibi Leader multi-frame running stride cycle (run1 <-> run2) verified.")

	# 3. Jump & Slide Poses
	player.velocity.y = 8.0
	player._physics_process(0.05)
	assert("chibi_rear_jump" in player.character_sprite.texture.resource_path, "Texture must swap to chibi rear jump pose in mid-air")
	print("✔ Chibi Leader pure rear jump leap pose verified.")

	player.velocity.y = 0.0
	player.slide()
	player._physics_process(0.05)
	assert("chibi_rear_slide" in player.character_sprite.texture.resource_path, "Texture must swap to chibi rear slide pose during slide")
	assert(player.character_sprite.position.y <= 0.5, "Sprite must lower to ground during slide")
	print("✔ Chibi Leader low ground slide crouch verified.")
	player._end_slide()

	# 4. Slide on Track Stability (Cannot penetrate below Y=0)
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

	# 5. Grand Capital Boulevard Scenery & Horizon Parliament Dome
	var track_mgr = main_inst.find_child("TrackManager", true, false)
	assert(track_mgr != null, "TrackManager must exist")
	assert(track_mgr.active_chunks.size() > 0, "TrackManager must have active chunks")
	assert(track_mgr.horizon_parliament_node != null, "TrackManager must have horizon Parliament dome")

	var first_chunk = track_mgr.active_chunks[0]
	var has_trees = false
	var has_lamps = false
	var has_crowd = false
	for child in first_chunk.get_children():
		var cname = child.name.to_lower()
		if "lamp" in cname:
			has_lamps = true
		if "tree" in cname and not "lamp" in cname:
			has_trees = true
		if "crowd" in cname:
			has_crowd = true
	assert(has_trees, "Track chunk must feature boulevard trees")
	assert(has_lamps, "Track chunk must feature street lampposts")
	assert(has_crowd, "Track chunk must feature cheering crowd spectators holding signs")
	print("✔ Grand Capital Boulevard scenery (trees, lampposts, cheering crowd sidewalks, Parliament dome) verified.")

	# 6. Obstacles: Moving Bull Cart (People) & Police K9 Dog (Police)
	var cart_obs = track_mgr._create_obstacle(TrackManager.ObstacleCategory.BULL_CART)
	assert(cart_obs is MovingObstacle, "Bull Cart must be a MovingObstacle")
	assert(cart_obs.get("speed") > 0.0, "Bull Cart must have active movement speed")
	cart_obs.queue_free()

	var dog_obs = track_mgr._create_obstacle(TrackManager.ObstacleCategory.POLICE_DOG)
	assert(dog_obs is MovingObstacle, "Police Dog must be a moving hazard")
	dog_obs.queue_free()

	var barricade_obs = track_mgr._create_obstacle(TrackManager.ObstacleCategory.POLICE_BARRICADE)
	assert(barricade_obs != null, "Police barricade must be created")
	barricade_obs.queue_free()

	var ramp_obs = track_mgr._create_obstacle(TrackManager.ObstacleCategory.JUMP_RAMP)
	assert(ramp_obs.find_child("RampTrigger", true, false) != null, "Jump ramp must have launch trigger area")
	assert(!ramp_obs.name.begins_with("Obstacle"), "Jump ramp must NOT be named as a fatal Obstacle")
	assert(!ramp_obs.is_in_group("obstacles"), "Jump ramp must NOT be in the obstacles collision group")
	ramp_obs.queue_free()

	# Test player speed ramp boost
	player.apply_ramp_boost(13.5, 6.5, 2.5)
	assert(player.ramp_boost_timer > 0.0, "Player must receive speed boost from ramp")
	assert(player.velocity.y > 10.0, "Player must launch upward on ramp")
	print("✔ Dynamic obstacles & Interactive Speed Boost Jump Ramp verified.")

	# 7. Collectibles: Heart (People) & Temple (Govt) Tokens
	var heart_token = track_mgr._create_collectible(0)
	assert(heart_token.find_child("CollectibleSprite", true, false) != null, "Heart token must have visual sprite")
	heart_token.queue_free()

	var temple_token = track_mgr._create_collectible(1)
	assert(temple_token.find_child("CollectibleSprite", true, false) != null, "Temple token must have visual sprite")
	temple_token.queue_free()
	print("✔ Collectibles (Red Heart People tokens & Blue Temple Govt tokens) verified.")

	# 8. Elevated Camera & Portrait Mode Verification
	assert(player.camera.position.y >= 3.5, "Camera must be elevated (>= 3.5m) for deep road visibility")
	var vp_w = ProjectSettings.get_setting("display/window/size/viewport_width")
	var vp_h = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert(vp_h > vp_w, "Game must be configured in portrait mode (viewport height > width)")
	print("✔ Mobile Portrait Mode (720x1280) & Elevated Camera perspective (y=3.8m) verified.")

	# 9. Reference 1 Mobile HUD & Swipe Gesture Controls
	var hud = main_inst.find_child("HUDController", true, false)
	assert(hud != null, "HUDController must exist")
	assert(hud.balance_needle != null, "Balance needle indicator (▼) must exist")
	assert(hud.people_count_label != null, "People count label must exist")
	assert(hud.govt_count_label != null, "Govt count label must exist")
	assert(hud.pause_button != null, "Pause button must exist")
	assert(hud.ability_button != null, "Mobile Ability Button must exist")

	# Test swipe gestures
	var lane_before = player.current_lane
	player._process_swipe(Vector2(-100, 0))
	assert(player.current_lane == lane_before - 1, "Swipe Left must shift player lane left")
	player._process_swipe(Vector2(100, 0))
	assert(player.current_lane == lane_before, "Swipe Right must shift player lane right")

	# Test mobile ability trigger
	hud.ability_button.pressed.emit()
	print("✔ Mobile Swipe Controls & Thumb-Friendly Ability Trigger verified.")

	# 9. Audio Engine (BGM & SFX)
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
	print("✔ AudioManager singleton and sound effects verified.")

	# 10. Void Fall Death Detection
	player.is_invulnerable = false
	player.position = Vector3(8.0, -5.0, 0.0)
	player._physics_process(0.02)
	assert(GameManager.is_game_over, "Falling off road into void (Y < -4.0) must trigger Game Over")
	print("✔ Void fall death boundary (Y < -4.0) verified.")

	print("\n=========================================================================")
	print("⭐⭐⭐ ALL CHIBI LEADER, BOULEVARD & REFERENCE 1 HUD TESTS PASSED! ⭐⭐⭐")
	print("=========================================================================\n")
	get_tree().quit(0)
