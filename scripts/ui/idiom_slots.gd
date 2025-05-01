extends PanelContainer

var current_word: Node = null
var word_scene = preload("res://scenes/ui/inventory_word.tscn")

func _ready() -> void:
	add_to_group("idiom_slot")
	custom_minimum_size = Vector2(50, 50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_appearance()

func _setup_appearance() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	add_theme_stylebox_override("panel", style)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var label = Label.new()
	label.text = str(get_index() + 1)
	label.modulate = Color(1, 1, 1, 0.3)
	center.add_child(label)

func is_empty() -> bool:
	return current_word == null

func get_word() -> Node:
	return current_word

func accept_word(word_text: String) -> void:
	if not is_empty():
		remove_word()
	
	var word_instance = word_scene.instantiate()
	word_instance.character = word_text
	word_instance.custom_minimum_size = Vector2(50, 50)
	add_child(word_instance)
	current_word = word_instance
	
	_check_idiom_formation()

func _check_idiom_formation() -> void:
	var word_system = get_tree().get_first_node_in_group("word_system")
	if not word_system:
		return
		
	var current_combination = _get_current_combination()
	if current_combination in word_system.IDIOMS:
		word_system.unlock_idiom_effect(current_combination)
	else:
		word_system.update_active_effects("")
	
	var word_collection_ui = get_tree().get_first_node_in_group("word_collection_ui")
	if word_collection_ui and word_collection_ui.has_method("update_idiom_hints"):
		word_collection_ui.update_idiom_hints(word_system.check_idioms())

func remove_word() -> void:
	if not current_word:
		return
		
	var word_text = _get_word_text(current_word)
	current_word.queue_free()
	current_word = null
	
	if word_text != "":
		var word_system = get_tree().get_first_node_in_group("word_system")
		if word_system:
			word_system.update_active_effects("")

func get_current_text() -> String:
	if not current_word:
		return ""
	return _get_word_text(current_word)

func _get_word_text(word: Node) -> String:
	if word.has_method("get_character"):
		return word.get_character()
	elif "character" in word:
		return word.character
	return ""

func _get_current_combination() -> String:
	var combination = ""
	var parent = get_parent()
	if parent:
		for slot in parent.get_children():
			if slot.has_method("get_current_text"):
				combination += slot.get_current_text()
	return combination
