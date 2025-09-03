@tool
extends RefCounted

## 房間生成器核心邏輯
## 
## 包含以下功能：
## - 自動掃描 MapData.txt 並檢測顏色
## - 使用 flood-fill 算法識別房間群組
## - 智能房間編號分配
## - TileMap 生成和場景創建

# 常量定義
const CELL_TILE_WIDTH = 16   # 每個 MetSys cell 的瓦片寬度
const CELL_TILE_HEIGHT = 9   # 每個 MetSys cell 的瓦片高度

# 顏色預設建議
const COLOR_SUGGESTIONS = {
	"24d6da,,,,": {
		"name": "Beginning",
		"folder": "beginning",
		"prefix": "Beginning",
		"preview_color": Color(0.14, 0.84, 0.85)  # 青藍色
	},
	"4be021,,,,": {
		"name": "Jungle", 
		"folder": "jungle",
		"prefix": "Jungle",
		"preview_color": Color(0.29, 0.88, 0.13)  # 綠色
	},
	"e4b015,,,,": {
		"name": "Fortress",
		"folder": "fortress", 
		"prefix": "Fortress",
		"preview_color": Color(0.89, 0.69, 0.08)  # 金黃色
	},
	"e04a21,,,,": {
		"name": "Village",
		"folder": "village",
		"prefix": "Village", 
		"preview_color": Color(0.88, 0.29, 0.13)  # 紅色
	},
	"8b15e4,,,,": {
		"name": "Mountain",
		"folder": "mountain",
		"prefix": "Mountain",
		"preview_color": Color(0.55, 0.08, 0.89)  # 紫色
	}
}

func scan_mapdata_colors(mapdata_path: String) -> Array:
	"""掃描 MapData.txt 並檢測所有顏色代碼"""
	print("[掃描] 開始掃描 MapData.txt: " + mapdata_path)
	
	var mapdata = load_mapdata(mapdata_path)
	if mapdata.is_empty():
		print("[錯誤] MapData.txt 載入失敗或為空")
		return []
	
	# 統計顏色出現次數
	var color_stats = {}
	
	for coord in mapdata:
		var cell_data = mapdata[coord]
		var color = cell_data.get("color", "")
		
		if not color.is_empty():
			if color_stats.has(color):
				color_stats[color] += 1
			else:
				color_stats[color] = 1
	
	print("[掃描] 找到 %d 個不同的顏色" % color_stats.size())
	
	# 使用 flood-fill 算法計算實際房間數量
	var room_groups = identify_room_groups_by_color(mapdata)
	
	# 建立顏色資訊陣列
	var detected_colors = []
	
	for color in color_stats:
		var color_info = {
			"color_code": color,
			"cell_count": color_stats[color],
			"room_count": get_room_count_for_color(room_groups, color),
			"preview_color": Color.WHITE,
			"suggested_name": "",
			"suggested_folder": "",
			"suggested_prefix": ""
		}
		
		# 應用預設建議
		if COLOR_SUGGESTIONS.has(color):
			var suggestion = COLOR_SUGGESTIONS[color]
			color_info["preview_color"] = suggestion.preview_color
			color_info["suggested_name"] = suggestion.name
			color_info["suggested_folder"] = suggestion.folder
			color_info["suggested_prefix"] = suggestion.prefix
		else:
			# 為未知顏色生成建議
			var suggestion = generate_color_suggestion(color)
			color_info.merge(suggestion)
		
		detected_colors.append(color_info)
		print("[檢測] 顏色: %s, Cells: %d, 房間: %d" % [color, color_info.cell_count, color_info.room_count])
	
	# 按房間數量排序
	detected_colors.sort_custom(func(a, b): return a.room_count > b.room_count)
	
	return detected_colors

func load_mapdata(file_path: String) -> Dictionary:
	"""載入並解析 MapData.txt 文件"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[錯誤] 無法打開文件: " + file_path)
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var lines = content.split("\n")
	var mapdata = {}
	
	var i = 0
	while i < lines.size():
		var line = lines[i].strip_edges()
		
		# 跳過空行和註解
		if line.is_empty() or line.begins_with("#") or line.begins_with("$"):
			i += 1
			continue
		
		# 解析座標行 [x,y,z]
		if line.begins_with("[") and line.ends_with("]"):
			var coord_str = line.substr(1, line.length() - 2)
			var coords = coord_str.split(",")
			
			if coords.size() == 3:
				var x = coords[0].to_int()
				var y = coords[1].to_int() 
				var z = coords[2].to_int()
				var coord = Vector3i(x, y, z)
				
				# 下一行是 cell 數據
				i += 1
				if i < lines.size():
					var data_line = lines[i].strip_edges()
					var cell_data = parse_cell_data(data_line)
					if cell_data:
						mapdata[coord] = cell_data
		
		i += 1
	
	print("[載入] 解析得到 %d 個 cell 數據" % mapdata.size())
	return mapdata

func parse_cell_data(data_line: String) -> Dictionary:
	"""解析 cell 數據行"""
	if not "|" in data_line:
		return {}
	
	var parts = data_line.split("|")
	if parts.size() < 2:
		return {}
	
	# 解析 borders [右,下,左,上]
	var borders_str = parts[0]
	var borders = []
	for border_val in borders_str.split(","):
		borders.append(border_val.to_int())
	
	var color = parts[1] if parts.size() > 1 else ""
	var symbol = parts[2] if parts.size() > 2 else ""
	var scene = parts[3] if parts.size() > 3 else ""
	
	return {
		"borders": borders,
		"color": color,
		"symbol": symbol,
		"scene": scene
	}

func identify_room_groups_by_color(mapdata: Dictionary) -> Dictionary:
	"""使用 flood-fill 算法按顏色識別房間群組"""
	var room_groups_by_color = {}
	var processed = {}
	
	for coord in mapdata:
		if coord in processed:
			continue
		
		var cell_data = mapdata[coord]
		var color = cell_data.get("color", "")
		
		if color.is_empty():
			processed[coord] = true
			continue
		
		# 使用 flood-fill 找出連通的房間
		var room_cells = flood_fill_room(coord, mapdata, processed)
		
		if room_cells.size() > 0:
			# 建立房間數據
			var room_data = build_room_data(room_cells, mapdata)
			
			# 按顏色分組
			if not room_groups_by_color.has(color):
				room_groups_by_color[color] = []
			room_groups_by_color[color].append(room_data)
	
	return room_groups_by_color

func flood_fill_room(start_coords: Vector3i, cells: Dictionary, processed: Dictionary) -> Array:
	"""實現 MetSys 的 get_whole_room 算法"""
	var room = []
	var to_check = [Vector2i(start_coords.x, start_coords.y)]
	var checked = []
	
	# 方向向量：右、下、左、上
	var FWD = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]
	
	while to_check.size() > 0:
		var p = to_check.pop_back()
		checked.append(p)
		
		var coords = Vector3i(p.x, p.y, start_coords.z)
		if coords in cells:
			room.append(coords)
			processed[coords] = true
			
			# 檢查四個方向
			for i in 4:
				if cells[coords].borders[i] == -1:  # -1表示封閉牆（同一房間）
					var p2 = p + FWD[i]
					if not p2 in to_check and not p2 in checked:
						to_check.append(p2)
	
	return room

func build_room_data(room_cells: Array, mapdata: Dictionary) -> Dictionary:
	"""建立房間數據結構"""
	var first_cell = room_cells[0]
	var cell_data = mapdata[first_cell]
	var color = cell_data.color
	
	# 計算房間邊界
	var min_x = room_cells[0].x
	var max_x = room_cells[0].x
	var min_y = room_cells[0].y
	var max_y = room_cells[0].y
	
	for coord in room_cells:
		min_x = min(min_x, coord.x)
		max_x = max(max_x, coord.x)
		min_y = min(min_y, coord.y)
		max_y = max(max_y, coord.y)
	
	var bounds = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	
	# 建立 cell 數據字典
	var cell_data_dict = {}
	for coord in room_cells:
		cell_data_dict[coord] = mapdata[coord]
	
	return {
		"cells": room_cells,
		"cell_data": cell_data_dict,
		"color": color,
		"bounds": bounds,
		"size": Vector2i(bounds.size.x, bounds.size.y)
	}

func get_room_count_for_color(room_groups: Dictionary, color: String) -> int:
	"""獲取指定顏色的房間數量"""
	if room_groups.has(color):
		return room_groups[color].size()
	return 0

func generate_color_suggestion(color_code: String) -> Dictionary:
	"""為未知顏色生成建議配置"""
	# 嘗試解析顏色代碼的第一部分作為顏色值
	var color_parts = color_code.split(",")
	var color_hex = color_parts[0] if color_parts.size() > 0 else "ffffff"
	
	var preview_color = Color.WHITE
	if color_hex.length() == 6:
		# 嘗試解析十六進制顏色
		var r = ("0x" + color_hex.substr(0, 2)).hex_to_int() / 255.0
		var g = ("0x" + color_hex.substr(2, 2)).hex_to_int() / 255.0
		var b = ("0x" + color_hex.substr(4, 2)).hex_to_int() / 255.0
		preview_color = Color(r, g, b)
	
	# 生成基於顏色的建議名稱
	var name_suggestion = "Area" + color_hex.substr(0, 3).capitalize()
	
	return {
		"preview_color": preview_color,
		"suggested_name": name_suggestion,
		"suggested_folder": name_suggestion.to_lower(),
		"suggested_prefix": name_suggestion
	}

func generate_rooms_from_config(config: Dictionary, detected_colors: Array) -> Array:
	"""基於配置和檢測到的顏色生成房間"""
	var mapdata_path = config.get("mapdata_path", "")
	var mapdata = load_mapdata(mapdata_path)
	
	if mapdata.is_empty():
		print("[錯誤] 無法載入 MapData")
		return []
	
	# 識別房間群組
	var room_groups_by_color = identify_room_groups_by_color(mapdata)
	
	# 過濾已存在的房間並重新分配編號
	var rooms_to_generate = []
	
	for color_info in detected_colors:
		var color_code = color_info.color_code
		var color_config = config.color_mappings.get(color_code, {})
		
		if color_config.is_empty():
			print("[跳過] 顏色 %s 沒有配置" % color_code)
			continue
		
		if room_groups_by_color.has(color_code):
			var room_groups = room_groups_by_color[color_code]
			
			# 過濾已存在的房間
			var filtered_rooms = filter_existing_rooms(room_groups)
			
			# 重新分配編號
			assign_sequential_room_names(filtered_rooms, color_config)
			
			rooms_to_generate.append_array(filtered_rooms)
	
	return rooms_to_generate

func filter_existing_rooms(room_groups: Array) -> Array:
	"""過濾已存在的房間"""
	var rooms_to_generate = []
	
	for room_data in room_groups:
		var has_existing_scene = false
		for cell in room_data.cells:
			var cell_data = room_data.cell_data[cell]
			if cell_data.scene and not cell_data.scene.is_empty():
				print("[跳過] 已存在房間: %s" % cell_data.scene)
				has_existing_scene = true
				break
		
		if not has_existing_scene:
			rooms_to_generate.append(room_data)
	
	return rooms_to_generate

func assign_sequential_room_names(room_groups: Array, color_config: Dictionary):
	"""分配連續的房間編號"""
	var folder = color_config.get("folder", "unknown")
	var prefix = color_config.get("prefix", "Room")
	
	# 獲取現有房間編號
	var existing_numbers = get_existing_room_numbers(folder, prefix)
	
	# 為房間分配連續編號
	var next_number = 1
	for room_data in room_groups:
		# 找到下一個可用編號
		while next_number in existing_numbers:
			next_number += 1
		
		# 更新房間名稱
		var room_name = "%s%d" % [prefix, next_number]
		room_data["name"] = room_name
		
		# 記錄已使用的編號
		existing_numbers.append(next_number)
		next_number += 1

func get_existing_room_numbers(folder: String, prefix: String) -> Array:
	"""獲取現有的房間編號列表"""
	var folder_path = "res://scenes/rooms/" + folder + "/"
	var dir = DirAccess.open(folder_path)
	
	if not dir:
		return []
	
	var existing_numbers = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var name_without_ext = file_name.get_basename()
			# 檢查是否符合格式並提取編號
			if name_without_ext.begins_with(prefix):
				var number_str = name_without_ext.substr(prefix.length())
				if number_str.is_valid_int():
					existing_numbers.append(number_str.to_int())
		file_name = dir.get_next()
	
	return existing_numbers