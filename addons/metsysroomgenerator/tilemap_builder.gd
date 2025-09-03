@tool
extends RefCounted

## TileMap 構建器
## 
## 負責根據房間數據和配置創建 TileMapLayer 數據
## 支持自定義 TileSet、瓦片選擇和基本方塊房生成

# 常量定義
const CELL_TILE_WIDTH = 16   # 每個 MetSys cell 的瓦片寬度 
const CELL_TILE_HEIGHT = 9   # 每個 MetSys cell 的瓦片高度

# 預設瓦片配置（基本方塊房）
const DEFAULT_TILES = {
	"floor": 0,      # 地板瓦片 ID
	"wall": 1,       # 牆壁瓦片 ID  
	"ceiling": 2,    # 天花板瓦片 ID
	"background": 3  # 背景瓦片 ID
}

func generate_room_tilemap(room_data: Dictionary, config: Dictionary) -> Dictionary:
	"""生成房間的 TileMap 數據"""
	
	var room_size = room_data.get("size", Vector2i(1, 1))
	var tile_width = room_size.x * CELL_TILE_WIDTH
	var tile_height = room_size.y * CELL_TILE_HEIGHT
	
	print("[TileMap] 生成房間: %s, 尺寸: %dx%d cells (%dx%d tiles)" % [
		room_data.get("name", "Unknown"),
		room_size.x, room_size.y,
		tile_width, tile_height
	])
	
	# 創建 TileMapLayer 數據
	var tilemap_data = {
		"size": Vector2i(tile_width, tile_height),
		"tiles": {},  # 瓦片數據 {Vector2i: {source_id, atlas_coords, alternative_tile}}
		"room_size": room_size
	}
	
	# 獲取 TileSet 和瓦片配置
	var tileset_config = get_tileset_config(config)
	
	# 生成基本房間結構
	generate_basic_room_structure(tilemap_data, room_data, tileset_config)
	
	# 生成通道連接
	generate_room_connections(tilemap_data, room_data, tileset_config)
	
	return tilemap_data

func get_tileset_config(config: Dictionary) -> Dictionary:
	"""獲取 TileSet 配置"""
	var tileset_config = {
		"tileset_path": config.get("tileset_path", ""),
		"selected_tiles": config.get("selected_tiles", [0, 1, 2, 3]),
		"source_id": 0,  # 預設使用第一個 source
		"use_atlas_coords": true
	}
	
	# 將瓦片 ID 映射到默認配置
	var selected_tiles = tileset_config.selected_tiles
	if selected_tiles.size() >= 4:
		tileset_config["floor_tile"] = selected_tiles[0]
		tileset_config["wall_tile"] = selected_tiles[1] 
		tileset_config["ceiling_tile"] = selected_tiles[2]
		tileset_config["background_tile"] = selected_tiles[3]
	else:
		# 使用默認配置
		tileset_config["floor_tile"] = DEFAULT_TILES.floor
		tileset_config["wall_tile"] = DEFAULT_TILES.wall
		tileset_config["ceiling_tile"] = DEFAULT_TILES.ceiling
		tileset_config["background_tile"] = DEFAULT_TILES.background
	
	return tileset_config

func generate_basic_room_structure(tilemap_data: Dictionary, room_data: Dictionary, tileset_config: Dictionary):
	"""生成基本房間結構（牆壁、地板、天花板）"""
	
	var size = tilemap_data.size
	var source_id = tileset_config.source_id
	
	# 填充背景
	for x in range(size.x):
		for y in range(size.y):
			set_tile_data(tilemap_data, Vector2i(x, y), source_id, 
				Vector2i(tileset_config.background_tile, 0), 0)
	
	# 生成地板（底部兩行）
	for x in range(size.x):
		for y in range(size.y - 2, size.y):
			set_tile_data(tilemap_data, Vector2i(x, y), source_id,
				Vector2i(tileset_config.floor_tile, 0), 0)
	
	# 生成天花板（頂部一行）
	for x in range(size.x):
		set_tile_data(tilemap_data, Vector2i(x, 0), source_id,
			Vector2i(tileset_config.ceiling_tile, 0), 0)
	
	# 生成左右牆壁
	for y in range(1, size.y - 2):
		# 左牆
		set_tile_data(tilemap_data, Vector2i(0, y), source_id,
			Vector2i(tileset_config.wall_tile, 0), 0)
		# 右牆
		set_tile_data(tilemap_data, Vector2i(size.x - 1, y), source_id,
			Vector2i(tileset_config.wall_tile, 0), 0)

func generate_room_connections(tilemap_data: Dictionary, room_data: Dictionary, tileset_config: Dictionary):
	"""生成房間連接（通道）"""
	
	var cells = room_data.get("cells", [])
	var cell_data_dict = room_data.get("cell_data", {})
	var bounds = room_data.get("bounds", Rect2i())
	
	# 為每個 cell 檢查邊界並開通道
	for cell_coord in cells:
		var cell_data = cell_data_dict.get(cell_coord, {})
		var borders = cell_data.get("borders", [0, 0, 0, 0])  # [右, 下, 左, 上]
		
		# 計算該 cell 在房間中的相對位置
		var relative_pos = Vector2i(
			cell_coord.x - bounds.position.x,
			cell_coord.y - bounds.position.y
		)
		
		# 為每個方向檢查是否需要開通道
		create_passages_for_cell(tilemap_data, relative_pos, borders, tileset_config)

func create_passages_for_cell(tilemap_data: Dictionary, cell_pos: Vector2i, borders: Array, tileset_config: Dictionary):
	"""為單個 cell 創建通道"""
	
	# cell 在 tilemap 中的起始位置
	var tile_start_x = cell_pos.x * CELL_TILE_WIDTH
	var tile_start_y = cell_pos.y * CELL_TILE_HEIGHT
	
	# 方向定義：右(0), 下(1), 左(2), 上(3)
	var directions = ["right", "down", "left", "up"]
	
	for i in range(4):
		var border_type = borders[i]
		
		# border_type > 0 表示有通道連接
		if border_type > 0:
			create_passage(tilemap_data, tile_start_x, tile_start_y, directions[i], tileset_config)

func create_passage(tilemap_data: Dictionary, start_x: int, start_y: int, direction: String, tileset_config: Dictionary):
	"""在指定方向創建通道"""
	
	var size = tilemap_data.size
	
	match direction:
		"right":
			# 右側通道：在右邊界開洞
			var passage_x = start_x + CELL_TILE_WIDTH - 1
			var passage_start_y = start_y + 4  # 地面高度
			var passage_height = 4  # 通道高度
			
			for y in range(passage_start_y, min(passage_start_y + passage_height, size.y - 2)):
				if passage_x < size.x:
					clear_tile_data(tilemap_data, Vector2i(passage_x, y))
		
		"left":
			# 左側通道：在左邊界開洞  
			var passage_x = start_x
			var passage_start_y = start_y + 4  # 地面高度
			var passage_height = 4  # 通道高度
			
			for y in range(passage_start_y, min(passage_start_y + passage_height, size.y - 2)):
				if passage_x >= 0:
					clear_tile_data(tilemap_data, Vector2i(passage_x, y))
		
		"up":
			# 上方通道：在天花板開洞
			var passage_y = start_y
			var passage_start_x = start_x + 6  # 水平置中
			var passage_width = 4  # 通道寬度
			
			for x in range(passage_start_x, min(passage_start_x + passage_width, size.x)):
				if passage_y >= 0:
					clear_tile_data(tilemap_data, Vector2i(x, passage_y))
		
		"down":
			# 下方通道：在地板開洞
			var passage_y = start_y + CELL_TILE_HEIGHT - 1
			var passage_start_x = start_x + 6  # 水平置中
			var passage_width = 4  # 通道寬度
			
			for x in range(passage_start_x, min(passage_start_x + passage_width, size.x)):
				if passage_y < size.y:
					clear_tile_data(tilemap_data, Vector2i(x, passage_y))

func set_tile_data(tilemap_data: Dictionary, coords: Vector2i, source_id: int, atlas_coords: Vector2i, alternative_tile: int = 0):
	"""設置瓦片數據"""
	tilemap_data.tiles[coords] = {
		"source_id": source_id,
		"atlas_coords": atlas_coords,
		"alternative_tile": alternative_tile
	}

func clear_tile_data(tilemap_data: Dictionary, coords: Vector2i):
	"""清除瓦片數據（創建空洞）"""
	if coords in tilemap_data.tiles:
		tilemap_data.tiles.erase(coords)

func apply_tilemap_to_layer(tilemap_layer: TileMapLayer, tilemap_data: Dictionary, tileset: TileSet = null):
	"""將生成的 TileMap 數據應用到 TileMapLayer"""
	
	if not tilemap_layer:
		print("[錯誤] TileMapLayer 為 null")
		return false
	
	# 設置 TileSet
	if tileset:
		tilemap_layer.tile_map_data = tileset
	
	# 清除現有瓦片
	tilemap_layer.clear()
	
	# 應用瓦片數據
	var tiles = tilemap_data.get("tiles", {})
	for coords in tiles:
		var tile_data = tiles[coords]
		tilemap_layer.set_cell(
			coords,
			tile_data.source_id,
			tile_data.atlas_coords,
			tile_data.alternative_tile
		)
	
	print("[TileMap] 已應用 %d 個瓦片到 TileMapLayer" % tiles.size())
	return true

func create_tilemap_layer_node(tilemap_data: Dictionary, tileset: TileSet = null, layer_name: String = "TileMapLayer") -> TileMapLayer:
	"""創建包含生成數據的 TileMapLayer 節點"""
	
	var tilemap_layer = TileMapLayer.new()
	tilemap_layer.name = layer_name
	
	# 設置 TileSet
	if tileset:
		tilemap_layer.tile_set = tileset
	
	# 應用瓦片數據
	if apply_tilemap_to_layer(tilemap_layer, tilemap_data, tileset):
		print("[TileMap] TileMapLayer 節點創建成功")
		return tilemap_layer
	else:
		print("[錯誤] TileMapLayer 節點創建失敗")
		tilemap_layer.queue_free()
		return null

func generate_preview_image(tilemap_data: Dictionary, tile_size: int = 32) -> Image:
	"""生成 TileMap 的預覽圖像"""
	
	var size = tilemap_data.get("size", Vector2i(16, 9))
	var preview_image = Image.create(size.x * tile_size, size.y * tile_size, false, Image.FORMAT_RGBA8)
	
	var tiles = tilemap_data.get("tiles", {})
	
	# 定義預設顏色
	var tile_colors = {
		0: Color.BROWN,      # 地板
		1: Color.GRAY,       # 牆壁
		2: Color.DIM_GRAY,   # 天花板
		3: Color.BLACK       # 背景
	}
	
	# 繪製瓦片
	for coords in tiles:
		var tile_data = tiles[coords]
		var atlas_coords = tile_data.get("atlas_coords", Vector2i(0, 0))
		var tile_id = atlas_coords.x
		
		var color = tile_colors.get(tile_id, Color.WHITE)
		var pixel_x = coords.x * tile_size
		var pixel_y = coords.y * tile_size
		
		# 填充瓦片區域
		for x in range(tile_size):
			for y in range(tile_size):
				if pixel_x + x < preview_image.get_width() and pixel_y + y < preview_image.get_height():
					preview_image.set_pixel(pixel_x + x, pixel_y + y, color)
	
	return preview_image

func get_tilemap_statistics(tilemap_data: Dictionary) -> Dictionary:
	"""獲取 TileMap 統計信息"""
	
	var tiles = tilemap_data.get("tiles", {})
	var size = tilemap_data.get("size", Vector2i(0, 0))
	
	# 統計瓦片類型
	var tile_counts = {}
	for coords in tiles:
		var tile_data = tiles[coords]
		var atlas_coords = tile_data.get("atlas_coords", Vector2i(0, 0))
		var tile_id = atlas_coords.x
		
		if tile_counts.has(tile_id):
			tile_counts[tile_id] += 1
		else:
			tile_counts[tile_id] = 1
	
	return {
		"total_tiles": tiles.size(),
		"map_size": size,
		"tile_counts": tile_counts,
		"fill_ratio": float(tiles.size()) / float(size.x * size.y) if size.x > 0 and size.y > 0 else 0.0
	}