extends Node

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
# 暫時註釋掉未使用的信號
# signal difficulty_changed(new_difficulty)
# signal score_changed(new_score)
# signal gold_changed(new_gold)
# signal level_changed(new_level)

# 音頻播放器引用
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var double_rewards_chance: float = 0.0
var all_drops_once_enabled: bool = false
var all_drops_once_used: bool = false

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
	name = "game_manager"  # 確保名稱正確
	
	# 連接玩家信號
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("died") and not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
	else:
		print("[GameManager] 警告：找不到玩家節點")
	
	# 初始化遊戲設置
	load_settings()
	
	# 連接房間管理器信號
	var room_manager = get_node_or_null("/root/RoomManager")
	if room_manager and room_manager.has_signal("room_changed"):
		if not room_manager.room_changed.is_connected(reset_room_effects):
			room_manager.room_changed.connect(reset_room_effects)

func _on_player_died():
	game_over()

func start_game():
	current_state = GameState.PLAYING
	reset_game_progress()
	# 開始播放背景音樂
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
		"gold": gold
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
			emit_signal("level_changed", current_level)
			emit_signal("difficulty_changed", current_difficulty)
			emit_signal("score_changed", score)
			emit_signal("gold_changed", gold)
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
	var player = get_tree().get_first_node_in_group("player")
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
	get_tree().paused = true
	current_state = GameState.GAME_OVER
	
	# 停止背景音樂，播放遊戲結束音效
	if music_player:
		music_player.stop()
	
	if sfx_player:
		sfx_player.stream = load("res://assets/sounds/game_over.wav")
		sfx_player.play()
	
	# 通過 UI 節點獲取遊戲結束畫面
	var ui = get_tree().get_first_node_in_group("ui")
	if ui:
		var game_over_screen = ui.get_node_or_null("GameOverScreen")
		if game_over_screen:
			game_over_screen.show_screen()

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
