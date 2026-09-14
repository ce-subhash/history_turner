## Main.gd
## Root scene script for "Timetracks: Rulers & Rebels".
## Coordinates scene initialization and high-level lifecycle.
extends Node3D


func _ready() -> void:
	# Ensure game state is initialized
	if GameManager:
		GameManager.reset_state()
