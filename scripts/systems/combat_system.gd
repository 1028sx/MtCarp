extends Node

# 戰鬥系統 - 戰鬥統計、敵人管理、BOSS管理和獎勵邏輯

# 信號
signal boss_spawned(boss_name: String, boss_position: Vector2)
signal boss_defeated_manager(boss_name: String)

# 統計數據
var kill_count := 0
var max_combo := 0
var current_combo := 0

# 獎勵系統設定
var double_rewards_chance: float = 0.0
var all_drops_once_enabled: bool = false
var all_drops_once_used: bool = false

# 敵人管理數據 (整合自EnemyManager)
const enemy_scenes = {
	"chicken": preload("res://scenes/enemies/chicken.tscn"),
	"archer": preload("res://scenes/enemies/archer/archer.tscn"),
	"bird": preload("res://scenes/enemies/small_bird.tscn")
}

const MARKER_NAME_TO_ENEMY = {
	"ChickenSpawn": "chicken",
	"ArcherSpawn": "archer", 
	"BirdSpawn": "bird"
}

var current_enemies: Array = []

# BOSS管理數據 (整合自BossManager)
const boss_scenes = {
	"boar": preload("res://scenes/enemies/boar.tscn"),
	"deer": preload("res://scenes/bosses/deer/deer.tscn"),
	"giant_fish": preload("res://scenes/bosses/giant_fish/giant_fish.tscn")
}

const MARKER_NAME_TO_BOSS = {
	"BossBoarSpawn": "boar",
	"BossDeerSpawn": "deer", 
	"BossGiantFishSpawn": "giant_fish"
}

var current_bosses: Array = []
var current_room_name: String = ""
var boss_ui: Node = null
var defeated_bosses: Dictionary = {}

func _init():
	add_to_group("combat_system")

func _ready():
	pass

# Combo 系統
func enemy_killed() -> void:
	kill_count += 1
	current_combo += 1
	if current_combo > max_combo:
		max_combo = current_combo

func reset_combo() -> void:
	current_combo = 0

# 獎勵系統設定
func set_double_rewards_chance(chance: float) -> void:
	double_rewards_chance = clamp(chance, 0.0, 1.0)

func enable_all_drops_once() -> void:
	all_drops_once_enabled = true
	all_drops_once_used = false

func disable_all_drops_once() -> void:
	all_drops_once_enabled = false
	all_drops_once_used = false

# 獎勵處理邏輯
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

# 房間重置相關效果
func reset_room_effects() -> void:
	# 重置房間相關的效果
	if all_drops_once_enabled and all_drops_once_used:
		all_drops_once_used = false

# 遊戲重置
func reset_combat_stats() -> void:
	kill_count = 0
	max_combo = 0
	current_combo = 0

# 統計數據獲取
func get_kill_count() -> int:
	return kill_count

func get_max_combo() -> int:
	return max_combo

func get_current_combo() -> int:
	return current_combo

# 遊戲不需要持久化數據，移除存檔相關方法

# ==============================================================================
# 敵人管理功能 (整合自 EnemyManager)
# ==============================================================================

func spawn_enemies_for_room(room_name: String = "") -> void:
	current_room_name = room_name if room_name != "" else "unknown"
	clear_current_enemies()
	
	var enemy_spawn_points = get_tree().get_first_node_in_group("enemy_spawn_points")
	if not enemy_spawn_points:
		return
	
	_scan_and_spawn_enemies(enemy_spawn_points)

func _scan_and_spawn_enemies(enemy_spawn_points: Node) -> void:
	for child in enemy_spawn_points.get_children():
		if child is Marker2D:
			var enemy_type = _get_enemy_type_from_marker_name(child.name)
			if enemy_type != "":
				_spawn_enemy_at_marker(child, enemy_type)

func _get_enemy_type_from_marker_name(marker_name: String) -> String:
	for marker_pattern in MARKER_NAME_TO_ENEMY:
		if marker_name.begins_with(marker_pattern):
			return MARKER_NAME_TO_ENEMY[marker_pattern]
	return ""

func _spawn_enemy_at_marker(marker: Marker2D, enemy_type: String) -> void:
	if not enemy_scenes.has(enemy_type):
		push_error("未知的敵人類型: " + enemy_type)
		return
	
	var enemy_scene = enemy_scenes[enemy_type]
	if not enemy_scene:
		push_error("無法載入敵人場景: " + enemy_type)
		return
	
	var enemy = enemy_scene.instantiate()
	if not enemy:
		push_error("無法實例化敵人: " + enemy_type)
		return
	
	enemy.global_position = marker.global_position
	
	var room_instance = MetSys.get_current_room_instance()
	if room_instance:
		room_instance.add_child(enemy)
	else:
		get_tree().root.add_child(enemy)
	
	current_enemies.append(enemy)
	
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)

func clear_current_enemies() -> void:
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	current_enemies.clear()

func _on_enemy_died(enemy: Node) -> void:
	if enemy in current_enemies:
		current_enemies.erase(enemy)
	enemy_killed()

func get_enemy_count() -> int:
	return current_enemies.size()

# ==============================================================================
# BOSS管理功能 (整合自 BossManager)
# ==============================================================================

func spawn_bosses_for_room(room_name: String = "") -> void:
	current_room_name = room_name if room_name != "" else "unknown"
	clear_current_bosses()
	
	var enemy_spawn_points = get_tree().get_first_node_in_group("enemy_spawn_points")
	if not enemy_spawn_points:
		return
	
	_scan_and_spawn_bosses(enemy_spawn_points)

func _scan_and_spawn_bosses(enemy_spawn_points: Node) -> void:
	for child in enemy_spawn_points.get_children():
		if child is Marker2D:
			var boss_type = _get_boss_type_from_marker_name(child.name)
			if boss_type != "" and not _is_boss_defeated(boss_type):
				_spawn_boss_at_marker(child, boss_type)

func _get_boss_type_from_marker_name(marker_name: String) -> String:
	for marker_pattern in MARKER_NAME_TO_BOSS:
		if marker_name.begins_with(marker_pattern):
			return MARKER_NAME_TO_BOSS[marker_pattern]
	return ""

func _spawn_boss_at_marker(marker: Marker2D, boss_type: String) -> void:
	if not boss_scenes.has(boss_type):
		push_error("未知的BOSS類型: " + boss_type)
		return
	
	var boss_scene = boss_scenes[boss_type]
	if not boss_scene:
		push_error("無法載入BOSS場景: " + boss_type)
		return
	
	var boss = boss_scene.instantiate()
	if not boss:
		push_error("無法實例化BOSS: " + boss_type)
		return
	
	boss.global_position = marker.global_position
	
	var room_instance = MetSys.get_current_room_instance()
	if room_instance:
		room_instance.add_child(boss)
	else:
		get_tree().root.add_child(boss)
	
	current_bosses.append(boss)
	
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated.bind(boss_type))
	
	boss_spawned.emit(boss_type, boss.global_position)
	_setup_boss_ui(boss)

func _setup_boss_ui(boss: Node) -> void:
	# 創建BOSS UI（如果需要）
	if not boss_ui:
		var ui_system = get_node_or_null("/root/UISystem")
		if ui_system and ui_system.has_method("create_boss_ui"):
			boss_ui = ui_system.create_boss_ui()
	
	if boss_ui and boss.has_method("get_health"):
		if boss_ui.has_method("setup_for_boss"):
			boss_ui.setup_for_boss(boss)

func _on_boss_defeated(boss_type: String) -> void:
	defeated_bosses[boss_type] = true
	boss_defeated_manager.emit(boss_type)
	
	# 清理BOSS UI
	if boss_ui:
		if boss_ui.has_method("hide_boss_ui"):
			boss_ui.hide_boss_ui()
	
	# 處理BOSS戰利品
	var reward_system = get_node_or_null("/root/RewardSystem")
	if reward_system and reward_system.has_method("collect_loot"):
		var boss_config = reward_system.get_boss_loot_config(boss_type)
		if not boss_config.is_empty():
			var loot_id = "boss_" + boss_type
			reward_system.collect_loot(loot_id, boss_config.ability_key)

func clear_current_bosses() -> void:
	for boss in current_bosses:
		if is_instance_valid(boss):
			boss.queue_free()
	current_bosses.clear()

func _is_boss_defeated(boss_type: String) -> bool:
	return defeated_bosses.get(boss_type, false)

func get_boss_count() -> int:
	return current_bosses.size()

func get_defeated_bosses() -> Dictionary:
	return defeated_bosses.duplicate()

# 房間統一生成方法
func spawn_all_enemies_and_bosses_for_room(room_name: String = "") -> void:
	spawn_enemies_for_room(room_name)
	spawn_bosses_for_room(room_name)

# 統一清理方法
func clear_all_combat_entities() -> void:
	clear_current_enemies()
	clear_current_bosses()
