extends Node

# GameCore - 輕量級遊戲狀態機和流程控制
# 職責：遊戲狀態管理、基本流程控制、玩家死亡處理

# 遊戲狀態
enum GameState {MENU, PLAYING, PAUSED, GAME_OVER}
var current_state = GameState.MENU

# 信號
signal game_state_changed(new_state: GameState)
signal player_death_handled
signal game_over_triggered

# 玩家連接狀態
var _is_player_fully_died_signal_connected := false
var _game_over_initiated := false

const GameOverScreenScene = preload("res://scenes/ui/game_over_screen.tscn")
var game_over_screen_instance = null

func _init():
	add_to_group("game_core")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready():
	name = "game_core"
	
	# 連接玩家信號
	_setup_player_connections()
	
	# 連接房間變更信號用於重置效果
	var room_system = get_node_or_null("/root/RoomSystem")
	if room_system and room_system.has_signal("room_changed"):
		if not room_system.room_changed.is_connected(_on_room_changed):
			room_system.room_changed.connect(_on_room_changed)

func _setup_player_connections():
	if PlayerSystem:
		if PlayerSystem.is_player_available():
			_connect_to_player_signals(PlayerSystem.get_player())
		if not PlayerSystem.player_registration_changed.is_connected(_on_player_registration_changed):
			PlayerSystem.player_registration_changed.connect(_on_player_registration_changed)

# 核心遊戲狀態控制
func start_game():
	if current_state != GameState.PLAYING:
		current_state = GameState.PLAYING
		_game_over_initiated = false
		game_state_changed.emit(current_state)
		
		# 通知其他系統開始遊戲
		var progress_system = get_node_or_null("/root/ProgressSystem")
		if progress_system and progress_system.has_method("reset_progress"):
			progress_system.reset_progress()
		
		var audio_system = get_node_or_null("/root/AudioSystem")
		if audio_system and audio_system.has_method("start_background_music"):
			audio_system.start_background_music()

func pause_game():
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_state_changed.emit(current_state)

func resume_game():
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_state_changed.emit(current_state)

func game_over() -> void:
	if _game_over_initiated:
		return
		
	_game_over_initiated = true
	get_tree().paused = true
	current_state = GameState.GAME_OVER
	game_state_changed.emit(current_state)
	
	# 通知音頻系統
	var audio_system = get_node_or_null("/root/AudioSystem")
	if audio_system:
		if audio_system.has_method("stop_background_music"):
			audio_system.stop_background_music()
		if audio_system.has_method("play_game_over_sound"):
			audio_system.play_game_over_sound()
	
	# 顯示遊戲結束畫面
	_show_game_over_screen()
	game_over_triggered.emit()

func return_to_menu():
	current_state = GameState.MENU
	get_tree().paused = false
	_game_over_initiated = false
	_cleanup_game_over_screen()
	game_state_changed.emit(current_state)

# 玩家死亡處理邏輯
func _on_player_fully_died_trigger() -> void:
	var respawn_manager = get_node_or_null("/root/RespawnManager")
	if respawn_manager and respawn_manager.has_method("has_active_respawn_point") and respawn_manager.has_active_respawn_point():
		# 延遲確保狀態清理完成
		await get_tree().create_timer(0.5).timeout
		if respawn_manager.has_method("respawn_player"):
			respawn_manager.respawn_player()
		player_death_handled.emit()
	else:
		# 沒有重生點，觸發遊戲結束
		game_over()

# 玩家信號連接
func _connect_to_player_signals(player_node: CharacterBody2D) -> void:
	if not is_instance_valid(player_node):
		return
		
	if player_node.has_signal("player_fully_died"):
		if not player_node.player_fully_died.is_connected(_on_player_fully_died_trigger):
			var error_code = player_node.player_fully_died.connect(_on_player_fully_died_trigger)
			_is_player_fully_died_signal_connected = (error_code == OK)

func _on_player_registration_changed(is_registered: bool) -> void:
	if is_registered:
		var player_node = PlayerSystem.get_player()
		if is_instance_valid(player_node):
			_connect_to_player_signals(player_node)
	else:
		_is_player_fully_died_signal_connected = false
		_game_over_initiated = false
		_cleanup_game_over_screen()

# 房間變更處理
func _on_room_changed() -> void:
	# 通知戰鬥系統重置房間效果
	var combat_system = get_node_or_null("/root/CombatSystem")
	if combat_system and combat_system.has_method("reset_room_effects"):
		combat_system.reset_room_effects()

# 遊戲結束畫面管理
func _show_game_over_screen() -> void:
	if not is_inside_tree():
		return
		
	if not is_instance_valid(game_over_screen_instance):
		game_over_screen_instance = GameOverScreenScene.instantiate()
		var main_scene = get_tree().root.get_node_or_null("Main")
		if main_scene:
			main_scene.add_child(game_over_screen_instance)
		else:
			get_tree().root.add_child(game_over_screen_instance)
	
	if is_instance_valid(game_over_screen_instance) and game_over_screen_instance.has_method("show_screen"):
		game_over_screen_instance.show_screen()

func _cleanup_game_over_screen() -> void:
	if is_instance_valid(game_over_screen_instance):
		game_over_screen_instance.queue_free()
		game_over_screen_instance = null

# 狀態查詢
func is_playing() -> bool:
	return current_state == GameState.PLAYING

func is_paused() -> bool:
	return current_state == GameState.PAUSED

func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER

func get_game_state() -> GameState:
	return current_state
