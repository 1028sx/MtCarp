@tool
extends RefCounted

## 場景模板創建器
## 
## 負責創建完整的房間場景文件，包括：
## - TileMapLayer 節點
## - RoomInstance 節點
## - 其他自定義節點和組件

func create_room_scene(room_data: Dictionary, tilemap_data: Dictionary, config: Dictionary) -> bool:
	"""創建完整的房間場景文件"""
	
	var room_name = room_data.get("name", "Room")
	var color_code = room_data.get("color", "")
	var color_config = config.get("color_mappings", {}).get(color_code, {})
	var folder = color_config.get("folder", "unknown")
	
	# 確定保存路徑
	var scene_folder = "res://scenes/rooms/" + folder + "/"
	var scene_path = scene_folder + room_name + ".tscn"
	
	print("[場景] 創建房間場景: " + scene_path)
	
	# 確保目標資料夾存在
	if not ensure_directory_exists(scene_folder):
		print("[錯誤] 無法創建目標資料夾: " + scene_folder)
		return false
	
	# 創建場景節點樹
	var scene_root = create_scene_node_tree(room_data, tilemap_data, config)
	if not scene_root:
		print("[錯誤] 場景節點樹創建失敗")
		return false
	
	# 創建 PackedScene
	var packed_scene = PackedScene.new()
	var pack_result = packed_scene.pack(scene_root)
	
	if pack_result != OK:
		print("[錯誤] 場景打包失敗: " + str(pack_result))
		scene_root.queue_free()
		return false
	
	# 保存場景文件
	var save_result = ResourceSaver.save(packed_scene, scene_path)
	scene_root.queue_free()
	
	if save_result != OK:
		print("[錯誤] 場景保存失敗: " + str(save_result))
		return false
	
	print("[成功] 場景已保存: " + scene_path)
	return true

func create_scene_node_tree(room_data: Dictionary, tilemap_data: Dictionary, config: Dictionary) -> Node2D:
	"""創建場景節點樹"""
	
	var room_name = room_data.get("name", "Room")
	var room_size = room_data.get("size", Vector2i(1, 1))
	
	# 創建根節點
	var root = Node2D.new()
	root.name = room_name
	
	# 加載和應用房間模板
	var template_applied = apply_room_template(root, config)
	if not template_applied:
		# 如果沒有模板，創建基本節點結構
		create_basic_node_structure(root, room_data, config)
	
	# 創建 TileMapLayer
	create_tilemap_layer(root, tilemap_data, config)
	
	# 添加房間特定組件
	add_room_components(root, room_data, config)
	
	print("[節點樹] 場景節點樹創建完成，根節點: " + root.name)
	return root

func apply_room_template(root: Node2D, config: Dictionary) -> bool:
	"""應用房間模板"""
	
	var template_path = config.get("room_template", "")
	if template_path.is_empty() or not FileAccess.file_exists(template_path):
		return false
	
	var template_scene = load(template_path)
	if not template_scene is PackedScene:
		print("[警告] 房間模板不是有效的 PackedScene: " + template_path)
		return false
	
	var template_instance = template_scene.instantiate()
	if not template_instance:
		print("[警告] 房間模板實例化失敗")
		return false
	
	# 複製模板節點到根節點
	copy_template_nodes(root, template_instance)
	template_instance.queue_free()
	
	print("[模板] 房間模板已應用: " + template_path)
	return true

func copy_template_nodes(root: Node2D, template: Node):
	"""複製模板節點到根節點"""
	
	for child in template.get_children():
		var child_copy = child.duplicate()
		root.add_child(child_copy)
		child_copy.owner = root

func create_basic_node_structure(root: Node2D, room_data: Dictionary, config: Dictionary):
	"""創建基本節點結構"""
	
	var included_nodes = config.get("included_nodes", ["RoomInstance", "DeathZone"])
	
	for node_type in included_nodes:
		match node_type:
			"RoomInstance":
				create_room_instance(root, room_data)
			"DeathZone":
				create_death_zone(root, room_data)
			"SpawnPoints":
				create_spawn_points(root, room_data)
			"Boundaries":
				create_room_boundaries(root, room_data)

func create_tilemap_layer(root: Node2D, tilemap_data: Dictionary, config: Dictionary):
	"""創建 TileMapLayer 節點"""
	
	# 載入 TileSet
	var tileset = null
	var tileset_path = config.get("tileset_path", "")
	if not tileset_path.is_empty() and FileAccess.file_exists(tileset_path):
		var loaded_resource = load(tileset_path)
		
		if loaded_resource is TileSet:
			tileset = loaded_resource
		elif loaded_resource is Texture2D:
			# 如果是圖片，創建基本的 TileSet
			tileset = create_tileset_from_texture(loaded_resource)
			print("[TileSet] 從圖片創建 TileSet: " + tileset_path)
		else:
			print("[警告] 不支持的 TileSet 格式: " + tileset_path)
			tileset = null
	
	# 創建 TileMapLayer
	var tilemap_builder = load("res://addons/metsysroomgenerator/tilemap_builder.gd").new()
	var tilemap_layer = tilemap_builder.create_tilemap_layer_node(tilemap_data, tileset, "TileMapLayer")
	
	if tilemap_layer:
		root.add_child(tilemap_layer)
		tilemap_layer.owner = root
		print("[TileMapLayer] 已添加到場景")
	else:
		print("[錯誤] TileMapLayer 創建失敗")

func create_room_instance(root: Node2D, room_data: Dictionary):
	"""創建 RoomInstance 節點（MetSys 房間實例）"""
	
	# 檢查是否有 MetSys 的 RoomInstance 類
	var RoomInstanceClass = null
	
	# 嘗試載入 RoomInstance 類
	if FileAccess.file_exists("res://addons/MetroidvaniaSystem/Scripts/RoomInstance.gd"):
		RoomInstanceClass = load("res://addons/MetroidvaniaSystem/Scripts/RoomInstance.gd")
	
	var room_instance
	if RoomInstanceClass:
		room_instance = RoomInstanceClass.new()
	else:
		# 如果沒有 MetSys，創建一個基本的 Node2D 節點作為替代
		room_instance = Node2D.new()
		print("[警告] 未找到 MetSys RoomInstance 類，使用 Node2D 替代")
	
	room_instance.name = "RoomInstance"
	root.add_child(room_instance)
	room_instance.owner = root
	
	print("[RoomInstance] 已添加到場景")

func create_death_zone(root: Node2D, room_data: Dictionary):
	"""創建死亡區域"""
	
	var room_size = room_data.get("size", Vector2i(1, 1))
	var pixel_width = room_size.x * 512  # MetSys cell 寬度
	var pixel_height = room_size.y * 288  # MetSys cell 高度
	
	# 創建死亡區域節點
	var death_zone = Area2D.new()
	death_zone.name = "DeathZone"
	death_zone.position = Vector2(0, pixel_height + 64)  # 位於房間底部下方
	
	# 創建碰撞形狀
	var collision_shape = CollisionShape2D.new()
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = Vector2(pixel_width, 64)  # 死亡區域高度
	
	collision_shape.shape = rectangle_shape
	death_zone.add_child(collision_shape)
	collision_shape.owner = root
	
	root.add_child(death_zone)
	death_zone.owner = root
	
	print("[DeathZone] 已添加到場景，位置: %s，大小: %s" % [death_zone.position, rectangle_shape.size])

func create_spawn_points(root: Node2D, room_data: Dictionary):
	"""創建生成點"""
	
	var room_size = room_data.get("size", Vector2i(1, 1))
	var pixel_width = room_size.x * 512
	var pixel_height = room_size.y * 288
	
	# 左側生成點
	var left_spawn = Node2D.new()
	left_spawn.name = "LeftSpawn"
	left_spawn.position = Vector2(64, pixel_height - 96)  # 地面高度
	root.add_child(left_spawn)
	left_spawn.owner = root
	
	# 右側生成點
	var right_spawn = Node2D.new()
	right_spawn.name = "RightSpawn"
	right_spawn.position = Vector2(pixel_width - 64, pixel_height - 96)  # 地面高度
	root.add_child(right_spawn)
	right_spawn.owner = root
	
	print("[SpawnPoints] 已添加生成點: Left(%s), Right(%s)" % [left_spawn.position, right_spawn.position])

func create_room_boundaries(root: Node2D, room_data: Dictionary):
	"""創建房間邊界"""
	
	var room_size = room_data.get("size", Vector2i(1, 1))
	var pixel_width = room_size.x * 512
	var pixel_height = room_size.y * 288
	
	# 創建邊界節點
	var boundaries = Node2D.new()
	boundaries.name = "Boundaries"
	root.add_child(boundaries)
	boundaries.owner = root
	
	# 四個邊界
	var boundary_names = ["TopBoundary", "BottomBoundary", "LeftBoundary", "RightBoundary"]
	var boundary_positions = [
		Vector2(pixel_width / 2, 0),           # 頂部
		Vector2(pixel_width / 2, pixel_height), # 底部
		Vector2(0, pixel_height / 2),          # 左側
		Vector2(pixel_width, pixel_height / 2)  # 右側
	]
	var boundary_sizes = [
		Vector2(pixel_width, 10),    # 頂部
		Vector2(pixel_width, 10),    # 底部
		Vector2(10, pixel_height),   # 左側
		Vector2(10, pixel_height)    # 右側
	]
	
	for i in range(4):
		var boundary = Area2D.new()
		boundary.name = boundary_names[i]
		boundary.position = boundary_positions[i]
		
		var collision_shape = CollisionShape2D.new()
		var rectangle_shape = RectangleShape2D.new()
		rectangle_shape.size = boundary_sizes[i]
		collision_shape.shape = rectangle_shape
		
		boundary.add_child(collision_shape)
		collision_shape.owner = root
		
		boundaries.add_child(boundary)
		boundary.owner = root
	
	print("[Boundaries] 已添加房間邊界")

func add_room_components(root: Node2D, room_data: Dictionary, config: Dictionary):
	"""添加房間特定組件"""
	
	var generation_settings = config.get("generation_settings", {})
	
	# 根據配置添加組件
	if generation_settings.get("create_spawn_points", false):
		if not root.has_node("LeftSpawn"):
			create_spawn_points(root, room_data)
	
	if generation_settings.get("create_room_boundaries", false):
		if not root.has_node("Boundaries"):
			create_room_boundaries(root, room_data)

func ensure_directory_exists(dir_path: String) -> bool:
	"""確保目標資料夾存在"""
	
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	
	var dir = DirAccess.open("res://")
	if not dir:
		print("[錯誤] 無法打開 res:// 目錄")
		return false
	
	var result = dir.make_dir_recursive(dir_path)
	if result != OK:
		print("[錯誤] 無法創建目錄: " + dir_path + " (錯誤: " + str(result) + ")")
		return false
	
	print("[目錄] 已創建目錄: " + dir_path)
	return true

func get_scene_preview_image(scene_path: String) -> Image:
	"""獲取場景預覽圖像"""
	
	if not FileAccess.file_exists(scene_path):
		return null
	
	# 這裡可以實現場景預覽圖像生成
	# 暫時返回一個簡單的佔位圖像
	var preview_image = Image.create(256, 144, false, Image.FORMAT_RGBA8)
	preview_image.fill(Color(0.2, 0.2, 0.3, 1.0))  # 深灰色背景
	
	return preview_image

func validate_scene_file(scene_path: String) -> Dictionary:
	"""驗證場景文件"""
	
	var validation_result = {
		"valid": false,
		"errors": [],
		"warnings": []
	}
	
	if not FileAccess.file_exists(scene_path):
		validation_result.errors.append("場景文件不存在: " + scene_path)
		return validation_result
	
	var scene = load(scene_path)
	if not scene is PackedScene:
		validation_result.errors.append("文件不是有效的 PackedScene")
		return validation_result
	
	var instance = scene.instantiate()
	if not instance:
		validation_result.errors.append("場景實例化失敗")
		return validation_result
	
	# 檢查必要的節點
	var required_nodes = ["TileMapLayer"]
	for node_name in required_nodes:
		if not instance.has_node(node_name):
			validation_result.warnings.append("缺少建議的節點: " + node_name)
	
	instance.queue_free()
	validation_result.valid = validation_result.errors.is_empty()
	
	return validation_result

func create_tileset_from_texture(texture: Texture2D) -> TileSet:
	"""從圖片創建基本的 TileSet"""
	
	var tileset = TileSet.new()
	
	# 創建 TileSetAtlasSource
	var atlas_source = TileSetAtlasSource.new()
	atlas_source.texture = texture
	
	# 設定基本瓦片大小 (假設 32x32)
	var tile_size = 32
	atlas_source.texture_region_size = Vector2i(tile_size, tile_size)
	
	# 計算圖片中有多少個瓦片
	var texture_size = texture.get_size()
	var cols = int(texture_size.x / tile_size)
	var rows = int(texture_size.y / tile_size)
	
	print("[TileSet] 創建 TileSet，瓦片尺寸: %dx%d，總計: %dx%d 瓦片" % [tile_size, tile_size, cols, rows])
	
	# 為每個瓦片創建 atlas coordinate
	for y in range(rows):
		for x in range(cols):
			var atlas_coords = Vector2i(x, y)
			atlas_source.create_tile(atlas_coords)
			
			# 可以為特定瓦片設置碰撞等屬性
			var tile_data = atlas_source.get_tile_data(atlas_coords, 0)
			if tile_data:
				# 基本碰撞設定（可選）
				pass
	
	# 添加 atlas source 到 tileset
	tileset.add_source(atlas_source, 0)
	
	return tileset