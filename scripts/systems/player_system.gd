extends Node

var player_node: CharacterBody2D = null

signal player_registration_changed(is_registered: bool)

func _ready() -> void:
	add_to_group("player_system")

func register_player(p_player_node: CharacterBody2D) -> void:
	player_node = p_player_node if is_instance_valid(p_player_node) else null
	player_registration_changed.emit(player_node != null)

func unregister_player() -> void:
	player_node = null
	player_registration_changed.emit(false)

func get_player() -> CharacterBody2D:
	if is_instance_valid(player_node):
		return player_node
	return null

func is_player_available() -> bool:
	return is_instance_valid(player_node)

func cleanup() -> void:
	player_node = null
	player_registration_changed.emit(false)