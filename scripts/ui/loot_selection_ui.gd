extends CanvasLayer

signal effect_selected(effect_data: Dictionary)

@onready var selection_container = $SelectionContainer

var effect_button_scene = preload("res://scenes/ui/effect_button.tscn")
var current_effects: Array = []
var available_effects_pool: Array = []
var shown_effects: Array = []
var is_menu_active := false

func _ready() -> void:
	add_to_group("loot_selection_ui", true)
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	
	if selection_container:
		selection_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selection_container.process_mode = Node.PROCESS_MODE_ALWAYS
		selection_container.custom_minimum_size = Vector2(800, 200)
		
		for child in selection_container.get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_STOP
				child.process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("refresh_loot"):
		refresh_effects()
		get_viewport().set_input_as_handled()

func show_effects(effects: Array) -> void:
	if get_tree().current_scene.name == "MainMenu":
		hide()
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	available_effects_pool = effects.duplicate()
	shown_effects.clear()
	
	for child in selection_container.get_children():
		child.queue_free()
	
	_display_effects()
	show_menu()

func show_menu() -> void:
	if not is_menu_active:
		is_menu_active = true
		show()
		
		_ensure_input_handling(selection_container)
		
		var global_ui = get_tree().get_first_node_in_group("global_ui")
		if global_ui:
			global_ui.request_pause("loot_ui")

func _ensure_input_handling(node: Node) -> void:
	if node is Control:
		if node == selection_container:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		node.set_process_input(true)
		node.set_process_unhandled_input(true)
		
	for child in node.get_children():
		_ensure_input_handling(child)

func hide_menu() -> void:
	if is_menu_active:
		is_menu_active = false
		hide()
		
		var global_ui = get_tree().get_first_node_in_group("global_ui")
		if global_ui:
			global_ui.request_unpause("loot_ui")

func refresh_effects() -> void:
	for child in selection_container.get_children():
		child.queue_free()
	
	for effect in current_effects:
		if not shown_effects.has(effect):
			shown_effects.append(effect)
	
	_display_effects()

func reset() -> void:
	for child in selection_container.get_children():
		child.queue_free()
	
	current_effects.clear()
	available_effects_pool.clear()
	shown_effects.clear()
	
	hide_menu()

func _display_effects() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	for child in selection_container.get_children():
		child.queue_free()
	
	if available_effects_pool.is_empty():
		return
	
	var filtered_effects = available_effects_pool.filter(func(effect): 
		return not player.active_effects.has(effect.effect)
	)
	
	if filtered_effects.is_empty():
		return
	
	if filtered_effects.size() < 3:
		shown_effects.clear()
	
	filtered_effects.shuffle()
	current_effects = filtered_effects.slice(0, min(3, filtered_effects.size()))
	
	for effect in current_effects:
		var button = effect_button_scene.instantiate()
		selection_container.add_child(button)
		
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		button.setup(effect)
		button.pressed.connect(func(): _on_effect_selected(effect))
		
		if not shown_effects.has(effect):
			shown_effects.append(effect)
	
	show_menu()

func _on_effect_selected(effect: Dictionary) -> void:
	effect_selected.emit(effect)
	reset()

func _exit_tree() -> void:
	reset()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		reset()
