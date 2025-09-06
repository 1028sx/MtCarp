extends Node

# 系統引用
var game_core: Node
var audio_system: Node
var progress_system: Node
var ui_system: Node
var combat_system: Node
var room_system: Node
var reward_system: Node

# 向後兼容的委託信號 (保留給依賴 GameManager 的舊代碼)
signal level_changed(new_level)
signal difficulty_changed(new_difficulty)
signal score_changed(new_score)
signal gold_changed(new_gold)

func _ready():
	name = "game_manager"
	add_to_group("game_manager")
	
	# 獲取系統引用
	_initialize_system_references()
	
	# 連接系統信號進行向後兼容
	_connect_system_signals()

func _initialize_system_references():
	game_core = get_node_or_null("/root/GameCore")
	audio_system = get_node_or_null("/root/AudioSystem")
	progress_system = get_node_or_null("/root/ProgressSystem")
	ui_system = get_node_or_null("/root/UISystem")
	combat_system = get_node_or_null("/root/CombatSystem")
	room_system = get_node_or_null("/root/RoomSystem")
	reward_system = get_node_or_null("/root/RewardSystem")

func _connect_system_signals():
	# 連接進度系統信號進行向後兼容
	if progress_system:
		if not progress_system.level_changed.is_connected(_on_level_changed):
			progress_system.level_changed.connect(_on_level_changed)
		if not progress_system.difficulty_changed.is_connected(_on_difficulty_changed):
			progress_system.difficulty_changed.connect(_on_difficulty_changed)
		if not progress_system.score_changed.is_connected(_on_score_changed):
			progress_system.score_changed.connect(_on_score_changed)
		if not progress_system.gold_changed.is_connected(_on_gold_changed):
			progress_system.gold_changed.connect(_on_gold_changed)

# 信號轉發 (向後兼容)
func _on_level_changed(new_level: int):
	level_changed.emit(new_level)

func _on_difficulty_changed(new_difficulty: int):
	difficulty_changed.emit(new_difficulty)

func _on_score_changed(new_score: int):
	score_changed.emit(new_score)

func _on_gold_changed(new_gold: int):
	gold_changed.emit(new_gold)

# ==============================================================================
# 高層遊戲流程控制
# ==============================================================================

func start_game():
	if game_core and game_core.has_method("start_game"):
		game_core.start_game()

func pause_game():
	if game_core and game_core.has_method("pause_game"):
		game_core.pause_game()

func resume_game():
	if game_core and game_core.has_method("resume_game"):
		game_core.resume_game()

func game_over():
	if game_core and game_core.has_method("game_over"):
		game_core.game_over()

# ==============================================================================
# 向後兼容的委託方法 (將調用委託給適當的系統)
# ==============================================================================

# 進度系統委託
func get_score() -> int:
	return progress_system.get_score() if progress_system else 0

func get_gold() -> int:
	return progress_system.get_gold() if progress_system else 0

# 音頻系統委託
func set_music_volume(volume: float):
	if audio_system and audio_system.has_method("set_music_volume"):
		audio_system.set_music_volume(volume)

func set_sfx_volume(volume: float):
	if audio_system and audio_system.has_method("set_sfx_volume"):
		audio_system.set_sfx_volume(volume)


# 重生點系統委託 (通過房間系統)
func set_respawn_data(data: Dictionary):
	if room_system and room_system.has_method("set_respawn_data"):
		room_system.set_respawn_data(data)

func get_respawn_data() -> Dictionary:
	if room_system and room_system.has_method("get_respawn_data"):
		return room_system.get_respawn_data()
	return {}

# ==============================================================================
# 系統協調和初始化
# ==============================================================================

func initialize_new_game():
	# 初始化新遊戲
	if progress_system and progress_system.has_method("start_new_game"):
		progress_system.start_new_game()
	
	if combat_system and combat_system.has_method("reset_combat_stats"):
		combat_system.reset_combat_stats()

func initialize_room(room_name: String):
	# 協調房間初始化
	if combat_system:
		if combat_system.has_method("spawn_all_enemies_and_bosses_for_room"):
			combat_system.spawn_all_enemies_and_bosses_for_room(room_name)
	
	if reward_system:
		if reward_system.has_method("setup_room_rewards"):
			var room_scene_path = "res://scenes/rooms/" + room_name + ".tscn"
			reward_system.setup_room_rewards(null, room_scene_path)

# 系統狀態查詢
func is_system_ready() -> bool:
	return game_core != null and audio_system != null and progress_system != null

func get_system_status() -> Dictionary:
	return {
		"game_core": game_core != null,
		"audio_system": audio_system != null,
		"progress_system": progress_system != null,
		"ui_system": ui_system != null,
		"combat_system": combat_system != null,
		"room_system": room_system != null,
		"reward_system": reward_system != null
	}
