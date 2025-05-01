extends Control

signal drag_started(word: Node)
signal drag_ended(word: Node)

@export var character: String = "字"

var is_dragging := false
var original_parent: Node = null
var original_position := Vector2()
var drag_start_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Label.text = character

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_start_time = Time.get_ticks_msec()
				start_drag()
			else:
				var drag_duration = Time.get_ticks_msec() - drag_start_time
				if drag_duration < 200:
					handle_click()
				else:
					end_drag()
	elif event is InputEventMouseMotion and is_dragging:
		position += event.relative

func handle_click() -> void:
	is_dragging = false
	z_index = 0
	
	var current_parent = get_parent()
	if current_parent == null:
		return
		
	var slots = get_tree().get_nodes_in_group("idiom_slot")
	if slots.is_empty():
		return
		
	if current_parent.name == "CollectedWords":
		for slot in slots:
			if not slot.has_method("add_word"):
				continue
			if slot.current_word == null:
				place_in_slot(slot)
				return
	else:
		var collected_words = get_tree().get_first_node_in_group("collected_words")
		if collected_words:
			if current_parent.has_method("remove_word"):
				current_parent.remove_word()
			
			if get_parent():
				get_parent().remove_child(self)
			collected_words.add_child(self)
			position = Vector2.ZERO
			update_original_info(collected_words, Vector2.ZERO)

func start_drag() -> void:
	is_dragging = true
	original_parent = get_parent()
	if original_parent == null:
		return
		
	original_position = position
	z_index = 100
	drag_started.emit(self)

func end_drag() -> void:
	if not is_dragging:
		return
		
	z_index = 0
	
	if not is_inside_tree():
		is_dragging = false
		return
		
	var slots = get_tree().get_nodes_in_group("idiom_slot")
	var found_slot = false
	
	for slot in slots:
		if not slot.has_method("add_word"):
			continue
			
		var slot_rect = slot.get_global_rect()
		var mouse_pos = get_global_mouse_position()
		
		if slot_rect.has_point(mouse_pos):
			if slot.current_word != null and slot.current_word != self:
				swap_with_slot(slot)
				found_slot = true
				break
			elif slot.current_word == null:
				place_in_slot(slot)
				found_slot = true
				break
	
	if not found_slot:
		return_to_original()
	
	is_dragging = false
	drag_ended.emit(self)

func place_in_slot(slot: Node) -> void:
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	
	if slot.has_method("add_word"):
		slot.add_word(self)
	else:
		slot.add_child(self)
	position = Vector2.ZERO
	update_original_info(slot, Vector2.ZERO)

func return_to_original() -> void:
	var current_parent = get_parent()
	if current_parent:
		if current_parent.has_method("update_current_word"):
			current_parent.update_current_word(null)
		current_parent.remove_child(self)
	
	if original_parent:
		original_parent.add_child(self)
		position = original_position

func update_original_info(new_parent: Node, new_position: Vector2) -> void:
	original_parent = new_parent
	original_position = new_position

func swap_with_slot(slot: Node) -> void:
	if not is_inside_tree():
		return
		
	var target_word = slot.current_word
	if target_word == null:
		place_in_slot(slot)
		return
		
	var my_current_parent = get_parent()
	var target_current_parent = target_word.get_parent()
	
	if my_current_parent == null or target_current_parent == null:
		return
	
	my_current_parent.remove_child(self)
	target_current_parent.remove_child(target_word)
	
	if target_current_parent.has_method("update_current_word"):
		target_current_parent.update_current_word(null)
	
	if my_current_parent.has_method("add_word"):
		my_current_parent.add_word(target_word)
	else:
		my_current_parent.add_child(target_word)
	target_word.position = Vector2.ZERO
	
	if slot.has_method("add_word"):
		slot.add_word(self)
	else:
		slot.add_child(self)
	position = Vector2.ZERO
	
	update_original_info(slot, Vector2.ZERO)
	target_word.update_original_info(my_current_parent, Vector2.ZERO)
