extends Node

# RewardSystem - 統一獎勵、戰利品和物品系統
# 職責：物品生成、戰利品管理、能力解鎖、獎勵處理

# 信號
signal item_collected(item: Node, item_type: String)
signal loot_collected(loot_id: String, ability_key: String)
signal respawn_system_unlocked
signal ability_unlocked(ability_key: String, ability_name: String)

# 使用配置資源
const ItemDataClass = preload("res://resources/item_configs/item_data.gd")
const RoomDataClass = preload("res://resources/room_configs/room_data.gd")

# 基本物品類型配置 (基於現有的ItemData)
const ITEM_TYPES = {
	"word": {
		"scene_path": "res://scenes/items/word.tscn",
		"min_difficulty": 1,
		"spawn_weight": 1.0
	},
	"loot": {
		"scene_path": "res://scenes/ui/loot.tscn", 
		"min_difficulty": 1,
		"spawn_weight": 1.0
	}
}

# 戰利品配置現在統一管理在 RoomDataClass 中

# 系統狀態
var _item_scene_cache = {}
var current_items = []
var collected_loot: Dictionary = {}
var respawn_system_enabled: bool = false

func _init():
	add_to_group("reward_system")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	name = "reward_system"
	_preload_item_scenes()
	_load_collected_loot()

# 物品生成系統 (來自ItemManager)
func spawn_items_for_room(room: Node2D, difficulty: int) -> void:
	clear_current_items()
	
	var spawn_point_container = room.get_node_or_null(ItemDataClass.ROOM_SPAWN_CONFIG.spawn_point_node)
	if not spawn_point_container:
		push_warning("房間缺少道具生成點容器: " + ItemDataClass.ROOM_SPAWN_CONFIG.spawn_point_node)
		return
	
	var spawn_points = spawn_point_container.get_children()
	if spawn_points.is_empty():
		return
	
	var num_items = _calculate_items_for_difficulty(difficulty)
	var max_items = min(num_items, spawn_points.size(), ItemDataClass.ROOM_SPAWN_CONFIG.max_items_per_room)
	
	for i in range(max_items):
		var item_type = _choose_item_type_for_difficulty(difficulty)
		var item = _create_item(item_type)
		if not item:
			continue
			
		item.global_position = spawn_points[i].global_position
		room.add_child(item)
		current_items.append(item)
		
		_connect_item_signals(item)

func _calculate_items_for_difficulty(difficulty: int) -> int:
	var base = ItemDataClass.SPAWN_RULES.items_per_difficulty.base
	var multiplier = ItemDataClass.SPAWN_RULES.items_per_difficulty.multiplier
	return max(ItemDataClass.ROOM_SPAWN_CONFIG.min_items_per_room, int(base + difficulty * multiplier))

func _choose_item_type_for_difficulty(difficulty: int) -> String:
	var available_types = []
	for item_type in ITEM_TYPES.keys():
		var type_data = ITEM_TYPES[item_type]
		if difficulty >= type_data.get("min_difficulty", 1):
			var weight = type_data.get("spawn_weight", 1.0)
			for i in range(int(weight * 10)):
				available_types.append(item_type)
	
	if available_types.is_empty():
		return ITEM_TYPES.keys()[0]
	
	return available_types[randi() % available_types.size()]

func _create_item(item_type: String) -> Node:
	if not ITEM_TYPES.has(item_type):
		push_error("未知的道具類型: " + item_type)
		return null
	
	var scene = _get_item_scene(item_type)
	if not scene:
		return null
	
	var item = scene.instantiate()
	if item.has_method("initialize_item"):
		item.initialize_item(item_type, ITEM_TYPES[item_type])
	
	return item

func _get_item_scene(item_type: String) -> PackedScene:
	if _item_scene_cache.has(item_type):
		return _item_scene_cache[item_type]
	
	var scene_path = ITEM_TYPES[item_type].get("scene_path", "")
	if scene_path.is_empty():
		push_error("道具類型 " + item_type + " 缺少場景路徑")
		return null
	
	if ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		_item_scene_cache[item_type] = scene
		return scene
	else:
		push_error("道具場景不存在: " + scene_path)
		return null

func _preload_item_scenes():
	for item_type in ITEM_TYPES.keys():
		_get_item_scene(item_type)

func _connect_item_signals(item: Node):
	if item.has_signal("item_collected"):
		if not item.item_collected.is_connected(_on_item_collected):
			item.item_collected.connect(_on_item_collected)

func _on_item_collected(item: Node, item_type: String):
	if item in current_items:
		current_items.erase(item)
	item_collected.emit(item, item_type)

func clear_current_items():
	for item in current_items:
		if is_instance_valid(item):
			item.queue_free()
	current_items.clear()

# 戰利品系統 (來自LootManager)
func is_loot_collected(loot_id: String) -> bool:
	return collected_loot.get(loot_id, false)

func collect_loot(loot_id: String, ability_key: String) -> void:
	if is_loot_collected(loot_id):
		return
		
	collected_loot[loot_id] = true
	
	# 處理特殊能力
	if ability_key == "respawn_unlock":
		_unlock_respawn_system()
	else:
		# 普通能力解鎖
		_unlock_player_ability(ability_key)
	
	loot_collected.emit(loot_id, ability_key)
	_save_collected_loot()

func _unlock_respawn_system():
	if not respawn_system_enabled:
		respawn_system_enabled = true
		print("重生點系統已解鎖！")
		respawn_system_unlocked.emit()
		
		# 通知RespawnManager啟用系統
		var respawn_manager = get_node_or_null("/root/RespawnManager")
		if respawn_manager and respawn_manager.has_method("enable_respawn_system"):
			respawn_manager.enable_respawn_system()

func _unlock_player_ability(ability_key: String):
	var player = PlayerSystem.get_player()
	if player and player.has_method("unlock_ability"):
		var success = player.unlock_ability(ability_key)
		if success:
			var ability_name = _get_ability_name_from_config(ability_key)
			print("能力已解鎖: ", ability_name)
			ability_unlocked.emit(ability_key, ability_name)

func _get_ability_name_from_config(ability_key: String) -> String:
	# 搜尋房間配置
	for room_path in RoomDataClass.ROOM_REWARDS:
		var room_data = RoomDataClass.ROOM_REWARDS[room_path]
		if room_data.ability_key == ability_key:
			return room_data.name
	
	# 搜尋BOSS配置
	for boss_id in RoomDataClass.BOSS_REWARDS:
		var boss_data = RoomDataClass.BOSS_REWARDS[boss_id]
		if boss_data.ability_key == ability_key:
			return boss_data.name
	
	return ability_key

func get_room_loot_config(room_scene_path: String) -> Dictionary:
	return RoomDataClass.get_room_reward(room_scene_path)

func get_boss_loot_config(boss_id: String) -> Dictionary:
	return RoomDataClass.BOSS_REWARDS.get(boss_id, {})

# 獎勵處理 (整合CombatSystem的獎勵邏輯)
func process_reward(reward_type: String, base_amount: int) -> int:
	var combat_system = get_node_or_null("/root/CombatSystem")
	if combat_system and combat_system.has_method("process_reward"):
		return combat_system.process_reward(reward_type, base_amount)
	return base_amount

func should_spawn_loot() -> bool:
	var combat_system = get_node_or_null("/root/CombatSystem")
	if combat_system and combat_system.has_method("should_spawn_loot"):
		return combat_system.should_spawn_loot()
	return false

func process_shop_purchase(item: Dictionary) -> Array:
	var combat_system = get_node_or_null("/root/CombatSystem")
	if combat_system and combat_system.has_method("process_shop_purchase"):
		return combat_system.process_shop_purchase(item)
	return []

# 遊戲不需要持久化數據，移除存檔相關方法

func _save_collected_loot():
	# 不再保存戰利品數據
	pass

func _load_collected_loot():
	# 不再載入戰利品數據
	pass

# 房間整合
func setup_room_rewards(room: Node2D, room_scene_path: String):
	# 生成房間物品
	var progress_system = get_node_or_null("/root/ProgressSystem")
	var difficulty = 1
	if progress_system and progress_system.has_method("get_current_difficulty"):
		difficulty = progress_system.get_current_difficulty()
	
	spawn_items_for_room(room, difficulty)
	
	# 檢查房間是否有特殊戰利品
	var loot_config = get_room_loot_config(room_scene_path)
	if not loot_config.is_empty():
		_setup_room_loot(room_scene_path, loot_config)

func _setup_room_loot(room_id: String, config: Dictionary):
	# 如果戰利品未收集，在房間中設置戰利品
	if not is_loot_collected(room_id):
		# 這裡可以根據需要創建視覺化的戰利品物件
		print("Room ", room_id, " has uncollected loot: ", config.name)

# 查詢方法
func is_respawn_system_enabled() -> bool:
	return respawn_system_enabled

func get_collected_loot_count() -> int:
	return collected_loot.size()

func get_available_items_count() -> int:
	return current_items.size()
