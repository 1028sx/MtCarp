extends Area2D

signal collected(word: String)
signal drag_started(word: Node)
signal drag_ended(word: Node)

@export var character: String = "字"

var is_collected := false
var is_dragging := false
var drag_offset := Vector2()
var original_parent: Node = null
var original_position := Vector2()

func _ready() -> void:
	add_to_group("word")
	$Label.text = character
	process_mode = Node.PROCESS_MODE_ALWAYS
	input_pickable = true
	
	if is_in_inventory():
		monitoring = false
		monitorable = false
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
	else:
		body_entered.connect(_on_body_entered)
		if has_node("AnimationPlayer"):
			$AnimationPlayer.play("float")

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag()
				get_viewport().set_input_as_handled()
			else:
				end_drag()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() + drag_offset
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() + drag_offset

func start_drag():
	if not is_dragging:
		is_dragging = true
		original_parent = get_parent()
		original_position = position
		drag_offset = position - get_local_mouse_position()
		
		var root = get_tree().root
		if original_parent:
			original_parent.remove_child(self)
			root.add_child(self)
			z_index = 100
		
		drag_started.emit(self)

func end_drag():
	if is_dragging:
		is_dragging = false
		z_index = 0
		
		var slots = get_tree().get_nodes_in_group("idiom_slot")
		var found_slot = false
		
		for slot in slots:
			var slot_rect = slot.get_global_rect()
			var mouse_pos = get_global_mouse_position()
			
			if slot_rect.has_point(mouse_pos):
				if slot.is_empty():
					place_in_slot(slot)
					found_slot = true
					break
				elif slot.current_word != self:
					swap_with_slot(slot)
					found_slot = true
					break
		
		if not found_slot:
			return_to_original()
		
		drag_ended.emit(self)

func place_in_slot(slot: Node):
	if original_parent:
		get_parent().remove_child(self)
		slot.add_word(self)
		position = Vector2.ZERO

func swap_with_slot(slot: Node):
	var other_word = slot.current_word
	if other_word and original_parent:
		slot.remove_word()
		original_parent.add_child(other_word)
		other_word.position = original_position
		
		get_parent().remove_child(self)
		slot.add_word(self)
		position = Vector2.ZERO

func return_to_original():
	if original_parent:
		get_parent().remove_child(self)
		original_parent.add_child(self)
		position = original_position

func is_in_inventory() -> bool:
	var parent = get_parent()
	while parent:
		if parent is Control:
			return true
		parent = parent.get_parent()
	return false

func _on_body_entered(body: Node2D) -> void:
	if not is_collected and body.is_in_group("player"):
		is_collected = true
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
		tween.tween_callback(func():
			collected.emit(character)
			queue_free()
		)
