extends Control

var is_transitioning := false

func _ready() -> void:
	# 確保遊戲時間恢復正常
	Engine.time_scale = 1.0
	
	# 禁用所有遊戲內 UI
	get_tree().paused = false
	
	# 清理可能存在的遊戲內 UI
	for group_name in ["inventory_ui", "loot_selection_ui", "pause_menu", "settings_menu"]:
		var nodes = get_tree().get_nodes_in_group(group_name)
		for node in nodes:
			node.queue_free()
	
	# 手動連接信號
	var start_button = $VBoxContainer/HBoxContainer2/StartButton
	if start_button and not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
		
	var quit_button = $VBoxContainer/HBoxContainer/QuitButton
	if quit_button and not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed() -> void:
	if is_transitioning:
		return
		
	is_transitioning = true
	$VBoxContainer/HBoxContainer2/StartButton.disabled = true
	
	var transition_screen = get_node_or_null("/root/TransitionScreen")
	if transition_screen:
		await transition_screen.fade_to_black()
		# 確保場景存在
		if ResourceLoader.exists("res://scenes/Main.tscn"):
			get_tree().change_scene_to_file("res://scenes/Main.tscn")
			await transition_screen.fade_from_black()
		else:
			push_error("無法找到主場景檔案")
			is_transitioning = false
			$VBoxContainer/HBoxContainer2/StartButton.disabled = false
	else:
		push_error("無法找到過場動畫節點")
		is_transitioning = false
		$VBoxContainer/HBoxContainer2/StartButton.disabled = false

func _on_quit_button_pressed() -> void:
	get_tree().quit() 
