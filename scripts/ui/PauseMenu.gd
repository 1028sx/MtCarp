extends Control

signal back_to_menu

@onready var resume_button = $Panel/VBoxContainer/HBoxContainer3/ResumeButton
@onready var settings_button = $Panel/VBoxContainer/HBoxContainer2/SettingsButton
@onready var menu_button = $Panel/VBoxContainer/HBoxContainer/MenuButton
@onready var settings_menu = preload("res://scenes/ui/SettingsMenu.tscn").instantiate()

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	
	add_child(settings_menu)
	settings_menu.settings_closed.connect(_on_settings_closed)
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if settings_menu.visible:
			settings_menu.hide_settings()
			$Panel.show()
		elif visible:
			hide_menu()
		else:
			show_menu()
		get_viewport().set_input_as_handled()

func show_menu():
	if get_tree().current_scene.name == "MainMenu":
		hide()
		return
	
	if not visible:
		show()
		get_tree().paused = true

func hide_menu():
	if visible:
		hide()
		var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
		if not inventory_ui or not inventory_ui.visible:
			get_tree().paused = false

func _on_resume_pressed():
	hide_menu()

func _on_settings_pressed():
	settings_menu.show_settings()
	$Panel.hide()

func _on_menu_pressed():
	hide_menu()
	back_to_menu.emit() 

func _on_settings_closed():
	$Panel.show()
  
