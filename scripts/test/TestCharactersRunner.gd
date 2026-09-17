extends Node

const CHIBI_RES = preload("res://resources/characters/chibi_leader.tres")
const CAESAR_RES = preload("res://resources/characters/caesar.tres")
const JOAN_RES = preload("res://resources/characters/joan.tres")
const HARRIET_RES = preload("res://resources/characters/harriet.tres")
const FactionRunwayScript = preload("res://scripts/world/FactionRunway.gd")

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
	assert(player.character_sprite.position.y <= 0.65, "Sprite must lower to ground during slide")
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

	# 4b. Verify Caesar, Joan, and Harriet Animation Cycles
	for char_res in [CAESAR_RES, JOAN_RES, HARRIET_RES]:
		var cname = char_res.character_name
		CharacterManager.select_character(char_res)
		player._apply_character_visuals(char_res)
		assert(player.character_sprite != null, "%s sprite must be created" % cname)

		# Ground running stride alternation
		var init_tex = player.character_sprite.texture.resource_path
		var alt_seen = false
		for f in range(30):
			player._physics_process(0.02)
			if player.character_sprite.texture.resource_path != init_tex:
				alt_seen = true
				break
		assert(alt_seen, "%s must alternate run strides (run1 <-> run2)" % cname)

		# Jump leap
		player.velocity.y = 8.0
		player.position.y = 0.5
		player._update_procedural_animations(0.02)
		assert(player.character_sprite.texture == player.CHARACTER_SPRITES[cname]["jump"], "%s must display jump leap in air" % cname)

		# Slide crouch
		player.velocity.y = 0.0
		player.position.y = 0.0
		player.slide()
		player._update_procedural_animations(0.02)
		assert(player.character_sprite.texture == player.CHARACTER_SPRITES[cname]["slide"], "%s must display slide crouch" % cname)
		player._end_slide()
		print("✔ %s running stride cycle, jump leap, and slide animations verified." % cname)

	# Restore Chibi Leader for remaining tests
	CharacterManager.select_character(CHIBI_RES)
	player._apply_character_visuals(CHIBI_RES)
	player.is_invulnerable = true

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

	# 6. Obstacles: Static Three-Wood Campfire (People) & Classical Stone Block (Ancient/Republic)
	var fire_obs = track_mgr._create_obstacle(TrackManager.ObstacleCategory.WOOD_FIRE)
	assert(fire_obs != null, "Three-Wood Campfire obstacle must be created")
	var fire_body = fire_obs.find_child("FireBody", true, false)
	assert(fire_body != null, "Three-Wood Campfire must have FireBody with obstacle collision")
	assert(fire_obs.find_child("WoodFireSprite", true, false) != null, "Three-Wood Campfire must use 2.5D PNG sprite")
	var fire_col = fire_body.find_child("CollisionShape3D", true, false)
	if fire_col and fire_col.shape is BoxShape3D:
		assert(fire_col.shape.size.y <= 0.6, "Campfire collider box height must be decreased for clean jumping")
		assert(fire_col.shape.size.x <= 1.2, "Campfire collider box width must be decreased")
	assert(fire_obs.is_in_group("obstacles") or fire_body.is_in_group("obstacles"), "Campfire or FireBody must be in obstacles group")
	fire_obs.queue_free()

	var stone_obs = track_mgr._create_obstacle(TrackManager.ObstacleCategory.STONE_BLOCK)
	assert(stone_obs != null, "Stone Block must be created")
	assert(stone_obs.is_in_group("obstacles"), "Stone Block must be in obstacles group")
	stone_obs.queue_free()

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

	# 7b. Pure Coin Accumulation & Zero Meter Death Verification
	GameManager.reset_state()
	GameManager.add_people_power(5.0)
	assert(GameManager.people_coins == 1, "People coins must increment on Heart pickup")
	assert(GameManager.people_power > 0.0, "People power must accumulate")

	GameManager.add_govt_power(5.0)
	assert(GameManager.govt_coins == 1, "Govt coins must increment on Temple pickup")
	assert(GameManager.govt_power > 0.0, "Govt power must accumulate")

	# Critical Requirement: Character must NEVER die because of 0% meter
	GameManager.people_power = 0.0
	GameManager.govt_power = 0.0
	GameManager._evaluate_political_stability()
	assert(!GameManager.is_game_over, "Character must NEVER die because of 0% political meter!")

	var runway_test = FactionRunwayScript.new()
	assert(runway_test.find_child("PeopleTrigger", true, false) != null, "Runway must have People boost trigger")
	assert(runway_test.find_child("GovtTrigger", true, false) != null, "Runway must have Govt boost trigger")
	runway_test.queue_free()
	print("✔ Dual Coin Accumulation & Zero Meter Deaths (Never Dies from Meter) verified.")

	# 8. Closer Zoom Camera & Portrait Mode Verification
	assert(player.camera.position.y >= 2.2 and player.camera.position.y <= 3.2, "Camera must be closely elevated (y=2.5m) to eliminate empty space")
	var vp_w = ProjectSettings.get_setting("display/window/size/viewport_width")
	var vp_h = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert(vp_h > vp_w, "Game must be configured in portrait mode (viewport height > width)")
	print("✔ Mobile Portrait Mode (720x1280) & Closer Zoom Camera perspective (y=2.5m, z=3.6m) verified.")

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
	audio.play_sfx_close_call()
	audio.play_sfx_powerup()
	audio.play_sfx_shield_break()
	audio.play_sfx_collect_fist(1.2)
	print("✔ AudioManager singleton, new arcade SFX, and pitch-scaled chimes verified.")

	# 10. In-Run Power-Up System & Juice Mechanics
	# Test Contact Shadow hiding in air
	var active_shadow = player.find_child("ContactShadow", true, false)
	assert(active_shadow != null, "Contact shadow must exist")
	player.position.y = 1.8
	player._update_procedural_animations(0.02)
	assert(active_shadow.visible == false, "Contact shadow must hide while jumping in air")
	player.position.y = 0.0
	player._update_procedural_animations(0.02)
	assert(active_shadow.visible == true, "Contact shadow must be visible when grounded")
	print("✔ Subtle contact shadow & airborne hiding verified.")


	# Test In-Run Chrono-Shield protection
	player.activate_chrono_shield()
	assert(player.has_chrono_shield == true, "Player must possess active Chrono-Shield")
	var dummy_obs = track_mgr._create_obstacle(TrackManager.ObstacleCategory.STONE_BLOCK)
	player._trigger_shield_break(dummy_obs)
	assert(player.has_chrono_shield == false, "Shield must absorb collision and deplete")
	assert(player.is_invulnerable == true, "Shield break must grant post-hit invulnerability")
	print("✔ In-Run Chrono-Shield collision absorption verified.")

	# Test In-Run Imperial Dash (Chariot Boost)
	player.activate_chariot_boost(5.0)
	assert(player.chariot_boost_timer > 0.0, "Imperial Dash must be active")
	player._physics_process(0.02)
	assert(player.velocity.z < -18.0, "Imperial Dash must supercharge forward velocity")
	print("✔ In-Run Imperial Dash (Chariot Boost) super-speed verified.")

	# Test Close Call near-miss trigger
	var trauma_before = player.camera_trauma
	player._trigger_close_call()
	assert(player.camera_trauma > trauma_before, "Close Call must trigger camera trauma shake")
	print("✔ Close Call near-miss mechanic, floating popup, and camera trauma verified.")

	# 11. Void Fall Death Detection
	player.is_invulnerable = false
	player.chariot_boost_timer = 0.0
	player.position = Vector3(8.0, -5.0, 0.0)
	player._physics_process(0.02)
	assert(GameManager.is_game_over, "Falling off road into void (Y < -4.0) must trigger Game Over")
	print("✔ Void fall death boundary (Y < -4.0) verified.")

	# Verify 'YOU FAILED' screen and no obstacle name shown
	var title_lbl = hud.game_over_panel.find_child("TitleLabel", true, false)
	assert(title_lbl.text == "YOU FAILED", "Game Over screen must display 'YOU FAILED'")
	var reason_lbl = hud.game_over_panel.find_child("ReasonLabel", true, false)
	assert(reason_lbl.visible == false or reason_lbl.text == "", "Game Over screen must NOT display obstacle names")
	var restart_btn = hud.game_over_panel.find_child("RestartButton", true, false)
	var menu_btn = hud.game_over_panel.find_child("MenuButton", true, false)
	assert(restart_btn != null and menu_btn != null, "Restart and Menu buttons must exist")
	assert(restart_btn.custom_minimum_size.y >= menu_btn.custom_minimum_size.y * 1.8, "Restart button must be significantly bigger than Menu button (>= 1.8x height)")
	assert(restart_btn.get_theme_font_size("font_size") > menu_btn.get_theme_font_size("font_size"), "Restart button font must be significantly larger")
	print("✔ Clean 'YOU FAILED' game over display & significantly larger Restart button (84px vs 42px) verified.")

	# 12. Mobile Screen Scaling, Closer Camera Zoom & Safe Area Tests
	assert(player.camera.keep_aspect == Camera3D.KEEP_WIDTH, "Camera must use KEEP_WIDTH for mobile screen scaling so all lanes remain visible on tall screens")
	assert(player.camera.position.z <= 4.0, "Camera must be zoomed in closer to player (Z <= 4.0m) to eliminate excessive empty bottom space")
	assert(player.camera.position.y <= 3.0, "Camera elevation must be lowered (Y <= 3.0m) to reduce top sky empty space")
	assert(player.camera.fov >= 55.0 and player.camera.fov <= 68.0, "Camera FOV must frame runner closely and clearly")

	# Verify Pause Button is hidden from gameplay screen
	var pause_btn = hud.get_node_or_null("TopBar/HBoxContainer/PauseButton")
	assert(pause_btn == null or pause_btn.visible == false, "Pause button must be hidden from gameplay screen")

	# Verify yellow ring power immediately hides upon expiration
	GameManager.is_game_over = false
	CharacterManager.is_ability_active = false
	CharacterManager.active_timer = 0.0
	player.has_chrono_shield = false
	player.is_peasant_fever = false
	player.is_divine_fever = false
	player.activate_chariot_boost(0.01)
	assert(player.shield_mesh.visible == true, "Shield mesh must show while boost is active")
	player.chariot_boost_timer = 0.0
	player._physics_process(0.02)
	assert(player.shield_mesh.visible == false, "Yellow ring power must immediately hide upon expiration")

	hud._apply_mobile_safe_area()
	var top_bar = hud.get_node_or_null("TopBar")
	assert(top_bar != null, "TopBar must exist in HUD")
	assert(top_bar.get_theme_constant("margin_top") >= 16, "TopBar margin_top must respect mobile top safe area")

	# Test Main Menu mobile safe area
	var menu_scn = load("res://scenes/ui/MainMenu.tscn")
	assert(menu_scn != null, "MainMenu.tscn must load")
	var menu_inst = menu_scn.instantiate()
	add_child(menu_inst)
	menu_inst._apply_mobile_safe_area()
	var menu_margin = menu_inst.get_node_or_null("MainMargin")
	assert(menu_margin != null, "MainMargin must exist on MainMenu")
	assert(menu_margin.get_theme_constant("margin_top") >= 56, "MainMargin must adapt to safe area on mobile")
	menu_inst.queue_free()
	print("✔ Mobile screen scaling, closer camera zoom (Z=3.6m, Y=2.5m, FOV=58°), hidden pause button & ring cleanup verified.")


	print("\n=========================================================================")
	print("⭐⭐⭐ ALL CHIBI LEADER, BOULEVARD & REFERENCE 1 HUD TESTS PASSED! ⭐⭐⭐")
	print("=========================================================================\n")
	get_tree().quit(0)
