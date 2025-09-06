extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd"

const SaveManager = preload("res://addons/MetroidvaniaSystem/Template/Scripts/SaveManager.gd")
const RoomDataClass = preload("res://resources/room_configs/room_data.gd")
const SAVE_PATH = "user://metsys_save.dat"

@onready var game_player = $Player
@onready var combat_system = CombatSystem
@onready var game_manager = GameManager

var game_initializer: Node
var previous_room_name: String = ""

func _enter_tree() -> void:
	await get_tree().process_frame

func _ready():
	if not is_in_group("main"):
		add_to_group("main")
	
	if not game_player:
		return
	
	_ensure_main_singleton()
	_setup_metsys_integration()
	_initialize_game_systems()
	
	await _load_initial_room()

func _ensure_main_singleton():
	for node in get_tree().get_nodes_in_group("main"):
		if node != self:
			node.remove_from_group("main")
	add_to_group("main")

func _setup_metsys_integration():
	set_player(game_player)
	add_module("RoomTransitions.gd")
	
	if not room_loaded.is_connected(_on_room_loaded):
		room_loaded.connect(_on_room_loaded)

func _initialize_game_systems():
	game_initializer = preload("res://scripts/managers/game_initializer.gd").new()
	add_child(game_initializer)
	
	await game_initializer.initialize_game(self, game_player)

func _load_initial_room():
	# 使用配置的起始房間
	var start_room = RoomDataClass.START_ROOM
	var full_path = RoomDataClass.get_room_path(start_room)
	
	await load_room(full_path)
	RoomSystem.setup_player_position(game_player, map)
	
	await get_tree().process_frame
	await get_tree().process_frame
	RoomSystem.setup_camera_limits(game_player, map)

func _on_room_loaded():
	var current_room = MetSys.get_current_room_name() if MetSys else ""
	
	# 記錄前一個房間的退出時間（用於重入冷卻）
	if not previous_room_name.is_empty() and game_initializer:
		game_initializer.record_room_exit(previous_room_name)
	
	# 更新當前房間記錄
	previous_room_name = current_room
	
	await game_initializer.initialize_room_with_player(game_player, map)
	
	# 重置牆壁系統狀態（解決房間切換後牆壁無法重新啟動的問題）
	var wall_manager = get_node_or_null("/root/WallManager")
	if wall_manager:
		wall_manager.reset_wall_system()
	
	# 檢查並生成房間loot
	_check_and_spawn_room_loot()

func _check_and_spawn_room_loot() -> void:
	var reward_system = get_node_or_null("/root/RewardSystem")
	if not reward_system:
		return
	
	# 獲取當前房間的場景路徑
	var current_room = MetSys.get_current_room_name() if MetSys else ""
	if current_room.is_empty():
		return
	
	# 確保路徑格式正確
	var scene_path = "res://scenes/rooms/" + current_room
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"
	
	# 設置房間獎勵（物品和戰利品）
	reward_system.setup_room_rewards(get_tree().current_scene, scene_path)

func start_new_game():
	if game_manager:
		game_manager.reset_game()

func save_game():
	var save_manager := SaveManager.new()
	save_manager.store_game(self)
	save_manager.save_as_text(SAVE_PATH)

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	
	var save_manager := SaveManager.new()
	save_manager.load_from_text(SAVE_PATH)
	save_manager.retrieve_game(self)
	
	var current_room = save_manager.get_value("current_room", "")
	if current_room != "" and current_room != MetSys.get_current_room_name():
		await load_room(current_room)
	
	return true

func set_music_volume(volume: float):
	var audio_system = get_node_or_null("/root/AudioSystem")
	if audio_system:
		audio_system.set_music_volume(volume)

func set_sfx_volume(volume: float):
	var audio_system = get_node_or_null("/root/AudioSystem")
	if audio_system:
		audio_system.set_sfx_volume(volume)
