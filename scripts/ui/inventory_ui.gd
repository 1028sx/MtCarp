extends Control

@onready var word_collection_ui = $WordCollectionUI

var canvas_layer: CanvasLayer = null
var process_mode_monitor: Timer = null

func _ready() -> void:
	if not is_in_group("inventory_ui"):
		add_to_group("inventory_ui")
	
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	if word_collection_ui:
		word_collection_ui.set_process_mode(Node.PROCESS_MODE_ALWAYS)
		word_collection_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_start_process_mode_monitor()
	
	_ensure_canvas_layer()
	hide()

func _start_process_mode_monitor() -> void:
	if process_mode_monitor:
		process_mode_monitor.queue_free()
	
	process_mode_monitor = Timer.new()
	process_mode_monitor.wait_time = 0.01
	process_mode_monitor.one_shot = false
	process_mode_monitor.timeout.connect(_check_process_modes)
	process_mode_monitor.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	add_child(process_mode_monitor)
	process_mode_monitor.start()

func _check_process_modes() -> void:
	if not is_instance_valid(word_collection_ui):
		process_mode_monitor.stop()
		return
		
	if process_mode != Node.PROCESS_MODE_ALWAYS:
		set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	if word_collection_ui.process_mode != Node.PROCESS_MODE_ALWAYS:
		word_collection_ui.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	_check_node_process_mode(self)

func _check_node_process_mode(node: Node) -> void:
	if node.process_mode != Node.PROCESS_MODE_ALWAYS:
		node.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	if node is Control:
		if node.is_in_group("inventory_word") or node.is_in_group("idiom_slot"):
			node.mouse_filter = Control.MOUSE_FILTER_STOP
			if node.is_in_group("inventory_word"):
				node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			elif node.is_in_group("idiom_slot"):
				node.mouse_default_cursor_shape = Control.CURSOR_DRAG
		else:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for child in node.get_children():
		_check_node_process_mode(child)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED:
			set_process_mode(Node.PROCESS_MODE_ALWAYS)
		NOTIFICATION_UNPARENTED:
			set_process_mode(Node.PROCESS_MODE_ALWAYS)
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible:
				set_process_mode(Node.PROCESS_MODE_ALWAYS)
				if word_collection_ui:
					word_collection_ui.set_process_mode(Node.PROCESS_MODE_ALWAYS)
				_check_node_process_mode(self)

func _ensure_canvas_layer() -> void:
	if not canvas_layer:
		canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 100
		canvas_layer.set_process_mode(Node.PROCESS_MODE_ALWAYS)
		
		var parent = get_parent()
		if parent:
			parent.remove_child(self)
			parent.add_child(canvas_layer)
			canvas_layer.add_child(self)
			
			set_process_mode(Node.PROCESS_MODE_ALWAYS)
			if word_collection_ui:
				word_collection_ui.set_process_mode(Node.PROCESS_MODE_ALWAYS)
		else:
			await get_tree().process_frame
			if get_parent():
				_ensure_canvas_layer()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
