extends TextureButton

@onready var icon = $Icon
@onready var title = $Title
@onready var description = $Description

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if title:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	if description:
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
			child.focus_mode = Control.FOCUS_NONE
			child.process_mode = Node.PROCESS_MODE_DISABLED
			child.set_process_input(false)
			child.set_process_unhandled_input(false)
			child.set_process_unhandled_key_input(false)

func setup(effect: Dictionary) -> void:
	if title and effect.has("name"):
		title.text = effect.name
	if description and effect.has("description"):
		description.text = effect.description
	if icon and effect.has("icon") and effect.icon != null:
		icon.texture = effect.icon

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed.emit()
			accept_event()
			get_viewport().set_input_as_handled()

func _on_mouse_entered() -> void:
	modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and get_global_rect().has_point(get_global_mouse_position()):
		_gui_input(event)
		get_viewport().set_input_as_handled()
