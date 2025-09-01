extends Node

# 房間設置管理器 - 在遊戲啟動時自動創建必要的房間數據

func _ready() -> void:
	# 延遲執行，確保專案完全載入
	call_deferred("setup_room_system")

func setup_room_system() -> void:
	print("開始設置房間系統...")
	
	# 創建目錄
	_ensure_directories()
	
	# 創建Beginning區域的房間數據
	_create_beginning_area_data()
	
	print("房間系統設置完成！")

func _ensure_directories() -> void:
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("data"):
		dir.make_dir("data")
	if not dir.dir_exists("data/rooms"):
		dir.make_dir("data/rooms")

func _create_beginning_area_data() -> void:
	_create_room_data("Beginning1", {"right": "Beginning2"}, "NORMAL")
	_create_room_data("Beginning2", {"left": "Beginning1"}, "NORMAL")

func _create_room_data(room_name: String, connections: Dictionary, room_type: String) -> void:
	var save_path = "res://data/rooms/" + room_name + ".tres"
	
	# 如果文件已存在，跳過
	if ResourceLoader.exists(save_path):
		print("房間數據已存在，跳過：", save_path)
		return
	
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
	ResourceSaver.save(room_data, save_path)
	print("房間數據已創建：", save_path)