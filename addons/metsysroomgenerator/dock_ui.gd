@tool
extends Control

## MetSys Room Generator 停靠面板 UI
## 
## 提供完整的用戶界面，包括：
## - 自動顏色檢測和區域配置
## - TileSet 選擇和瓦片配置
## - 房間模板設定
## - 生成控制和進度顯示

# 核心組件
var room_generator: RefCounted
var config_manager: RefCounted

# UI 元件
var main_scroll: ScrollContainer
var content_container: VBoxContainer

# 配置區域
var mapdata_section: VBoxContainer
var mapdata_path_input: LineEdit
var scan_button: Button

# 顏色配置區域
var colors_section: VBoxContainer
var colors_container: VBoxContainer
var detected_colors: Array = []

# TileSet 配置區域
var tileset_section: VBoxContainer
var tileset_path_input: LineEdit
var tileset_browse_button: Button
var tile_selector: GridContainer

# 房間模板區域
var template_section: VBoxContainer
var template_path_input: LineEdit
var template_browse_button: Button

# 生成控制區域
var generation_section: VBoxContainer
var preview_button: Button
var generate_button: Button
var progress_bar: ProgressBar
var status_label: Label

# 日誌區域
var log_section: VBoxContainer
var log_text: RichTextLabel

func _init():
	name = "MetSys Room Generator"
	custom_minimum_size = Vector2(300, 600)
	
	# 創建 UI
	setup_ui()
	
	# 載入核心組件
	load_components()
	
	# 載入配置
	load_config()

func load_components():
	# 載入核心組件類
	var RoomGenerator = load("res://addons/metsysroomgenerator/room_generator.gd")
	var ConfigManager = load("res://addons/metsysroomgenerator/config_manager.gd")
	
	if RoomGenerator and ConfigManager:
		room_generator = RoomGenerator.new()
		config_manager = ConfigManager.new()
		add_log("[系統] 核心組件載入完成")
	else:
		add_log("[錯誤] 無法載入核心組件")

func setup_ui():
	# 主滾動容器
	main_scroll = ScrollContainer.new()
	main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(main_scroll)
	main_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 主內容容器
	content_container = VBoxContainer.new()
	main_scroll.add_child(content_container)
	content_container.add_theme_constant_override("separation", 10)
	
	# 創建各個區域
	setup_mapdata_section()
	setup_colors_section()
	setup_tileset_section()
	setup_template_section()
	setup_generation_section()
	setup_log_section()

func setup_mapdata_section():
	mapdata_section = create_section("📁 MapData 配置")
	
	var path_container = HBoxContainer.new()
	mapdata_section.add_child(path_container)
	
	var path_label = Label.new()
	path_label.text = "MapData.txt 路徑："
	path_label.custom_minimum_size.x = 120
	path_container.add_child(path_label)
	
	mapdata_path_input = LineEdit.new()
	mapdata_path_input.text = "res://scenes/rooms/MapData.txt"
	mapdata_path_input.placeholder_text = "請輸入 MapData.txt 文件路徑"
	path_container.add_child(mapdata_path_input)
	
	scan_button = Button.new()
	scan_button.text = "🔍 掃描顏色"
	scan_button.pressed.connect(_on_scan_colors_pressed)
	mapdata_section.add_child(scan_button)

func setup_colors_section():
	colors_section = create_section("🎨 區域配置")
	colors_section.visible = false
	
	var help_label = Label.new()
	help_label.text = "為每個檢測到的顏色設定區域名稱："
	help_label.add_theme_color_override("font_color", Color.GRAY)
	colors_section.add_child(help_label)
	
	colors_container = VBoxContainer.new()
	colors_container.add_theme_constant_override("separation", 5)
	colors_section.add_child(colors_container)

func setup_tileset_section():
	tileset_section = create_section("🎯 TileSet 配置")
	
	var tileset_label = Label.new()
	tileset_label.text = "TileSet 路徑 (可選)："
	tileset_section.add_child(tileset_label)
	
	var tileset_container = HBoxContainer.new()
	tileset_section.add_child(tileset_container)
	
	tileset_path_input = LineEdit.new()
	tileset_path_input.placeholder_text = "如: res://assets/tileset.tres 或 tilemap.png (留空使用基本方塊房)"
	tileset_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 自動擴展填充
	tileset_path_input.text_changed.connect(_on_tileset_path_changed)
	tileset_container.add_child(tileset_path_input)
	
	tileset_browse_button = Button.new()
	tileset_browse_button.text = "瀏覽"
	tileset_browse_button.pressed.connect(_on_tileset_browse_pressed)
	tileset_container.add_child(tileset_browse_button)
	
	var tile_label = Label.new()
	tile_label.text = "瓦片選擇（基本方塊房）："
	tileset_section.add_child(tile_label)
	
	tile_selector = GridContainer.new()
	tile_selector.columns = 4
	tileset_section.add_child(tile_selector)

func setup_template_section():
	template_section = create_section("🏠 房間模板")
	
	var template_label = Label.new()
	template_label.text = "房間模板路徑 (可選)："
	template_section.add_child(template_label)
	
	var template_container = HBoxContainer.new()
	template_section.add_child(template_container)
	
	template_path_input = LineEdit.new()
	template_path_input.placeholder_text = "如: res://templates/room_template.tscn (留空使用默認)"
	template_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # 自動擴展填充
	template_container.add_child(template_path_input)
	
	template_browse_button = Button.new()
	template_browse_button.text = "瀏覽"
	template_browse_button.pressed.connect(_on_template_browse_pressed)
	template_container.add_child(template_browse_button)

func setup_generation_section():
	generation_section = create_section("🚀 生成控制")
	
	var button_container = HBoxContainer.new()
	generation_section.add_child(button_container)
	
	preview_button = Button.new()
	preview_button.text = "👁️ 預覽"
	preview_button.pressed.connect(_on_preview_pressed)
	button_container.add_child(preview_button)
	
	generate_button = Button.new()
	generate_button.text = "🏗️ 生成房間"
	generate_button.pressed.connect(_on_generate_pressed)
	button_container.add_child(generate_button)
	
	progress_bar = ProgressBar.new()
	progress_bar.visible = false
	generation_section.add_child(progress_bar)
	
	status_label = Label.new()
	status_label.text = "就緒"
	generation_section.add_child(status_label)

func setup_log_section():
	log_section = create_section("📝 日誌")
	
	log_text = RichTextLabel.new()
	log_text.custom_minimum_size.y = 150
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_section.add_child(log_text)
	
	add_log("[系統] MetSys Room Generator 已就緒")

func create_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	content_container.add_child(section)
	section.add_theme_constant_override("separation", 5)
	
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.CYAN)
	section.add_child(title_label)
	
	var separator = HSeparator.new()
	section.add_child(separator)
	
	return section

func add_log(text: String):
	if log_text:
		log_text.append_text("[color=white]" + text + "[/color]\n")
	print("[MetSys Room Generator] " + text)

# 事件處理函數
func _on_scan_colors_pressed():
	var mapdata_path = mapdata_path_input.text.strip_edges()
	
	if not FileAccess.file_exists(mapdata_path):
		add_log("[錯誤] 找不到文件: " + mapdata_path)
		return
	
	add_log("[掃描] 開始掃描 MapData.txt...")
	
	if room_generator and room_generator.has_method("scan_mapdata_colors"):
		detected_colors = room_generator.scan_mapdata_colors(mapdata_path)
		
		if detected_colors.size() > 0:
			add_log("[成功] 檢測到 %d 個顏色區域" % detected_colors.size())
			setup_color_configs()
			colors_section.visible = true
		else:
			add_log("[警告] 沒有檢測到任何顏色")
	else:
		add_log("[錯誤] 房間生成器載入失敗")

func setup_color_configs():
	# 清除現有的顏色配置
	for child in colors_container.get_children():
		child.queue_free()
	
	# 為每個顏色創建配置行
	for color_info in detected_colors:
		create_color_config_row(color_info)

func create_color_config_row(color_info: Dictionary):
	var row_container = HBoxContainer.new()
	colors_container.add_child(row_container)
	
	# 顏色預覽
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(20, 20)
	color_rect.color = Color(color_info.get("preview_color", Color.WHITE))
	row_container.add_child(color_rect)
	
	# 房間數量標籤
	var count_label = Label.new()
	count_label.text = "x%d" % color_info.get("room_count", 0)
	count_label.custom_minimum_size.x = 30
	row_container.add_child(count_label)
	
	# 區域名稱輸入
	var name_input = LineEdit.new()
	name_input.placeholder_text = "區域名稱 (如: Beginning)"
	name_input.text = color_info.get("suggested_name", "")
	name_input.custom_minimum_size.x = 150  # 設置最小寬度
	row_container.add_child(name_input)
	
	# 儲存引用以便後續使用
	color_info["ui_name_input"] = name_input

func _on_tileset_browse_pressed():
	show_file_dialog("tileset", "選擇 TileSet", ["*.tres", "*.res", "*.png", "*.jpg", "*.jpeg", "*.webp"])

func _on_template_browse_pressed():
	show_file_dialog("template", "選擇房間模板", ["*.tscn"])

func show_file_dialog(dialog_type: String, title: String, filters: Array):
	"""顯示文件選擇對話框"""
	var file_dialog = FileDialog.new()
	add_child(file_dialog)
	
	# 配置對話框
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.title = title
	file_dialog.current_dir = "res://"
	
	# 設置文件過濾器
	for filter in filters:
		file_dialog.add_filter(filter)
	
	# 連接信號
	file_dialog.file_selected.connect(_on_file_selected.bind(dialog_type))
	file_dialog.canceled.connect(_on_dialog_canceled.bind(dialog_type))
	
	# 顯示對話框
	file_dialog.popup_centered_ratio(0.7)

func _on_file_selected(path: String, dialog_type: String):
	"""處理文件選擇結果"""
	match dialog_type:
		"tileset":
			tileset_path_input.text = path
			add_log("[TileSet] 已選擇: " + path)
		"template":
			template_path_input.text = path
			add_log("[模板] 已選擇: " + path)
	
	# 清理對話框
	_cleanup_file_dialog()

func _on_dialog_canceled(dialog_type: String):
	"""處理對話框取消"""
	add_log("[%s] 取消選擇" % dialog_type.capitalize())
	_cleanup_file_dialog()

func _cleanup_file_dialog():
	"""清理文件對話框"""
	var dialogs = get_children().filter(func(child): return child is FileDialog)
	for dialog in dialogs:
		dialog.queue_free()

func _on_tileset_path_changed(new_text: String):
	"""TileSet 路徑變更處理"""
	if new_text.strip_edges().is_empty():
		clear_tile_selector()
		add_log("[TileSet] 清除瓦片選擇")
		return
		
	# 延遲載入，避免每次按鍵都觸發
	if has_method("call_deferred"):
		call_deferred("_load_tileset_preview", new_text.strip_edges())

func _load_tileset_preview(tileset_path: String):
	"""載入 TileSet 預覽"""
	if not FileAccess.file_exists(tileset_path):
		return
		
	add_log("[TileSet] 載入預覽: " + tileset_path)
	
	var tileset = null
	var loaded_resource = load(tileset_path)
	
	if loaded_resource is TileSet:
		tileset = loaded_resource
	elif loaded_resource is Texture2D:
		# 從圖片創建 TileSet
		tileset = create_tileset_from_texture(loaded_resource)
		add_log("[TileSet] 從圖片創建 TileSet")
	else:
		add_log("[錯誤] 不支持的 TileSet 格式")
		return
	
	if tileset:
		setup_tile_preview(tileset)

func create_tileset_from_texture(texture: Texture2D) -> TileSet:
	"""從圖片創建 TileSet（簡化版本）"""
	var tileset = TileSet.new()
	var atlas_source = TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(32, 32)  # 假設 32x32 瓦片
	
	# 計算瓦片數量
	var texture_size = texture.get_size()
	var cols = int(texture_size.x / 32)
	var rows = int(texture_size.y / 32)
	
	# 創建瓦片
	for y in range(min(rows, 8)):  # 限制最多 8 行
		for x in range(min(cols, 8)):  # 限制最多 8 列
			atlas_source.create_tile(Vector2i(x, y))
	
	tileset.add_source(atlas_source, 0)
	return tileset

func setup_tile_preview(tileset: TileSet):
	"""設置瓦片預覽界面"""
	clear_tile_selector()
	
	if not tileset or tileset.get_source_count() == 0:
		add_log("[錯誤] TileSet 無效或沒有瓦片源")
		return
		
	var source = tileset.get_source(0)
	if not source is TileSetAtlasSource:
		add_log("[錯誤] TileSet 源不是 AtlasSource 類型")
		return
		
	var atlas_source = source as TileSetAtlasSource
	var texture = atlas_source.texture
	if not texture:
		add_log("[錯誤] TileSet 沒有紋理")
		return
	
	# 創建瓦片選擇器標題
	var selector_label = Label.new()
	selector_label.text = "選擇瓦片用途："
	tile_selector.add_child(selector_label)
	
	# 瓦片用途配置
	var tile_purposes = [
		{"name": "地板", "key": "floor", "color": Color.BROWN},
		{"name": "牆壁", "key": "wall", "color": Color.GRAY}, 
		{"name": "天花板", "key": "ceiling", "color": Color.DARK_GRAY},
		{"name": "背景", "key": "background", "color": Color.DIM_GRAY}
	]
	
	# 為每個用途創建瓦片選擇行
	for purpose in tile_purposes:
		create_tile_selection_row(atlas_source, purpose)
	
	add_log("[TileSet] 瓦片預覽設置完成")

func create_tile_selection_row(atlas_source: TileSetAtlasSource, purpose: Dictionary):
	"""創建瓦片選擇行"""
	var row_container = HBoxContainer.new()
	tile_selector.add_child(row_container)
	
	# 用途標籤
	var purpose_label = Label.new()
	purpose_label.text = purpose.name + ":"
	purpose_label.custom_minimum_size.x = 60
	purpose_label.add_theme_color_override("font_color", purpose.color)
	row_container.add_child(purpose_label)
	
	# 瓦片預覽按鈕網格
	var tiles_container = HBoxContainer.new()
	row_container.add_child(tiles_container)
	
	# 獲取所有可用的瓦片
	var tile_count = 0
	for i in range(8):  # 最多顯示 8 個瓦片
		for j in range(8):
			var atlas_coords = Vector2i(i, j)
			if atlas_source.has_tile(atlas_coords):
				var tile_button = create_tile_button(atlas_source, atlas_coords, purpose.key)
				tiles_container.add_child(tile_button)
				tile_count += 1
				if tile_count >= 8:  # 每行最多 8 個
					break
		if tile_count >= 8:
			break

func create_tile_button(atlas_source: TileSetAtlasSource, atlas_coords: Vector2i, purpose_key: String) -> Button:
	"""創建瓦片選擇按鈕"""
	var tile_button = Button.new()
	tile_button.custom_minimum_size = Vector2(40, 40)
	tile_button.tooltip_text = "瓦片 (%d,%d)" % [atlas_coords.x, atlas_coords.y]
	
	# 創建瓦片預覽圖像
	var texture = atlas_source.texture
	if texture:
		var region_size = atlas_source.texture_region_size
		var region = Rect2(
			Vector2(atlas_coords.x * region_size.x, atlas_coords.y * region_size.y),
			region_size
		)
		
		# 創建簡單的圖標（使用 TextureRect 代替）
		var texture_rect = TextureRect.new()
		texture_rect.texture = texture
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.custom_minimum_size = Vector2(32, 32)
		tile_button.add_child(texture_rect)
	
	# 連接點擊事件
	tile_button.pressed.connect(_on_tile_selected.bind(atlas_coords, purpose_key))
	
	return tile_button

func _on_tile_selected(atlas_coords: Vector2i, purpose_key: String):
	"""處理瓦片選擇"""
	add_log("[瓦片] 選擇 %s 瓦片: (%d,%d)" % [purpose_key, atlas_coords.x, atlas_coords.y])
	
	# 儲存瓦片選擇到配置（後續在 get_current_config 中使用）
	if not has_meta("selected_tiles"):
		set_meta("selected_tiles", {})
	
	var selected_tiles = get_meta("selected_tiles")
	selected_tiles[purpose_key] = atlas_coords
	set_meta("selected_tiles", selected_tiles)

func clear_tile_selector():
	for child in tile_selector.get_children():
		child.queue_free()

func _on_preview_pressed():
	add_log("[預覽] 生成預覽...")
	
	# 驗證配置
	var config = get_current_config()
	var validation_errors = validate_generation_config(config)
	
	if not validation_errors.is_empty():
		add_log("[錯誤] 配置驗證失敗:")
		for error in validation_errors:
			add_log("  • " + error)
		return
	
	# 生成房間預覽
	if room_generator and room_generator.has_method("generate_rooms_from_config"):
		var rooms_to_generate = room_generator.generate_rooms_from_config(config, detected_colors)
		
		if rooms_to_generate.is_empty():
			add_log("[信息] 沒有房間需要生成")
			return
		
		show_generation_preview(rooms_to_generate)
		add_log("[預覽] 找到 %d 個房間需要生成" % rooms_to_generate.size())

func _on_generate_pressed():
	add_log("[生成] 開始房間生成...")
	
	# 驗證配置
	var config = get_current_config()
	var validation_errors = validate_generation_config(config)
	
	if not validation_errors.is_empty():
		add_log("[錯誤] 配置驗證失敗:")
		for error in validation_errors:
			add_log("  • " + error)
		return
	
	# 禁用生成按鈕
	generate_button.disabled = true
	progress_bar.visible = true
	status_label.text = "準備生成..."
	
	# 開始異步生成
	start_room_generation(config)

func validate_generation_config(config: Dictionary) -> Array:
	"""驗證生成配置"""
	var errors = []
	
	# 檢查 MapData 路徑
	var mapdata_path = config.get("mapdata_path", "")
	if mapdata_path.is_empty():
		errors.append("MapData 路徑不能為空")
	elif not FileAccess.file_exists(mapdata_path):
		errors.append("MapData 文件不存在: " + mapdata_path)
	
	# 檢查顏色配置
	var color_mappings = config.get("color_mappings", {})
	if color_mappings.is_empty():
		errors.append("沒有配置任何顏色映射")
	
	# 檢查是否有檢測到的顏色
	if detected_colors.is_empty():
		errors.append("尚未掃描顏色，請先點擊'掃描顏色'")
	
	return errors

func show_generation_preview(rooms_to_generate: Array):
	"""顯示生成預覽"""
	var preview_text = "[color=cyan][b]📋 生成預覽：[/b][/color]\n\n"
	
	# 按區域分組顯示
	var area_groups = {}
	for room_data in rooms_to_generate:
		var color_code = room_data.get("color", "")
		var color_config = get_current_config().color_mappings.get(color_code, {})
		var area_name = color_config.get("area_name", "Unknown")
		
		if not area_groups.has(area_name):
			area_groups[area_name] = []
		area_groups[area_name].append(room_data)
	
	for area_name in area_groups.keys():
		var rooms = area_groups[area_name]
		preview_text += "[color=yellow][b]%s 區域：[/b][/color]\n" % area_name
		
		for room_data in rooms:
			var room_name = room_data.get("name", "Unknown")
			var cell_count = room_data.get("cells", []).size()
			preview_text += "  • [color=white]%s[/color] ([color=gray]%d個cell[/color])\n" % [room_name, cell_count]
		
		preview_text += "\n"
	
	preview_text += "[color=cyan]總計需要生成：[b]%d[/b] 個房間[/color]" % rooms_to_generate.size()
	
	# 顯示在日誌中
	add_log(preview_text)

func start_room_generation(config: Dictionary):
	"""開始房間生成過程"""
	
	# 獲取需要生成的房間
	var rooms_to_generate = room_generator.generate_rooms_from_config(config, detected_colors)
	
	if rooms_to_generate.is_empty():
		add_log("[信息] 沒有房間需要生成")
		finish_generation()
		return
	
	# 載入工具類時遇到問題，暫時停用
	add_log("[警告] 房間生成功能暫時不可用")
	add_log("[信息] 檢查文檔了解已知問題和解決方案")
	
	var success_count = 0
	var failed_count = rooms_to_generate.size()
	
	# 顯示錯誤信息
	for room_data in rooms_to_generate:
		var room_name = room_data.get("name", "Unknown")
		add_log("[跳過] %s - 生成功能暫時不可用" % room_name)
	
	# 完成生成
	progress_bar.value = rooms_to_generate.size()
	
	if failed_count == 0:
		status_label.text = "✅ 全部完成！成功生成 %d 個房間" % success_count
		add_log("[完成] 🎉 所有房間生成成功！")
	else:
		status_label.text = "⚠️ 完成：成功 %d，失敗 %d" % [success_count, failed_count]
		add_log("[完成] ⚠️ 生成結果：成功 %d，失敗 %d" % [success_count, failed_count])
	
	finish_generation()

func generate_single_room(room_data: Dictionary, tilemap_builder, scene_creator, config: Dictionary) -> bool:
	"""生成單個房間"""
	
	var room_name = room_data.get("name", "Unknown")
	
	# 檢查 room_data 基本結構
	if not room_data.has("cells") or room_data.cells.is_empty():
		add_log("[錯誤] %s: room_data 缺少 cells 數據" % room_name)
		return false
	
	# 生成 TileMap 數據
	add_log("[詳細] %s: 開始生成 TileMap 數據..." % room_name)
	var tilemap_data = null
	
	# 添加錯誤捕獲
	if tilemap_builder and tilemap_builder.has_method("generate_room_tilemap"):
		tilemap_data = tilemap_builder.generate_room_tilemap(room_data, config)
	else:
		add_log("[錯誤] %s: TileMap 生成器載入失敗" % room_name)
		return false
	
	if not tilemap_data:
		add_log("[錯誤] %s: TileMap 數據生成失敗" % room_name)
		return false
	
	add_log("[詳細] %s: TileMap 數據生成成功" % room_name)
	
	# 創建場景文件
	add_log("[詳細] %s: 開始創建場景文件..." % room_name)
	var success = false
	
	if scene_creator and scene_creator.has_method("create_room_scene"):
		success = scene_creator.create_room_scene(room_data, tilemap_data, config)
	else:
		add_log("[錯誤] %s: 場景創建器載入失敗" % room_name)
		return false
	
	if not success:
		add_log("[錯誤] %s: 場景文件創建失敗" % room_name)
		return false
	
	add_log("[詳細] %s: 場景文件創建成功" % room_name)
	return success

func finish_generation():
	"""完成生成過程"""
	generate_button.disabled = false
	progress_bar.visible = false
	
	# 保存配置
	save_config()

func load_config():
	if config_manager and config_manager.has_method("load_config"):
		var config = config_manager.load_config()
		if config:
			apply_config(config)
			add_log("[配置] 配置文件載入完成")

func apply_config(config: Dictionary):
	# 應用載入的配置
	if config.has("mapdata_path"):
		mapdata_path_input.text = config.mapdata_path
	
	# TileSet 配置
	if config.has("tileset_path"):
		tileset_path_input.text = config.tileset_path
		# 如果有 TileSet 路徑，觸發預覽載入
		if not config.tileset_path.is_empty():
			call_deferred("_load_tileset_preview", config.tileset_path)
	
	# 瓦片選擇配置
	if config.has("selected_tiles"):
		set_meta("selected_tiles", config.selected_tiles)
	
	# 房間模板配置
	if config.has("room_template"):
		template_path_input.text = config.room_template

func save_config():
	if config_manager and config_manager.has_method("save_config"):
		var config = get_current_config()
		config_manager.save_config(config)
		add_log("[配置] 配置已保存")

func get_current_config() -> Dictionary:
	var config = {}
	config["mapdata_path"] = mapdata_path_input.text
	
	# 顏色映射配置
	config["color_mappings"] = {}
	for color_info in detected_colors:
		if color_info.has("ui_name_input"):
			var area_name = color_info.ui_name_input.text
			config["color_mappings"][color_info.color_code] = {
				"area_name": area_name,
				"folder": area_name.to_lower(),
				"prefix": area_name
			}
	
	# TileSet 配置
	config["tileset_path"] = tileset_path_input.text.strip_edges()
	
	# 瓦片選擇配置
	if has_meta("selected_tiles"):
		config["selected_tiles"] = get_meta("selected_tiles")
	else:
		config["selected_tiles"] = {}
	
	# 房間模板配置
	config["room_template"] = template_path_input.text.strip_edges()
	
	return config


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_config()
