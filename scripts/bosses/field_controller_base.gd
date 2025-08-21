extends Node2D

class_name FieldControllerBase

## 通用場地控制系統基類
## 提供場地控制的通用邏輯，可被各種BOSS使用

#region 導出屬性
@export_group("場地控制配置")
@export var cooldown_time: float = 8.0
@export var trigger_distance: float = 400.0
@export var auto_trigger: bool = true
#endregion

#region 核心變量
var boss_node: Node2D
var target_player: Node2D 
var spawnable_manager: Node
var last_trigger_time: float = 0.0
var is_cooldown: bool = false

# 場地控制統計
var trigger_count: int = 0
var last_pattern_used: String = ""
#endregion

#region 信號
signal field_control_triggered(pattern_name: String)
signal field_control_completed(pattern_name: String)
#endregion

func _ready():
	print_debug("[FieldController] 場地控制系統初始化")

func initialize(boss: Node2D, player: Node2D, spawnable_mgr: Node):
	"""初始化場地控制系統"""
	boss_node = boss
	target_player = player
	spawnable_manager = spawnable_mgr
	
	print_debug("[FieldController] 系統初始化完成 - BOSS: %s, 玩家: %s" % [boss, player])

func _process(_delta: float):
	if not is_initialized():
		return
		
	# 更新冷卻狀態
	_update_cooldown()
	
	# 自動觸發檢查
	if auto_trigger and not is_cooldown:
		_check_auto_trigger()

func is_initialized() -> bool:
	"""檢查是否已正確初始化"""
	return boss_node != null and target_player != null and spawnable_manager != null

func _update_cooldown():
	"""更新冷卻狀態"""
	if is_cooldown:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_trigger_time >= cooldown_time:
			is_cooldown = false
			print_debug("[FieldController] 冷卻結束，可以觸發場地控制")

func _check_auto_trigger():
	"""檢查是否應該自動觸發場地控制"""
	if not target_player or not boss_node:
		return
		
	var distance = boss_node.global_position.distance_to(target_player.global_position)
	
	# 玩家保持距離時觸發場地控制
	if distance > trigger_distance:
		var pattern = select_field_control_pattern()
		if pattern != "":
			trigger_field_control(pattern)

func select_field_control_pattern() -> String:
	"""選擇場地控制模式 - 子類應該覆寫此函數"""
	print_debug("[FieldController] 基類無可用模式，請在子類中實現")
	return ""

func trigger_field_control(pattern_name: String) -> bool:
	"""觸發場地控制 - 子類應該覆寫此函數"""
	if is_cooldown:
		print_debug("[FieldController] 場地控制冷卻中，跳過觸發")
		return false
	
	print_debug("[FieldController] 觸發場地控制: %s" % pattern_name)
	
	# 更新狀態
	last_trigger_time = Time.get_ticks_msec() / 1000.0
	is_cooldown = true
	trigger_count += 1
	last_pattern_used = pattern_name
	
	# 發送信號
	field_control_triggered.emit(pattern_name)
	
	return true

func on_field_control_completed(pattern_name: String):
	"""場地控制完成回調"""
	print_debug("[FieldController] 場地控制完成: %s" % pattern_name)
	field_control_completed.emit(pattern_name)

func get_player_position() -> Vector2:
	"""獲取玩家位置"""
	if target_player:
		return target_player.global_position
	return Vector2.ZERO

func get_boss_position() -> Vector2:
	"""獲取BOSS位置"""
	if boss_node:
		return boss_node.global_position
	return Vector2.ZERO

func get_distance_to_player() -> float:
	"""獲取與玩家的距離"""
	if not target_player or not boss_node:
		return 0.0
	return boss_node.global_position.distance_to(target_player.global_position)

#region 調試和統計
func get_debug_info() -> Dictionary:
	"""獲取調試信息"""
	return {
		"initialized": is_initialized(),
		"cooldown": is_cooldown,
		"trigger_count": trigger_count,
		"last_pattern": last_pattern_used,
		"distance_to_player": get_distance_to_player()
	}

func print_debug_status():
	"""打印調試狀態"""
	var info = get_debug_info()
	print_debug("[FieldController] 狀態: %s" % info)
#endregion
