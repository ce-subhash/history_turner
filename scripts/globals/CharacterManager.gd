## CharacterManager.gd
## Autoload Singleton managing the playable character roster,
## active character selection, ability cooldowns, and activation dispatch.
extends Node

# --- Preloaded Character Resource Class & Catalog ---
const CharacterDataScript = preload("res://scripts/resources/CharacterData.gd")
const CHIBI_RES = preload("res://resources/characters/chibi_leader.tres")
const CAESAR_RES = preload("res://resources/characters/caesar.tres")
const JOAN_RES = preload("res://resources/characters/joan.tres")
const HARRIET_RES = preload("res://resources/characters/harriet.tres")

# --- Signals ---
## Emitted when the active ability begins.
signal ability_activated(character: Resource, duration: float)

## Emitted when the active ability ends.
signal ability_deactivated(character: Resource)

## Emitted periodically as cooldown advances (for HUD radial / progress sweep).
signal cooldown_updated(time_remaining: float, max_cooldown: float)

## Emitted when a new ruler is selected.
signal character_selected(character: Resource)

# --- State Variables ---
## Currently active ruler driving the run.
var active_character: Resource

## Ability cooldown tracking (seconds remaining until next use).
var cooldown_timer: float = 0.0

## Active ability duration countdown (seconds remaining while active).
var active_timer: float = 0.0

## Flags whether the ability is currently active.
var is_ability_active: bool = false


func _ready() -> void:
	# Default to Chibi Leader on startup
	if not active_character:
		select_character(CHIBI_RES)

	if GameManager:
		GameManager.game_restarted.connect(_on_game_restarted)


func _process(delta: float) -> void:
	if GameManager.is_game_over:
		return

	# Handle Active Ability Countdown
	if is_ability_active:
		active_timer -= delta
		if active_timer <= 0.0:
			_deactivate_ability()

	# Handle Cooldown Countdown
	elif cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - delta)
		if active_character:
			cooldown_updated.emit(cooldown_timer, active_character.active_cooldown)


## Attempts to trigger the active ruler's ability.
func trigger_active_ability() -> bool:
	if GameManager.is_game_over or is_ability_active or cooldown_timer > 0.0 or not active_character:
		return false

	is_ability_active = true
	active_timer = active_character.active_duration
	cooldown_timer = active_character.active_cooldown

	print("[CharacterManager] Activated ability '%s' for %.1fs!" % [active_character.active_ability_name, active_timer])
	ability_activated.emit(active_character, active_character.active_duration)
	return true


## Refunds ability cooldown timer by a fraction (e.g. 0.35 = 35% cooldown refund).
func charge_ability(fraction: float = 0.35) -> void:
	if not active_character or is_ability_active:
		return
	var reduction: float = active_character.active_cooldown * fraction
	cooldown_timer = maxf(0.0, cooldown_timer - reduction)
	cooldown_updated.emit(cooldown_timer, active_character.active_cooldown)
	print("[CharacterManager] Charged ability by %.0f%%. Remaining cooldown: %.1fs" % [fraction * 100.0, cooldown_timer])



func _deactivate_ability() -> void:
	if not is_ability_active:
		return

	is_ability_active = false
	active_timer = 0.0
	print("[CharacterManager] Ability expired. Cooldown: %.1fs" % cooldown_timer)
	ability_deactivated.emit(active_character)


## Sets the active character and applies passive perks.
func select_character(char_data: Resource) -> void:
	if not char_data:
		return

	active_character = char_data
	reset_ability_state()

	# Apply Passive Perk modifiers to GameManager
	if GameManager:
		if active_character.get("passive_perk_type") == "pax_romana":
			GameManager.govt_decay_modifier = 0.85
		else:
			GameManager.govt_decay_modifier = 1.0

	character_selected.emit(active_character)
	print("[CharacterManager] Selected character: %s (%s)" % [active_character.character_name, active_character.era_name])


## Selects a character by common name ("caesar", "joan", "harriet").
func select_character_by_name(identifier: String) -> void:
	match identifier.to_lower():
		"caesar", "julius":
			select_character(CAESAR_RES)
		"joan", "arc":
			select_character(JOAN_RES)
		"harriet", "tubman":
			select_character(HARRIET_RES)


## Resets ability cooldowns and active states back to baseline.
func reset_ability_state() -> void:
	is_ability_active = false
	active_timer = 0.0
	cooldown_timer = 0.0
	if active_character:
		cooldown_updated.emit(0.0, active_character.active_cooldown)


func _on_game_restarted() -> void:
	reset_ability_state()
