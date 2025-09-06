extends Control

signal settings_closed

# 修正為場景中的實際節點路徑
@onready var music_slider = $Panel/VBoxContainer/MusicSettings/MusicBar/Slider
@onready var music_label = $Panel/VBoxContainer/MusicSettings/MusicLabel
@onready var sfx_slider = $Panel/VBoxContainer/SFXSettings/SFXBar/Slider
@onready var sfx_label = $Panel/VBoxContainer/SFXSettings/SFXLabel
@onready var back_button = $Panel/VBoxContainer/HBoxContainer/BackButton

var ui_system: Node

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_menu")
	
	# 獲取UISystem引用
	ui_system = get_node_or_null("/root/UISystem")
	
	# 音樂控制設置（Bus 1 - Music）
	if music_slider:
		music_slider.min_value = 0
		music_slider.max_value = 100
		music_slider.step = 1
		var music_db = AudioServer.get_bus_volume_db(1)
		music_slider.value = (music_db + 30.0) * (100.0/30.0)
		music_slider.value_changed.connect(_on_music_changed)
	
	# 音效控制設置（Bus 2 - SFX）
	if sfx_slider:
		sfx_slider.min_value = 0
		sfx_slider.max_value = 100
		sfx_slider.step = 1
		var sfx_db = AudioServer.get_bus_volume_db(2)
		sfx_slider.value = (sfx_db + 30.0) * (100.0/30.0)
		sfx_slider.value_changed.connect(_on_sfx_changed)
	
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	
	_update_music_label(music_slider.value if music_slider else 80)
	_update_sfx_label(sfx_slider.value if sfx_slider else 90)

# 移除自定義拖拽處理，使用內建HSlider功能

func _on_music_changed(value: float) -> void:
	var db_value = (value * 30.0/100.0) - 30.0
	AudioServer.set_bus_volume_db(1, db_value)
	_update_music_label(value)

func _update_music_label(value: float) -> void:
	if music_label:
		music_label.text = "音樂：%d%%" % [value]

func _on_sfx_changed(value: float) -> void:
	var db_value = (value * 30.0/100.0) - 30.0
	AudioServer.set_bus_volume_db(2, db_value)
	_update_sfx_label(value)

func _update_sfx_label(value: float) -> void:
	if sfx_label:
		sfx_label.text = "音效：%d%%" % [value]


func _on_back_pressed() -> void:
	hide()
	if ui_system:
		ui_system.pop_ui_state()
	settings_closed.emit()

func show_settings() -> void:
	if get_tree().current_scene.name == "MainMenu":
		hide()
		return
	
	show()
