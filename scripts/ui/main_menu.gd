extends Control

@onready var start_button = $VBoxContainer/HBoxContainer2/StartButton
@onready var quit_button = $VBoxContainer/HBoxContainer/QuitButton

var is_transitioning := false
var ui_system: Node

func _ready() -> void:
	# 確保遊戲時間恢復正常
	Engine.time_scale = 1.0
	
	# 禁用所有遊戲內 UI
	get_tree().paused = false
	
	# 獲取UISystem引用
	ui_system = get_node_or_null("/root/UISystem")
	if ui_system:
		ui_system.change_ui_state(ui_system.UIState.MENU, false)
		ui_system.cleanup_game_ui()
	
	# 信號連接
	if start_button and not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed() -> void:
	if is_transitioning:
		return
		
	is_transitioning = true
	start_button.disabled = true
	
	ui_system.change_ui_state(ui_system.UIState.GAME, false)
	await ui_system.request_scene_transition("res://scenes/main.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit() 
