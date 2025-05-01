extends Control

signal settings_closed

@onready var volume_bar = $Panel/VBoxContainer/VolumeSettings/VolumeBar
@onready var volume_slider = $Panel/VBoxContainer/VolumeSettings/VolumeBar/Slider
@onready var volume_label = $Panel/VBoxContainer/VolumeSettings/VolumeLabel
@onready var fullscreen_button = $Panel/VBoxContainer/FullscreenSettings/FullscreenButton
@onready var back_button = $Panel/VBoxContainer/HBoxContainer/BackButton

var is_dragging = false

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_menu")
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	style.set_corner_radius_all(4)
	volume_bar.add_theme_stylebox_override("background", style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.8, 0.8, 0.8)
	fill_style.set_corner_radius_all(4)
	volume_bar.add_theme_stylebox_override("fill", fill_style)
	
	volume_bar.min_value = 0
	volume_bar.max_value = 100
	volume_bar.value = (AudioServer.get_bus_volume_db(0) + 30.0) * (100.0/30.0)
	_update_slider_position()
	
	fullscreen_button.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	volume_bar.value_changed.connect(_on_volume_changed)
	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_pressed)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var bar_rect = volume_bar.get_global_rect()
				if bar_rect.has_point(event.global_position):
					is_dragging = true
					_handle_drag(event.global_position)
			else:
				if is_dragging:
					is_dragging = false
					_handle_drag(event.global_position)
	
	elif event is InputEventMouseMotion and is_dragging:
		_handle_drag(event.global_position)

func _handle_drag(mouse_pos: Vector2):
	var bar_rect = volume_bar.get_global_rect()
	var slider_width = volume_slider.size.x
	
	var relative_x = mouse_pos.x - bar_rect.position.x
	
	if relative_x <= slider_width/2.0:
		volume_bar.value = volume_bar.min_value
	elif relative_x >= bar_rect.size.x - slider_width/2.0:
		volume_bar.value = volume_bar.max_value
	else:
		var ratio = (relative_x - slider_width/2.0) / (bar_rect.size.x - slider_width/2.0)
		var new_value = lerp(volume_bar.min_value, volume_bar.max_value, ratio)
		volume_bar.value = new_value
	
	_on_volume_changed(volume_bar.value)

func _on_volume_changed(value: float) -> void:
	var db_value = (value * 30.0/100.0) - 30.0
	AudioServer.set_bus_volume_db(0, db_value)
	_update_slider_position()
	_update_volume_label(value)

func _update_slider_position() -> void:
	if volume_slider:
		var ratio = inverse_lerp(volume_bar.min_value, volume_bar.max_value, volume_bar.value)
		var slider_width = volume_slider.size.x
		volume_slider.position.x = ratio * (volume_bar.size.x - slider_width/2.0)

func _update_volume_label(value: float) -> void:
	if volume_label:
		volume_label.text = "音量：%d%%" % [value]

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	hide()
	settings_closed.emit()

func show_settings() -> void:
	if get_tree().current_scene.name == "MainMenu":
		hide()
		return
	
	show()
