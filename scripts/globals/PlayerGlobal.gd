extends Node

static var instance: PlayerGlobal = null
var player_node: CharacterBody2D = null

signal player_registration_changed(is_registered: bool)

func _enter_tree() -> void:
	if not instance:
		instance = self
	else:
		queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and instance == self:
		cleanup()

func register_player(p_player_node: CharacterBody2D) -> void:
	player_node = p_player_node if is_instance_valid(p_player_node) else null
	player_registration_changed.emit(player_node != null)

func unregister_player() -> void:
	player_node = null
	player_registration_changed.emit(false)

static func get_player() -> CharacterBody2D:
	if instance and is_instance_valid(instance.player_node):
		return instance.player_node
	return null

static func is_player_available() -> bool:
	return instance != null and is_instance_valid(instance.player_node)

func cleanup() -> void:
	player_node = null
	instance = null
	player_registration_changed.emit(false)
