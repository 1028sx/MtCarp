extends FieldControllerBase

class_name BubbleFieldController

## 泡泡場地控制系統
## 實現四種智能場地控制模式，反制玩家距離保持策略

#region 場地控制模式
enum BubblePattern { 
	SIDE_SPRAY,     # 從左右邊緣噴出一串泡泡
	TOP_SCATTER,    # 從上方隨機散落泡泡
	CORNER_ADVANCE, # 從角落推進
	CENTER_BURST    # 中心爆發
}
#endregion

#region 導出屬性
@export_group("泡泡模式配置")
@export var bubble_scene: PackedScene
@export var side_spray_count: int = 6
@export var top_scatter_count: int = 8  
@export var corner_advance_count: int = 5
@export var center_burst_count: int = 12

@export_group("模式參數")
@export var bubble_spacing: float = 80.0
@export var spawn_delay_min: float = 0.1
@export var spawn_delay_max: float = 0.8
@export var pattern_weights: Array[float] = [1.0, 1.0, 1.0, 1.0]  # 各模式權重
#endregion

#region 地圖邊界
var map_bounds: Rect2
var map_bounds_calculated: bool = false
#endregion

func _ready():
	super._ready()

func initialize(boss: Node2D, player: Node2D, spawnable_mgr: Node):
	super.initialize(boss, player, spawnable_mgr)
	
	# 計算地圖邊界
	_calculate_map_bounds()

func select_field_control_pattern() -> String:
	"""根據玩家位置和戰術需要選擇場地控制模式"""
	if not target_player or not boss_node:
		return ""
	
	var player_pos = get_player_position()
	var distance = get_distance_to_player()
	
	# 智能模式選擇邏輯
	var available_patterns = []
	
	# SIDE_SPRAY: 玩家在地圖中央時使用
	if _is_player_in_center(player_pos):
		available_patterns.append("SIDE_SPRAY")
	
	# TOP_SCATTER: 玩家保持高距離時使用
	if distance > trigger_distance * 1.2:
		available_patterns.append("TOP_SCATTER")
	
	# CORNER_ADVANCE: 玩家在角落時使用
	if _is_player_in_corner(player_pos):
		available_patterns.append("CORNER_ADVANCE")
	
	# CENTER_BURST: 通用模式，總是可用
	available_patterns.append("CENTER_BURST")
	
	# 避免重複使用相同模式
	if last_pattern_used in available_patterns and available_patterns.size() > 1:
		available_patterns.erase(last_pattern_used)
	
	# 隨機選擇
	if available_patterns.size() > 0:
		return available_patterns[randi() % available_patterns.size()]
	
	return "CENTER_BURST"  # 保底模式

func trigger_field_control(pattern_name: String) -> bool:
	"""觸發指定的場地控制模式"""
	if not super.trigger_field_control(pattern_name):
		return false
	
	
	# 執行具體模式
	match pattern_name:
		"SIDE_SPRAY":
			_execute_side_spray()
		"TOP_SCATTER":
			_execute_top_scatter()
		"CORNER_ADVANCE":
			_execute_corner_advance()
		"CENTER_BURST":
			_execute_center_burst()
		_:
			return false
	
	return true

#region 具體模式實現
func _execute_side_spray():
	"""從左右邊緣噴出一串泡泡"""
	var player_pos = get_player_position()
	var boss_pos = get_boss_position()
	
	# 選擇遠離玩家的邊緣
	var spawn_side_x = map_bounds.position.x if player_pos.x > boss_pos.x else map_bounds.position.x + map_bounds.size.x
	
	
	# 垂直排列泡泡
	for i in range(side_spray_count):
		var spawn_pos = Vector2(spawn_side_x, boss_pos.y - 200 + i * bubble_spacing)
		var direction = Vector2(1.0 if spawn_side_x < boss_pos.x else -1.0, 0)
		
		# 延遲生成以創造噴射效果
		await get_tree().create_timer(i * 0.15).timeout
		_spawn_independent_bubble(spawn_pos, direction)
	
	# 模式完成
	await get_tree().create_timer(1.0).timeout
	on_field_control_completed("SIDE_SPRAY")

func _execute_top_scatter():
	"""從上方隨機散落泡泡"""
	var player_pos = get_player_position()
	var scatter_area = 500.0  # 散落區域寬度
	
	
	for i in range(top_scatter_count):
		# 在玩家周圍隨機位置
		var random_x = player_pos.x + randf_range(-scatter_area/2, scatter_area/2)
		var spawn_pos = Vector2(random_x, player_pos.y - 400)
		var direction = Vector2(randf_range(-0.5, 0.5), 1.0).normalized()
		
		# 隨機延遲
		await get_tree().create_timer(randf_range(0.1, 0.6)).timeout
		_spawn_independent_bubble(spawn_pos, direction)
	
	await get_tree().create_timer(1.5).timeout
	on_field_control_completed("TOP_SCATTER")

func _execute_corner_advance():
	"""從角落推進"""
	var player_pos = get_player_position()
	
	# 選擇最近的角落
	var corner_pos = _get_nearest_corner(player_pos)
	
	
	for i in range(corner_advance_count):
		var progress = float(i) / float(corner_advance_count - 1)
		var spawn_pos = corner_pos.lerp(player_pos, progress * 0.7)  # 推進到玩家70%位置
		var direction = (player_pos - corner_pos).normalized()
		
		await get_tree().create_timer(0.25).timeout
		_spawn_independent_bubble(spawn_pos, direction)
	
	await get_tree().create_timer(1.2).timeout
	on_field_control_completed("CORNER_ADVANCE")

func _execute_center_burst():
	"""中心爆發"""
	var boss_pos = get_boss_position()
	
	
	# 180度上半圓分佈（-90度到+90度），避免向地面生成泡泡
	var angle_step = 180.0 / center_burst_count
	var start_angle = -90.0  # 從左側開始
	
	for i in range(center_burst_count):
		var angle = deg_to_rad(start_angle + i * angle_step)
		var direction = Vector2(cos(angle), sin(angle))
		var spawn_pos = boss_pos + direction * 100  # 稍微偏離BOSS中心
		
		_spawn_independent_bubble(spawn_pos, direction)
		
		# 快速連續生成
		if i < center_burst_count - 1:
			await get_tree().create_timer(0.08).timeout
	
	await get_tree().create_timer(1.0).timeout
	on_field_control_completed("CENTER_BURST")
#endregion

#region 輔助函數
func _spawn_independent_bubble(world_position: Vector2, direction: Vector2):
	"""在獨立世界空間生成泡泡"""
	if not bubble_scene or not spawnable_manager:
		return
	
	var bubble = bubble_scene.instantiate()
	if not bubble:
		return
	
	# 添加到世界空間
	get_tree().current_scene.add_child(bubble)
	bubble.global_position = world_position
	
	# 初始化泡泡
	if bubble.has_method("initialize_with_direction"):
		bubble.initialize_with_direction(target_player, direction)
	elif bubble.has_method("initialize"):
		bubble.initialize(target_player)
	

func _calculate_map_bounds():
	"""計算地圖邊界（簡化版本）"""
	if map_bounds_calculated:
		return
	
	# 使用BOSS周圍區域作為地圖邊界（實際項目中應該從地圖系統獲取）
	var boss_pos = get_boss_position()
	map_bounds = Rect2(boss_pos.x - 800, boss_pos.y - 400, 1600, 800)
	map_bounds_calculated = true
	

func _is_player_in_center(player_pos: Vector2) -> bool:
	"""判斷玩家是否在地圖中央"""
	var center = map_bounds.get_center()
	var distance_to_center = player_pos.distance_to(center)
	return distance_to_center < 200.0

func _is_player_in_corner(player_pos: Vector2) -> bool:
	"""判斷玩家是否在角落"""
	var corners = [
		map_bounds.position,
		Vector2(map_bounds.position.x + map_bounds.size.x, map_bounds.position.y),
		Vector2(map_bounds.position.x, map_bounds.position.y + map_bounds.size.y),
		map_bounds.position + map_bounds.size
	]
	
	for corner in corners:
		if player_pos.distance_to(corner) < 150.0:
			return true
	return false

func _get_nearest_corner(pos: Vector2) -> Vector2:
	"""獲取最近的角落位置"""
	var corners = [
		map_bounds.position,
		Vector2(map_bounds.position.x + map_bounds.size.x, map_bounds.position.y),
		Vector2(map_bounds.position.x, map_bounds.position.y + map_bounds.size.y),
		map_bounds.position + map_bounds.size
	]
	
	var nearest_corner = corners[0]
	var min_distance = pos.distance_to(nearest_corner)
	
	for corner in corners:
		var distance = pos.distance_to(corner)
		if distance < min_distance:
			min_distance = distance
			nearest_corner = corner
	
	return nearest_corner
#endregion
