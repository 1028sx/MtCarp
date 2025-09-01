extends Node2D
class_name BaseRoom

@export var room_name: String = ""
@export var room_type: String = "NORMAL"
@export var camera_bounds: Rect2 = Rect2(0, 0, 1920, 1080)

@onready var spawn_points: Node2D = $SpawnPoints
@onready var room_boundaries: Node2D = $RoomBoundaries  
@onready var camera_bounds_rect: ReferenceRect = $CameraBounds
@onready var enemy_spawn_points: Node2D = $EnemySpawnPoints

var room_data: RoomData

func _ready() -> void:
	# 設定房間名稱（如果沒有設定的話）
	if room_name.is_empty():
		room_name = name
	
	# 自動設定攝影機邊界
	if camera_bounds_rect:
		camera_bounds_rect.size = camera_bounds.size
		camera_bounds_rect.position = camera_bounds.position
	
	# 載入房間數據
	_load_room_data()
	
	# 設定房間邊界的參數
	_setup_room_boundaries()

func _load_room_data() -> void:
	var data_path = "res://data/rooms/" + room_name + ".tres"
	if ResourceLoader.exists(data_path):
		room_data = load(data_path) as RoomData
	else:
		# 創建默認數據
		room_data = RoomData.new()
		room_data.room_name = room_name
		room_data.room_type = room_type
		room_data.camera_bounds = camera_bounds

func _setup_room_boundaries() -> void:
	if not room_boundaries or not room_data:
		return
	
	# 自動設定房間邊界的target_room參數
	for child in room_boundaries.get_children():
		if child is Area2D and child.has_method("get_spawn_point_name"):
			var boundary_name = child.name.to_lower()
			
			# 根據邊界名稱自動設定連接
			if "left" in boundary_name:
				var target = room_data.get_connection("left")
				if not target.is_empty():
					child.target_room = target
					child.entrance_side = "right"
			elif "right" in boundary_name:
				var target = room_data.get_connection("right")
				if not target.is_empty():
					child.target_room = target
					child.entrance_side = "left"
			elif "up" in boundary_name or "top" in boundary_name:
				var target = room_data.get_connection("up")
				if not target.is_empty():
					child.target_room = target
					child.entrance_side = "down"
			elif "down" in boundary_name or "bottom" in boundary_name:
				var target = room_data.get_connection("down")
				if not target.is_empty():
					child.target_room = target
					child.entrance_side = "up"

func get_spawn_point(spawn_name: String) -> Vector2:
	if not spawn_points:
		return Vector2.ZERO
	
	var spawn_node = spawn_points.get_node_or_null(spawn_name)
	if spawn_node and spawn_node is Node2D:
		return spawn_node.global_position
	
	return Vector2.ZERO

func get_enemy_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	if not enemy_spawn_points:
		return points
	
	for child in enemy_spawn_points.get_children():
		if child is Node2D:
			points.append(child.global_position)
	
	return points

func set_camera_bounds(bounds: Rect2) -> void:
	camera_bounds = bounds
	if camera_bounds_rect:
		camera_bounds_rect.size = bounds.size
		camera_bounds_rect.position = bounds.position