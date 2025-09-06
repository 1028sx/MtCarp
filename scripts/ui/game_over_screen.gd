extends CanvasLayer

@onready var play_time_label = $CenterContainer/VBoxContainer/VBoxContainer_Stats/Label_PlayTime
@onready var kill_count_label = $CenterContainer/VBoxContainer/VBoxContainer_Stats/Label_KillCount
@onready var max_combo_label = $CenterContainer/VBoxContainer/VBoxContainer_Stats/Label_MaxCombo
@onready var gold_label = $CenterContainer/VBoxContainer/VBoxContainer_Stats/Label_Gold
@onready var links_label = $CenterContainer/VBoxContainer/HBoxContainer_Links/Label
@onready var discord_button = $CenterContainer/VBoxContainer/HBoxContainer_Links/Button_Discord
@onready var github_button = $CenterContainer/VBoxContainer/HBoxContainer_Links/Button_GitHub
@onready var feedback_button = $CenterContainer/VBoxContainer/HBoxContainer_Links/Button_Feedback

var ui_system: Node

const DISCORD_ID = "613878521898598531"
const GITHUB_URL = "https://github.com/1028sx/graduation_project"
const FEEDBACK_URL = "https://forms.gle/GzWnzdix2vK2M4747"

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_over_screen")
	
	# 獲取UISystem引用
	ui_system = get_node_or_null("/root/UISystem")
	
	# 設置按鈕信號
	discord_button.pressed.connect(_on_discord_pressed)
	github_button.pressed.connect(_on_github_pressed)
	feedback_button.pressed.connect(_on_feedback_pressed)


func show_screen() -> void:
	# 顯示統計數據
	call_deferred("_update_stats")
	show()
	
	# 使用UISystem管理狀態
	if ui_system:
		ui_system.change_ui_state(ui_system.UIState.GAME_OVER)
	else:
		get_tree().paused = true

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):  # Esc 鍵
		_back_to_menu()
		get_viewport().set_input_as_handled()

func _update_stats() -> void:
	var combat_system = get_node_or_null("/root/CombatSystem")
	
	var progress_system = get_node_or_null("/root/ProgressSystem")
	if progress_system:
		# 格式化遊戲時間
		var total_seconds: int = int(progress_system.get_play_time())
		var minutes: int = floori(total_seconds / 60.0)
		var seconds: int = total_seconds % 60
		play_time_label.text = "遊戲時間：%02d:%02d" % [minutes, seconds]
		gold_label.text = "獲得金幣：%d" % progress_system.get_gold()
	else:
		play_time_label.text = "遊戲時間：00:00"
		gold_label.text = "獲得金幣：0"
	
	# 獲取戰鬥數據
	if combat_system:
		kill_count_label.text = "擊殺數：%d" % combat_system.get_kill_count()
		max_combo_label.text = "最大連擊：%d" % combat_system.get_max_combo()
	else:
		kill_count_label.text = "擊殺數：0"
		max_combo_label.text = "最大連擊：0"

func _on_discord_pressed() -> void:
	# 複製 Discord ID 到剪貼簿
	DisplayServer.clipboard_set(DISCORD_ID)
	
	var original_text = links_label.text
	links_label.text = "已複製使用者ID！"
	
	# 創建計時器來恢復文字
	var timer = get_tree().create_timer(2.0)
	await timer.timeout
	links_label.text = original_text

func _on_github_pressed() -> void:
	OS.shell_open(GITHUB_URL)

func _on_feedback_pressed() -> void:
	OS.shell_open(FEEDBACK_URL)

func _back_to_menu() -> void:
	if ui_system:
		ui_system.change_ui_state(ui_system.UIState.MENU, false)
		await ui_system.request_scene_transition("res://scenes/ui/main_menu.tscn")
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
