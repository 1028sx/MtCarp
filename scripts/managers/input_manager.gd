extends Node

var _pause_stack: int = 0
var room_manager: Node

func _ready():
	room_manager = get_node_or_null("/root/RoomSystem")

func _input(event):
	if event.is_action_pressed("pause"):
		_handle_pause_input()
	elif event.is_action_pressed("map"):
		_handle_map_input()
	elif event.is_action_pressed("inventory"):
		_handle_inventory_input()

func _handle_pause_input():
	if get_tree().paused:
		request_unpause()
	else:
		request_pause()

func _handle_map_input():
	_toggle_map()

func _handle_inventory_input():
	var ui_system = get_node("/root/UISystem")
	if ui_system:
		if not get_tree().paused:
			request_pause()
		ui_system.toggle_inventory()
		get_viewport().set_input_as_handled()

func request_pause():
	_pause_stack += 1
	if _pause_stack > 0:
		get_tree().paused = true

func request_unpause():
	_pause_stack = max(0, _pause_stack - 1)
	if _pause_stack == 0:
		get_tree().paused = false

func _toggle_pause():
	if get_tree().paused:
		request_unpause()
	else:
		request_pause()

func _toggle_map() -> void:
	if room_manager:
		if MetSys.is_map_visible():
			room_manager.hide_map()
		else:
			room_manager.show_map()

func initialize_pause_system():
	_pause_stack = 0
	get_tree().paused = false

func get_pause_stack() -> int:
	return _pause_stack