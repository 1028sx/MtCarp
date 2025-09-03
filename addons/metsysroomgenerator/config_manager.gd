@tool
extends RefCounted

## 配置管理器
## 
## 負責處理用戶配置的載入、保存和管理
## 所有配置文件都保存在工具目錄內，不會影響專案

const CONFIG_FILE_PATH = "res://addons/metsysroomgenerator/config.json"
const DEFAULT_CONFIG_PATH = "res://addons/metsysroomgenerator/examples/default_config.json"

var current_config: Dictionary = {}

func _init():
	load_default_config()

func load_config() -> Dictionary:
	"""載入配置文件，如果不存在則使用默認配置"""
	
	# 嘗試載入用戶配置
	if FileAccess.file_exists(CONFIG_FILE_PATH):
		var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_text)
			
			if parse_result == OK:
				current_config = json.get_data()
				print("[配置] 用戶配置載入成功")
				return current_config
			else:
				print("[配置] 配置文件格式錯誤，使用默認配置")
				return load_default_config()
		else:
			print("[配置] 無法讀取配置文件，使用默認配置")
			return load_default_config()
	else:
		print("[配置] 配置文件不存在，使用默認配置")
		return load_default_config()

func load_default_config() -> Dictionary:
	"""載入默認配置"""
	current_config = {
		"mapdata_path": "res://scenes/rooms/MapData.txt",
		"color_mappings": {
			"24d6da,,,,": {
				"area_name": "Beginning",
				"folder": "beginning",
				"prefix": "Beginning"
			},
			"4be021,,,,": {
				"area_name": "Jungle",
				"folder": "jungle",
				"prefix": "Jungle"
			},
			"e4b015,,,,": {
				"area_name": "Fortress",
				"folder": "fortress",
				"prefix": "Fortress"
			},
			"e04a21,,,,": {
				"area_name": "Village",
				"folder": "village",
				"prefix": "Village"
			},
			"8b15e4,,,,": {
				"area_name": "Mountain",
				"folder": "mountain",
				"prefix": "Mountain"
			}
		},
		"tileset_path": "",
		"selected_tiles": [0, 1, 2, 3],  # 基本方塊房瓦片ID
		"room_template": "",
		"included_nodes": ["RoomInstance", "DeathZone"],
		"generation_settings": {
			"create_spawn_points": true,
			"create_room_boundaries": true,
			"tile_size": 32
		}
	}
	
	# 保存默認配置作為範例
	save_default_config()
	return current_config

func save_config(config: Dictionary) -> bool:
	"""保存配置到文件"""
	current_config = config
	
	var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(config, "\t")
		file.store_string(json_string)
		file.close()
		print("[配置] 配置已保存到: " + CONFIG_FILE_PATH)
		return true
	else:
		print("[配置] 無法保存配置文件")
		return false

func save_default_config():
	"""保存默認配置作為範例"""
	var file = FileAccess.open(DEFAULT_CONFIG_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(current_config, "\t")
		file.store_string(json_string)
		file.close()

func get_config_value(key: String, default_value = null):
	"""獲取配置值"""
	return current_config.get(key, default_value)

func set_config_value(key: String, value):
	"""設定配置值"""
	current_config[key] = value

func get_color_mapping(color_code: String) -> Dictionary:
	"""獲取顏色映射配置"""
	var mappings = current_config.get("color_mappings", {})
	return mappings.get(color_code, {})

func set_color_mapping(color_code: String, mapping: Dictionary):
	"""設定顏色映射"""
	if not current_config.has("color_mappings"):
		current_config["color_mappings"] = {}
	current_config["color_mappings"][color_code] = mapping

func validate_config() -> Array:
	"""驗證配置的有效性，返回錯誤列表"""
	var errors = []
	
	# 檢查 MapData 路徑
	var mapdata_path = get_config_value("mapdata_path", "")
	if mapdata_path.is_empty():
		errors.append("MapData 路徑不能為空")
	elif not FileAccess.file_exists(mapdata_path):
		errors.append("MapData 文件不存在: " + mapdata_path)
	
	# 檢查顏色映射
	var color_mappings = get_config_value("color_mappings", {})
	if color_mappings.is_empty():
		errors.append("沒有設定任何顏色映射")
	else:
		for color_code in color_mappings:
			var mapping = color_mappings[color_code]
			if not mapping.has("area_name") or mapping.area_name.is_empty():
				errors.append("顏色 %s 缺少區域名稱" % color_code)
			if not mapping.has("folder") or mapping.folder.is_empty():
				errors.append("顏色 %s 缺少資料夾設定" % color_code)
			if not mapping.has("prefix") or mapping.prefix.is_empty():
				errors.append("顏色 %s 缺少房間前綴" % color_code)
	
	# 檢查 TileSet 路徑（如果設定了）
	var tileset_path = get_config_value("tileset_path", "")
	if not tileset_path.is_empty() and not FileAccess.file_exists(tileset_path):
		errors.append("TileSet 文件不存在: " + tileset_path)
	
	# 檢查房間模板（如果設定了）
	var room_template = get_config_value("room_template", "")
	if not room_template.is_empty() and not FileAccess.file_exists(room_template):
		errors.append("房間模板文件不存在: " + room_template)
	
	return errors

func reset_to_default():
	"""重置為默認配置"""
	load_default_config()
	save_config(current_config)