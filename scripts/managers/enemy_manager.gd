extends Node

# 普通敵人場景配置（BOSS已移到BossManager）
const enemy_scenes = {
	"chicken": preload("res://scenes/enemies/chicken.tscn"),
	"archer": preload("res://scenes/enemies/archer/archer.tscn"),
	"bird": preload("res://scenes/enemies/small_bird.tscn")
}

# Marker2D命名規則映射
const MARKER_NAME_TO_ENEMY = {
	"ChickenSpawn": "chicken",
	"ArcherSpawn": "archer", 
	"BirdSpawn": "bird"
}

var current_enemies: Array = []
var current_room_name: String = ""

func _ready() -> void:
	if not is_in_group("enemy_manager"):
		add_to_group("enemy_manager")
	
	process_mode = Node.PROCESS_MODE_INHERIT
	# 初始化完成

# 新的基於Marker2D的敵人生成系統
func spawn_enemies_for_room(room_name: String = "") -> void:
	# 為房間生成敵人
	current_room_name = room_name if room_name != "" else "unknown"
	
	# 清理現有敵人
	clear_current_enemies()
	
	# 尋找EnemySpawnPoints節點
	var enemy_spawn_points = get_tree().get_first_node_in_group("enemy_spawn_points")
	if not enemy_spawn_points:
		return
	
	# 掃描EnemySpawnPoints中的Marker2D
	_scan_and_spawn_enemies(enemy_spawn_points)

# 掃描EnemySpawnPoints中的Marker2D節點並生成敵人
func _scan_and_spawn_enemies(enemy_spawn_points: Node) -> void:
	# 直接掃描EnemySpawnPoints的子節點
	for child in enemy_spawn_points.get_children():
		# 檢查是否為Marker2D節點
		if child is Marker2D:
			var enemy_type = _get_enemy_type_from_marker_name(child.name)
			if enemy_type != "":
				_spawn_enemy_at_marker(child, enemy_type)

# 根據Marker2D名稱取得敵人類型
func _get_enemy_type_from_marker_name(marker_name: String) -> String:
	# 移除數字後綴 (例: ChickenSpawn2 -> ChickenSpawn)
	var base_name = marker_name
	var regex = RegEx.new()
	regex.compile("\\d+$")  # 匹配結尾的數字
	base_name = regex.sub(base_name, "", true)
	
	# 查找匹配的敵人類型
	for marker_pattern in MARKER_NAME_TO_ENEMY:
		if base_name == marker_pattern:
			return MARKER_NAME_TO_ENEMY[marker_pattern]
	
	return ""

# 在指定Marker2D位置生成敵人
func _spawn_enemy_at_marker(marker: Marker2D, enemy_type: String) -> void:
	if not enemy_scenes.has(enemy_type):
		# 未知的敵人類型
		return
	
	var enemy_scene = enemy_scenes[enemy_type]
	var enemy = enemy_scene.instantiate()
	
	if not enemy:
		# 無法實例化敵人
		return
	
	# 將敵人添加到地圖節點
	var main_node = get_tree().get_first_node_in_group("main")
	var map_node = main_node.get("map")
	if map_node:
		map_node.add_child(enemy)
	else:
		# 備用：添加到main節點
		main_node.add_child(enemy)
	
	enemy.global_position = marker.global_position
	current_enemies.append(enemy)
	
	# 在marker位置生成敵人

# 清理所有當前敵人
func clear_current_enemies() -> void:
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	current_enemies.clear()
	# 已清理所有敵人
