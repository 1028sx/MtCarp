@tool
extends EditorPlugin

# 房間數據創建器 - 用於快速創建房間配置文件

func create_room_data(room_name: String, connections: Dictionary = {}, room_type: String = "NORMAL") -> void:
	var room_data = RoomData.new()
	
	# 基本設定
	room_data.room_name = room_name
	room_data.room_type = room_type
	room_data.room_size = Vector2(1920, 1080)
	room_data.camera_bounds = Rect2(0, 0, 1920, 1080)
	
	# 連接設定
	room_data.connections = connections
	
	# 生成點設定（使用默認值）
	room_data.spawn_points = {
		"LeftSpawn": Vector2(100, 540),
		"RightSpawn": Vector2(1820, 540),
		"TopSpawn": Vector2(960, 100),
		"BottomSpawn": Vector2(960, 980),
		"DefaultSpawn": Vector2(960, 540)
	}
	
	# 保存房間數據
	var save_path = "res://data/rooms/" + room_name + ".tres"
	
	# 確保目錄存在
	DirAccess.open("res://").make_dir_recursive("data/rooms")
	
	ResourceSaver.save(room_data, save_path)
	print("房間數據已創建：", save_path)

func create_connected_rooms_data(room_configs: Array) -> void:
	"""
	創建一系列相連的房間數據
	room_configs格式：[
		{"name": "Room1", "connections": {"right": "Room2"}},
		{"name": "Room2", "connections": {"left": "Room1", "right": "Room3"}},
		...
	]
	"""
	for config in room_configs:
		var room_name = config.get("name", "")
		var connections = config.get("connections", {})
		var room_type = config.get("type", "NORMAL")
		
		if not room_name.is_empty():
			create_room_data(room_name, connections, room_type)

# 為Beginning區域創建數據
func create_beginning_area_data() -> void:
	var beginning_rooms = [
		{
			"name": "Beginning1",
			"connections": {"right": "Beginning2"},
			"type": "NORMAL"
		},
		{
			"name": "Beginning2", 
			"connections": {"left": "Beginning1"},
			"type": "NORMAL"
		}
	]
	
	create_connected_rooms_data(beginning_rooms)

# 示例：創建森林區域
func create_forest_area_data() -> void:
	var forest_rooms = [
		{
			"name": "ForestEntrance",
			"connections": {"right": "ForestPath1"},
			"type": "NORMAL"
		},
		{
			"name": "ForestPath1",
			"connections": {"left": "ForestEntrance", "right": "ForestPath2", "down": "ForestSecret1"},
			"type": "NORMAL"
		},
		{
			"name": "ForestPath2",
			"connections": {"left": "ForestPath1", "up": "ForestBoss"},
			"type": "NORMAL"
		},
		{
			"name": "ForestSecret1",
			"connections": {"up": "ForestPath1"},
			"type": "TREASURE"
		},
		{
			"name": "ForestBoss",
			"connections": {"down": "ForestPath2"},
			"type": "BOSS"
		}
	]
	
	create_connected_rooms_data(forest_rooms)

func _run() -> void:
	print("房間數據創建器就緒！")
	
	# 創建Beginning區域的數據
	create_beginning_area_data()
	
	print("Beginning區域房間數據已創建！")
	print("你可以修改此腳本來創建更多區域的房間數據")