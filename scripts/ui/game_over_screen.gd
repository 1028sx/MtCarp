extends Control

@onready var play_time_label = $CenterContainer/VBoxContainer/VBoxContainer_Stats/Label_PlayTime
@onready var kill_count_label = $CenterContainer/VBoxContainer/VBoxContainer_Stats/Label_KillCount
@onready var max_combo_label = $CenterContainer/VBoxContainer/VBoxContainer_Stats/Label_MaxCombo
@onready var gold_label = $CenterContainer/VBoxContainer/VBoxContainer_Stats/Label_Gold
@onready var links_label = $CenterContainer/VBoxContainer/HBoxContainer_Links/Label

const DISCORD_ID = "613878521898598531"  # 替換成您的 Discord ID
const GITHUB_URL = "https://github.com/1028sx/graduation_project"
const FEEDBACK_URL = "https://forms.gle/GzWnzdix2vK2M4747"

func _ready() -> void:
	# 初始時隱藏
	hide()
	# 確保在暫停時仍能運作
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 設置按鈕信號
	var discord_button = $CenterContainer/VBoxContainer/HBoxContainer_Links/Button_Discord
	var github_button = $CenterContainer/VBoxContainer/HBoxContainer_Links/Button_GitHub
	var feedback_button = $CenterContainer/VBoxContainer/HBoxContainer_Links/Button_Feedback
	
	discord_button.pressed.connect(_on_discord_pressed)
	github_button.pressed.connect(_on_github_pressed)
	feedback_button.pressed.connect(_on_feedback_pressed)

func show_screen() -> void:
	# 顯示統計數據
	_update_stats()
	# 顯示畫面
	show()
	# 確保遊戲暫停
	get_tree().paused = true

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):  # Esc 鍵
		_back_to_menu()
		get_viewport().set_input_as_handled()

func _update_stats() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		# 格式化遊戲時間
		var total_seconds: int = int(game_manager.play_time)
		var minutes: int = floori(total_seconds / 60.0)
		var seconds: int = total_seconds % 60
		play_time_label.text = "遊戲時間：%02d:%02d" % [minutes, seconds]
		
		# 更新其他統計數據
		kill_count_label.text = "擊殺數：%d" % game_manager.kill_count
		max_combo_label.text = "最大連擊：%d" % game_manager.max_combo
		gold_label.text = "獲得金幣：%d" % game_manager.gold

func _on_discord_pressed() -> void:
	# 複製 Discord ID 到剪貼簿
	DisplayServer.clipboard_set(DISCORD_ID)
	
	# 更新提示文字
	var original_text = links_label.text
	links_label.text = "已複製使用者ID！"
	
	# 創建一個計時器來恢復文字
	var timer = get_tree().create_timer(2.0)  # 2秒後恢復
	await timer.timeout
	links_label.text = original_text

func _on_github_pressed() -> void:
	var error = OS.shell_open(GITHUB_URL)
	if error != OK:
		links_label.text = "無法開啟 GitHub 連結"
		var timer = get_tree().create_timer(2.0)
		await timer.timeout
		links_label.text = ""

func _on_feedback_pressed() -> void:
	var error = OS.shell_open(FEEDBACK_URL)
	if error != OK:
		links_label.text = "無法開啟回饋表單連結"
		var timer = get_tree().create_timer(2.0)
		await timer.timeout
		links_label.text = ""

func _back_to_menu() -> void:
	get_tree().paused = false  # 取消暫停
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
