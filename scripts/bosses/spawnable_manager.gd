class_name SpawnableManager
extends Node2D

# 衍生物統一管理器 - 負責所有BOSS衍生物的生命週期管理

signal spawnable_created(spawnable: Node, type: String)
signal spawnable_destroyed(spawnable: Node, type: String)

# 活躍衍生物列表
var active_spawnables: Array[Node] = []

# 物件池系統
var object_pools: Dictionary = {}
const MAX_POOL_SIZE = 20

# 統計信息
var spawn_counts: Dictionary = {}
var total_spawned: int = 0
var total_pooled: int = 0

func _ready():
	name = "SpawnableManager"

# 主要接口：使用物件池生成衍生物
func spawn_with_pool(scene: PackedScene, type: String, setup_func: Callable = Callable()) -> Node:
	
	if not scene:
		push_error("[SpawnableManager] Scene is null for type: %s" % type)
		return null
	
	var obj = _get_from_pool(type, scene)
	if not obj:
		push_error("[SpawnableManager] Failed to create object for type: %s" % type)
		return null
	
	
	# 添加到場景樹
	add_child(obj)
	active_spawnables.append(obj)
	
	# 執行設定函數
	if setup_func.is_valid():
		setup_func.call(obj)
	
	# 統計
	_update_spawn_stats(type)
	
	# 發送信號
	spawnable_created.emit(obj, type)
	
	return obj

# 從物件池獲取或創建新物件
func _get_from_pool(type: String, scene: PackedScene) -> Node:
	if not object_pools.has(type):
		object_pools[type] = []
	
	var pool = object_pools[type]
	
	if pool.is_empty():
		# 池中無物件，創建新的
		var new_obj = scene.instantiate()
		if new_obj:
			total_spawned += 1
		return new_obj
	else:
		# 從池中取出
		var obj = pool.pop_back()
		if is_instance_valid(obj):
			obj.visible = true
			if obj.has_method("reset"):
				obj.reset()
			return obj
		else:
			# 物件已失效，遞歸重試
			return _get_from_pool(type, scene)

# 將物件歸還到池中
func _return_to_pool(obj: Node, type: String):
	if not is_instance_valid(obj):
		return
	
	if not object_pools.has(type):
		object_pools[type] = []
	
	var pool = object_pools[type]
	
	if pool.size() < MAX_POOL_SIZE:
		# 池未滿，歸還
		if obj.has_method("reset"):
			obj.reset()
		obj.visible = false
		obj.get_parent().remove_child(obj)
		pool.append(obj)
		total_pooled += 1
	else:
		# 池已滿，直接銷毀
		obj.queue_free()

# 銷毀指定衍生物
func destroy_spawnable(obj: Node):
	if not is_instance_valid(obj):
		return
	
	if obj in active_spawnables:
		active_spawnables.erase(obj)
	
	# 嘗試判斷類型並歸還池中
	var type = _detect_spawnable_type(obj)
	if type != "":
		_return_to_pool(obj, type)
		spawnable_destroyed.emit(obj, type)
	else:
		obj.queue_free()

# 清理所有活躍衍生物
func cleanup_all():
	for spawnable in active_spawnables:
		if is_instance_valid(spawnable):
			var type = _detect_spawnable_type(spawnable)
			_return_to_pool(spawnable, type)
			spawnable_destroyed.emit(spawnable, type)
	
	active_spawnables.clear()

# 清理指定類型的衍生物
func cleanup_type(type: String):
	var to_remove = []
	
	for spawnable in active_spawnables:
		if is_instance_valid(spawnable) and _detect_spawnable_type(spawnable) == type:
			to_remove.append(spawnable)
	
	for spawnable in to_remove:
		destroy_spawnable(spawnable)

# 獲取指定類型的活躍衍生物數量
func get_active_count(type: String = "") -> int:
	if type == "":
		return active_spawnables.size()
	
	var count = 0
	for spawnable in active_spawnables:
		if is_instance_valid(spawnable) and _detect_spawnable_type(spawnable) == type:
			count += 1
	
	return count

# 檢測衍生物類型
func _detect_spawnable_type(obj: Node) -> String:
	if obj.has_method("get_spawnable_type"):
		return obj.get_spawnable_type()
	
	# 通過類名推斷
	var obj_class_name = obj.get_script().get_global_name() if obj.get_script() else ""
	
	if "Bubble" in obj_class_name:
		return "bubble"
	elif "WaterSplash" in obj_class_name:
		return "water_splash"
	elif "Wave" in obj_class_name:
		return "wave"
	else:
		return "unknown"

# 更新生成統計
func _update_spawn_stats(type: String):
	if not spawn_counts.has(type):
		spawn_counts[type] = 0
	spawn_counts[type] += 1

# 獲取調試信息
func get_debug_info() -> Dictionary:
	return {
		"active_count": active_spawnables.size(),
		"total_spawned": total_spawned,
		"total_pooled": total_pooled,
		"spawn_counts": spawn_counts,
		"pool_sizes": _get_pool_sizes()
	}

func _get_pool_sizes() -> Dictionary:
	var sizes = {}
	for type in object_pools.keys():
		sizes[type] = object_pools[type].size()
	return sizes

# 清理無效的活躍物件
func _cleanup_invalid_references():
	var valid_spawnables = []
	for spawnable in active_spawnables:
		if is_instance_valid(spawnable):
			valid_spawnables.append(spawnable)
	active_spawnables = valid_spawnables

# 每秒清理一次無效引用
func _on_cleanup_timer_timeout():
	_cleanup_invalid_references()

func _exit_tree():
	cleanup_all()