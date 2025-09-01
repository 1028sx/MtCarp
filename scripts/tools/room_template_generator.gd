@tool
extends EditorScript

# 房間模板生成器 - 用於快速創建標準化房間

func create_room_template(room_name: String, room_size: Vector2 = Vector2(1920, 1080)) -> void:
	print("開始創建房間模板：", room_name)
	
	# 創建主房間節點
	var room_scene = PackedScene.new()
	var room_root = Node2D.new()
	room_root.name = room_name
	room_root.set_script(load("res://scripts/rooms/base_room.gd"))
	
	# 創建標準節點結構
	_create_spawn_points(room_root, room_size)
	_create_room_boundaries(room_root, room_size)
	_create_camera_bounds(room_root, room_size)
	_create_enemy_spawn_points(room_root)
	
	# 保存場景
	room_scene.pack(room_root)
	var save_path = "res://scenes/rooms/" + room_name + ".tscn"
	ResourceSaver.save(room_scene, save_path)
	
	print("房間模板已創建：", save_path)

func _create_spawn_points(parent: Node2D, room_size: Vector2) -> void:
	var spawn_points = Node2D.new()
	spawn_points.name = "SpawnPoints"
	
	# 左側生成點
	var left_spawn = Marker2D.new()
	left_spawn.name = "LeftSpawn"
	left_spawn.position = Vector2(100, room_size.y * 0.5)
	spawn_points.add_child(left_spawn)
	left_spawn.owner = parent
	
	# 右側生成點
	var right_spawn = Marker2D.new()
	right_spawn.name = "RightSpawn"
	right_spawn.position = Vector2(room_size.x - 100, room_size.y * 0.5)
	spawn_points.add_child(right_spawn)
	right_spawn.owner = parent
	
	# 上方生成點
	var top_spawn = Marker2D.new()
	top_spawn.name = "TopSpawn"
	top_spawn.position = Vector2(room_size.x * 0.5, 100)
	spawn_points.add_child(top_spawn)
	top_spawn.owner = parent
	
	# 下方生成點
	var bottom_spawn = Marker2D.new()
	bottom_spawn.name = "BottomSpawn"
	bottom_spawn.position = Vector2(room_size.x * 0.5, room_size.y - 100)
	spawn_points.add_child(bottom_spawn)
	bottom_spawn.owner = parent
	
	# 默認生成點
	var default_spawn = Marker2D.new()
	default_spawn.name = "DefaultSpawn"
	default_spawn.position = Vector2(room_size.x * 0.5, room_size.y * 0.5)
	spawn_points.add_child(default_spawn)
	default_spawn.owner = parent
	
	parent.add_child(spawn_points)
	spawn_points.owner = parent

func _create_room_boundaries(parent: Node2D, room_size: Vector2) -> void:
	var boundaries = Node2D.new()
	boundaries.name = "RoomBoundaries"
	parent.add_child(boundaries)
	boundaries.owner = parent
	
	# 這裡只創建節點結構，具體的邊界需要根據房間連接手動添加
	# 因為不是每個房間都需要所有方向的出口

func _create_camera_bounds(parent: Node2D, room_size: Vector2) -> void:
	var camera_bounds = ReferenceRect.new()
	camera_bounds.name = "CameraBounds"
	camera_bounds.position = Vector2.ZERO
	camera_bounds.size = room_size
	parent.add_child(camera_bounds)
	camera_bounds.owner = parent

func _create_enemy_spawn_points(parent: Node2D) -> void:
	var enemy_spawns = Node2D.new()
	enemy_spawns.name = "EnemySpawnPoints"
	parent.add_child(enemy_spawns)
	enemy_spawns.owner = parent

# 批量創建多個房間模板
func create_multiple_rooms(room_names: Array[String]) -> void:
	for room_name in room_names:
		create_room_template(room_name)

# 使用示例：
func _run() -> void:
	# 創建單個房間
	# create_room_template("TestRoom")
	
	# 批量創建多個房間
	var room_list = [
		"ForestArea1",
		"ForestArea2", 
		"CaveArea1",
		"CaveArea2"
	]
	# create_multiple_rooms(room_list)
	
	print("房間模板生成器就緒！")
	print("使用方法：")
	print("1. 修改 _run() 函數中的代碼")
	print("2. 在 Project -> Tools -> Execute Script 中執行此腳本")