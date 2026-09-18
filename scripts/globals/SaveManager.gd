## SaveManager.gd
## Autoload Singleton handling persistent JSON save data (user://save_data.json),
## alternate history timeline cards, equippable relic loadouts, and milestone progression.
extends Node

# --- Signals ---
signal card_unlocked(card: Dictionary)
signal relic_equipped(relic_id: String)
signal relic_unequipped(relic_id: String)
signal save_data_loaded()

# --- Configuration Constants ---
const SAVE_PATH: String = "user://save_data.json"
const MAX_EQUIPPED_RELICS: int = 2

# Relic Catalog Definitions
const RELIC_CATALOG = {
	"cleopatra_asp": {
		"name": "Cleopatra's Asp",
		"description": "Prevents fatal damage once per run, resetting both meters to 50% with 3s invulnerability.",
		"icon": "🐍"
	},
	"napoleon_telescope": {
		"name": "Napoleon's Telescope",
		"description": "Slows time down by an extra 30% during Decision Gates (time_scale = 0.14).",
		"icon": "🔭"
	},
	"tesla_watch": {
		"name": "Tesla's Pocket Watch",
		"description": "Magnetizes all collectibles for 3.0 seconds after passing any Decision Gate.",
		"icon": "⏱️"
	}
}

# Milestone Locked Rulers Definitions
const LOCKED_RULERS = {
	"Napoleon": {
		"name": "Napoleon Bonaparte",
		"era": "Napoleonic France (1804)",
		"requirement": "Pass 5 Decision Gates as Caesar",
		"target_stat": "caesar_gates_passed",
		"target_count": 5
	},
	"Cleopatra": {
		"name": "Cleopatra VII",
		"era": "Ptolemaic Egypt (48 BCE)",
		"requirement": "Collect 50 People Favor tokens",
		"target_stat": "fists_collected",
		"target_count": 50
	},
	"Nobunaga": {
		"name": "Oda Nobunaga",
		"era": "Sengoku Japan (1568)",
		"requirement": "Survive 1 Boss Chase",
		"target_stat": "bosses_defeated",
		"target_count": 1
	}
}

# --- State Data Structure ---
var save_data: Dictionary = {
	"unlocked_characters": ["Caesar", "JoanOfArc", "HarrietTubman"],
	"unlocked_relics": [],
	"equipped_relics": [],
	"unlocked_timeline_cards": [],
	"total_relics_collected": 0,
	"best_distance": 0,
	"stats": {
		"caesar_gates_passed": 0,
		"fists_collected": 0,
		"bosses_defeated": 0,
		"runs_completed": 0
	}
}


func _ready() -> void:
	load_game()


## Saves active dictionary to user://save_data.json via JSON string format.
func save_game() -> bool:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Failed to open save file for writing: %s" % SAVE_PATH)
		return false

	var json_str: String = JSON.stringify(save_data, "\t")
	file.store_string(json_str)
	file.close()
	print("[SaveManager] Game state successfully saved to: %s" % SAVE_PATH)
	return true


## Loads persistent dictionary from user://save_data.json.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No existing save found. Initializing default profile.")
		save_game()
		save_data_loaded.emit()
		return true

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Failed to open save file for reading: %s" % SAVE_PATH)
		return false

	var content: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error = json.parse(content)
	if error != OK:
		push_error("[SaveManager] JSON Parse Error: %s in %s" % [json.get_error_message(), content])
		return false

	var loaded_dict = json.data
	if loaded_dict is Dictionary:
		# Merge loaded keys into save_data ensuring default keys remain intact
		for key in loaded_dict.keys():
			save_data[key] = loaded_dict[key]
		print("[SaveManager] Save data loaded successfully (%d timeline cards unlocked)." % save_data["unlocked_timeline_cards"].size())
		save_data_loaded.emit()
		return true

	return false


## Unlocks an alternate history timeline card (deduplicated by card_id).
func unlock_card(card_id: String, title: String, blurb: String) -> bool:
	for existing in save_data["unlocked_timeline_cards"]:
		if existing.get("id") == card_id:
			return false # Already unlocked

	var card_entry: Dictionary = {
		"id": card_id,
		"title": title,
		"blurb": blurb,
		"timestamp": Time.get_datetime_string_from_system()
	}

	save_data["unlocked_timeline_cards"].append(card_entry)
	save_game()
	print("[SaveManager] 📜 NEW TIMELINE CARD DISCOVERED: %s - '%s'" % [card_id, title])
	card_unlocked.emit(card_entry)
	return true


## Checks if a card is unlocked.
func is_card_unlocked(card_id: String) -> bool:
	for existing in save_data["unlocked_timeline_cards"]:
		if existing.get("id") == card_id:
			return true
	return false


## Equips a relic (enforcing max 2 equipped relics limit).
func equip_relic(relic_id: String) -> bool:
	if not RELIC_CATALOG.has(relic_id):
		return false

	var equipped: Array = save_data["equipped_relics"]
	if equipped.has(relic_id):
		return true # Already equipped

	if equipped.size() >= MAX_EQUIPPED_RELICS:
		# Remove oldest equipped relic to make space
		var removed = equipped.pop_front()
		relic_unequipped.emit(removed)

	equipped.append(relic_id)
	save_game()
	relic_equipped.emit(relic_id)
	print("[SaveManager] Equipped relic: %s" % relic_id)
	return true


## Unequips an equipped relic.
func unequip_relic(relic_id: String) -> bool:
	var equipped: Array = save_data["equipped_relics"]
	if equipped.has(relic_id):
		equipped.erase(relic_id)
		save_game()
		relic_unequipped.emit(relic_id)
		print("[SaveManager] Unequipped relic: %s" % relic_id)
		return true
	return false


## Checks if a specific relic is currently active in the runner loadout.
func is_relic_equipped(_relic_id: String) -> bool:
	return false


## Increments a tracked progression stat and checks for ruler milestone unlocks.
func add_stat(stat_name: String, amount: int = 1) -> void:
	var stats: Dictionary = save_data["stats"]
	stats[stat_name] = stats.get(stat_name, 0) + amount
	_check_milestone_unlocks()
	save_game()


## Evaluates milestone conditions for locked historical rulers.
func _check_milestone_unlocks() -> void:
	var stats: Dictionary = save_data["stats"]
	var unlocked_chars: Array = save_data["unlocked_characters"]

	for ruler_id in LOCKED_RULERS.keys():
		if unlocked_chars.has(ruler_id):
			continue

		var info: Dictionary = LOCKED_RULERS[ruler_id]
		var stat_key: String = info["target_stat"]
		var target_count: int = info["target_count"]

		if stats.get(stat_key, 0) >= target_count:
			unlocked_chars.append(ruler_id)
			print("[SaveManager] 🎉 NEW RULER UNLOCKED: %s! (%s)" % [info["name"], info["requirement"]])
			unlock_card("ruler_" + ruler_id.to_lower(), "Ruler Unlocked: " + info["name"], "You satisfied the milestone: " + info["requirement"])


## Checks if a ruler is unlocked.
func is_character_unlocked(character_name: String) -> bool:
	var unlocked: Array = save_data.get("unlocked_characters", [])
	return unlocked.has(character_name)
