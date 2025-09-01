extends Node

# BOSS場景配置
const boss_scenes = {
	"boar": preload("res://scenes/enemies/boar.tscn"),
	"deer": preload("res://scenes/bosses/deer/deer.tscn"),
	"giant_fish": preload("res://scenes/bosses/giant_fish/giant_fish.tscn")
}

# BOSS Marker2D命名規則映射
const MARKER_NAME_TO_BOSS = {
	"BossBoarSpawn": "boar",
	"BossDeerSpawn": "deer", 
	"BossGiantFishSpawn": "giant_fish"
}

var current_bosses: Array = []
var current_room_name: String = ""
var boss_ui: Node = null

func _ready() -> void:
	if not is_in_group("boss_manager"):
		add_to_group("boss_manager")
	
	process_mode = Node.PROCESS_MODE_INHERIT
	# BOSS管理器初始化完成

# 為房間生成BOSS（基於Marker2D）
func spawn_bosses_for_room(room_name: String = "") -> void:
	current_room_name = room_name if room_name != "" else "unknown"
	clear_current_bosses()
	
	var enemy_spawn_points = get_tree().get_first_node_in_group("enemy_spawn_points")
	if not enemy_spawn_points:
		return
	
	_scan_and_spawn_bosses(enemy_spawn_points)

# 掃描EnemySpawnPoints中的BOSS Marker2D節點
func _scan_and_spawn_bosses(enemy_spawn_points: Node) -> void:
	var spawn_count = 0
	
	# 直接掃描EnemySpawnPoints的子節點，尋找BOSS
	for child in enemy_spawn_points.get_children():
		if child is Marker2D:
			var boss_type = _get_boss_type_from_marker_name(child.name)
			if boss_type != "":
				_spawn_boss_at_marker(child, boss_type)
				spawn_count += 1
	
	if spawn_count > 0:
		_show_boss_ui()

# 根據Marker2D名稱取得BOSS類型
func _get_boss_type_from_marker_name(marker_name: String) -> String:
	# 移除數字後綴 (例: BossBoar2 -> BossBoar)
	var base_name = marker_name
	var regex = RegEx.new()
	regex.compile("\\d+$")
	base_name = regex.sub(base_name, "", true)
	
	# 查找匹配的BOSS類型
	for marker_pattern in MARKER_NAME_TO_BOSS:
		if base_name == marker_pattern:
			return MARKER_NAME_TO_BOSS[marker_pattern]
	
	return ""

# 在指定Marker2D位置生成BOSS
func _spawn_boss_at_marker(marker: Marker2D, boss_type: String) -> void:
	if not boss_scenes.has(boss_type):
		return
	
	var boss_scene = boss_scenes[boss_type]
	var boss = boss_scene.instantiate()
	
	if not boss:
		return
	
	# 將BOSS添加到地圖節點
	var main_node = get_tree().get_first_node_in_group("main")
	var map_node = main_node.get("map")
	if map_node:
		map_node.add_child(boss)
	else:
		main_node.add_child(boss)
	
	boss.global_position = marker.global_position
	current_bosses.append(boss)
	
	# 連接BOSS死亡信號
	if boss.has_signal("boss_defeated"):
		if not boss.boss_defeated.is_connected(_on_boss_defeated):
			boss.boss_defeated.connect(_on_boss_defeated.bind(boss))

# 顯示BOSS UI
func _show_boss_ui() -> void:
	boss_ui = get_tree().get_first_node_in_group("boss_ui")
	if boss_ui and boss_ui.has_method("show"):
		boss_ui.show()
	elif boss_ui:
		boss_ui.visible = true

# 隱藏BOSS UI
func _hide_boss_ui() -> void:
	if boss_ui and boss_ui.has_method("hide"):
		boss_ui.hide()
	elif boss_ui:
		boss_ui.visible = false

# BOSS死亡回調
func _on_boss_defeated(boss) -> void:
	if not is_instance_valid(boss):
		return
	
	if boss in current_bosses:
		current_bosses.erase(boss)
		
		# 檢查是否所有BOSS都被擊敗
		if current_bosses.is_empty():
			_hide_boss_ui()

# 清理所有當前BOSS
func clear_current_bosses() -> void:
	for boss in current_bosses:
		if is_instance_valid(boss):
			boss.queue_free()
	
	current_bosses.clear()
	_hide_boss_ui()
