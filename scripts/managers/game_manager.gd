extends Node

# Preload the PlayerGlobal script resource to call static functions from the type
const PlayerGlobalScript = preload("res://scripts/globals/PlayerGlobal.gd")

# 遊戲狀態
enum GameState {MENU, PLAYING, PAUSED, GAME_OVER}
var current_state = GameState.MENU

# 遊戲進度
var current_level = 1
var current_difficulty = 1
var score = 0
var gold = 0

# 遊戲設置
var music_volume = 1.0
var sfx_volume = 1.0

# 信號
signal difficulty_changed(new_difficulty)
signal score_changed(new_score)
signal gold_changed(new_gold)
signal level_changed(new_level)

# 音頻播放器引用
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

const GameOverScreenScene = preload("res://scenes/ui/game_over_screen.tscn") # ADDED: Preload GameOverScreen
var game_over_screen_instance = null # ADDED: Instance variable for GameOverScreen

var _is_player_died_connected := false
# var _is_player_fully_died_connected := false # 新增標誌給新的信號 # REMOVED
var _is_player_fully_died_signal_connected := false # ADDED: Flag for player_fully_died connection
var _game_over_initiated := false # ADDED: Flag to ensure game_over logic runs once
# var _current_player_instance_id_connected_fully_died: int = 0 # REMOVED as it's no longer used

var double_rewards_chance: float = 0.0
var all_drops_once_enabled: bool = false
var all_drops_once_used: bool = false

# 重生點數據
var respawn_data: Dictionary = {}

# 添加統計數據變量
var play_time := 0.0
var kill_count := 0
var max_combo := 0
var current_combo := 0

func set_double_rewards_chance(chance: float) -> void:
	double_rewards_chance = clamp(chance, 0.0, 1.0)

func enable_all_drops_once() -> void:
	all_drops_once_enabled = true
	all_drops_once_used = false

func disable_all_drops_once() -> void:
	all_drops_once_enabled = false
	all_drops_once_used = false

func _ready():
	music_player = get_node_or_null("MusicPlayer")
	sfx_player = get_node_or_null("SFXPlayer")
	add_to_group("game_manager")
	name = "game_manager"

	# 使用 PlayerGlobal 連接玩家信號
	if PlayerGlobal:
		if PlayerGlobalScript.is_player_available():
			_connect_to_player_signals(PlayerGlobalScript.get_player())
		if not PlayerGlobal.player_registration_changed.is_connected(_on_player_registration_changed):
			PlayerGlobal.player_registration_changed.connect(_on_player_registration_changed)
	
	load_settings()
	
	var room_manager = get_node_or_null("/root/RoomManager")
	if room_manager and room_manager.has_signal("room_changed"):
		if not room_manager.room_changed.is_connected(reset_room_effects):
			room_manager.room_changed.connect(reset_room_effects)

func _on_player_fully_died_trigger() -> void:
	# 根據是否有重生點決定後續處理
	var respawn_manager = get_node_or_null("/root/RespawnManager")
	if respawn_manager and respawn_manager.has_active_respawn_point():
		# 有重生點，執行重生
		respawn_manager.respawn_player()
	else:
		# 沒有重生點，執行遊戲結束
		if not _game_over_initiated:
			_game_over_initiated = true
			game_over()

func start_game():
	current_state = GameState.PLAYING
	reset_game_progress()
	if music_player:
		music_player.play()

func pause_game():
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true

func resume_game():
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false

func reset_game_progress():
	current_level = 1
	current_difficulty = 1
	score = 0
	gold = 0
	emit_signal("level_changed", current_level)
	emit_signal("difficulty_changed", current_difficulty)
	emit_signal("score_changed", score)
	emit_signal("gold_changed", gold)

func increase_difficulty():
	current_difficulty += 1

func add_score(points):
	score += points

func add_gold(amount):
	gold += amount

func next_level():
	current_level += 1

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0, 1)
	if music_player:
		music_player.volume_db = linear_to_db(music_volume)
	save_settings()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0, 1)
	if sfx_player:
		sfx_player.volume_db = linear_to_db(sfx_volume)
	save_settings()

func save_settings():
	var settings = {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume
	}
	var file = FileAccess.open("user://settings.save", FileAccess.WRITE)
	file.store_var(settings)
	file.close()

func load_settings():
	if FileAccess.file_exists("user://settings.save"):
		var file = FileAccess.open("user://settings.save", FileAccess.READ)
		var settings = file.get_var()
		file.close()
		if settings:
			set_music_volume(settings.get("music_volume", 1.0))
			set_sfx_volume(settings.get("sfx_volume", 1.0))

func save_game():
	var save_data = {
		"level": current_level,
		"difficulty": current_difficulty,
		"score": score,
		"gold": gold,
		"respawn_data": respawn_data
	}
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	file.store_var(save_data)
	file.close()

func load_game():
	if FileAccess.file_exists("user://savegame.save"):
		var file = FileAccess.open("user://savegame.save", FileAccess.READ)
		var save_data = file.get_var()
		file.close()
		if save_data:
			current_level = save_data.get("level", 1)
			current_difficulty = save_data.get("difficulty", 1)
			score = save_data.get("score", 0)
			gold = save_data.get("gold", 0)
			respawn_data = save_data.get("respawn_data", {})
			emit_signal("level_changed", current_level)
			emit_signal("difficulty_changed", current_difficulty)
			emit_signal("score_changed", score)
			emit_signal("gold_changed", gold)
			
			# 恢復重生點數據
			var respawn_manager = get_node_or_null("/root/RespawnManager")
			if respawn_manager:
				respawn_manager.load_respawn_data()
			return true
	return false

func play_sound(sound_name: String):
	if sfx_player:
		var sound = load("res://assets/sounds/" + sound_name + ".wav")
		if sound:
			sfx_player.stream = sound
			sfx_player.play()

func process_reward(reward_type: String, base_amount: int) -> int:
	var final_amount = base_amount
	
	# 檢查殺雞取卵效果
	if reward_type == "loot":
		if all_drops_once_enabled:
			if all_drops_once_used:
				return 0
			all_drops_once_used = true
			final_amount *= 2
	
	# 檢查是否需要雙倍獎勵
	if randf() < double_rewards_chance:
		final_amount *= 2
		
	return final_amount

func should_spawn_loot() -> bool:
	if all_drops_once_enabled:
		if all_drops_once_used:
			return false
		return true
	return true

func process_shop_purchase(item: Dictionary) -> Array:
	var rewards = [item]  # 基礎獎勵必定包含購買的物品
	
	# 檢查是否觸發雙倍獎勵
	if randf() < double_rewards_chance:
		rewards.append(item.duplicate())  # 添加一個相同物品的副本
	
	return rewards

func process_loot_effect(effect) -> void:
	# 檢查效果是否為字符串，如果是則轉換為字典
	var effect_dict = {}
	if effect is String:
		effect_dict = {"effect": effect}
	elif effect is Dictionary:
		effect_dict = effect
	else:
		return
	
	# 獲取玩家引用
	
	var player = PlayerGlobalScript.get_player()

	if not player or not player.has_method("apply_effect"):
		return
	
	# 應用效果到玩家
	player.apply_effect(effect_dict)

func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta

func enemy_killed() -> void:
	kill_count += 1
	current_combo += 1
	if current_combo > max_combo:
		max_combo = current_combo

func reset_combo() -> void:
	current_combo = 0

func game_over() -> void:
	# 進入遊戲結束邏輯（沒有重生點的情況）
	get_tree().paused = true
	current_state = GameState.GAME_OVER
	
	if music_player:
		music_player.stop()
	
	if sfx_player:
		sfx_player.stream = load("res://assets/sounds/game_over.wav")
		sfx_player.play()
	
	if not is_inside_tree():
		return

	# 實例化並顯示 GameOverScreen
	if not is_instance_valid(game_over_screen_instance):
		game_over_screen_instance = GameOverScreenScene.instantiate()
		var main_scene = get_tree().root.get_node_or_null("Main")
		if main_scene:
			main_scene.add_child(game_over_screen_instance)
		else:
			get_tree().root.add_child(game_over_screen_instance)

	if is_instance_valid(game_over_screen_instance):
		if not game_over_screen_instance.is_inside_tree():
			var main_scene = get_tree().root.get_node_or_null("Main")
			if main_scene:
				main_scene.add_child(game_over_screen_instance)
			else:
				get_tree().root.add_child(game_over_screen_instance)
		
		game_over_screen_instance.show_screen()

# 玩家信號連接函數
func _connect_to_player_signals(player_node: CharacterBody2D) -> void:
	if is_instance_valid(player_node):
		# 斷開舊的 died 信號連接 (如果存在且已連接到舊的處理函數)
		if player_node.has_signal("died") and _is_player_died_connected:
			_is_player_died_connected = false # 標記為未連接，因為我們不再使用這個信號了

		# 連接 player_fully_died 信號
		if player_node.has_signal("player_fully_died"):
			if player_node.player_fully_died.is_connected(_on_player_fully_died_trigger):
				if not _is_player_fully_died_signal_connected:
					_is_player_fully_died_signal_connected = true
			else:
				var error_code = player_node.player_fully_died.connect(_on_player_fully_died_trigger)
				if error_code == OK:
					_is_player_fully_died_signal_connected = true
				else:
					_is_player_fully_died_signal_connected = false


func _on_player_registration_changed(is_registered: bool) -> void:
	if is_registered:
		var player_node = PlayerGlobalScript.get_player()
		if is_instance_valid(player_node):
			_connect_to_player_signals(player_node)
	else:
		# 玩家註銷了，重置連接標誌
		_is_player_fully_died_signal_connected = false
		
		# 當玩家註銷時（例如返回主選單或重新開始關卡），重置 game_over_initiated 標誌
		_game_over_initiated = false 
		
		cleanup_game_over_screen()

func reset_game() -> void:
	play_time = 0.0
	kill_count = 0
	max_combo = 0
	current_combo = 0
	gold = 0

func reset_room_effects() -> void:
	# 重置房間相關的效果
	if all_drops_once_enabled and all_drops_once_used:
		all_drops_once_used = false

func cleanup_game_over_screen() -> void:
	if is_instance_valid(game_over_screen_instance):
		game_over_screen_instance.queue_free()
		game_over_screen_instance = null

# 重生點數據管理
func set_respawn_data(data: Dictionary) -> void:
	respawn_data = data

func get_respawn_data() -> Dictionary:
	return respawn_data
