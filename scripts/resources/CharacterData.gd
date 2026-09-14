## CharacterData.gd
## Custom Resource defining historical leader statistics, abilities, and passives.
extends Resource
class_name CharacterData

@export var character_name: String = "Julius Caesar"
@export var era_name: String = "Classical Rome (44 BCE)"
@export var base_speed_modifier: float = 1.0
@export var active_ability_name: String = "Testudo Shield Wall"
@export var active_duration: float = 6.0
@export var active_cooldown: float = 20.0
@export var passive_perk_type: String = "pax_romana"

# Additional metadata for presentation & UI
@export var ability_description: String = "Forms an impenetrable shield wall; immune to all obstacles for 6s."
@export var passive_description: String = "Pax Romana: Government favor decay rate is reduced by 15%."
@export var theme_color: Color = Color(0.9, 0.25, 0.25)
@export var difficulty_rating: String = "Easy / Defense"
