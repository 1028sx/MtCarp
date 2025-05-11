extends CanvasLayer

# 不使用@onready，改為在_ready中直接獲取節點
var boss_health_bar = null
var boss_hp_decors = []

func _ready():
	add_to_group("boss_ui")
	
	# 確保場景樹完全加載
	await get_tree().process_frame
	await get_tree().process_frame  # 多等一幀確保節點已加載
	
	print("[BossUI] 開始初始化，診斷節點結構")
	print("[BossUI] 節點路徑: ", get_path())
	
	# 檢查是否為正確的父節點
	_check_parent_node()
	
	_debug_print_scene_tree(get_tree().root, 0)
	
	# 嘗試獲取節點引用
	var control_hud = get_node_or_null("Control_BossHUD")
	if not control_hud:
		print("[BossUI] 錯誤：找不到Control_BossHUD節點！檢查場景結構是否正確")
		print("[BossUI] 當前節點的子節點:")
		for child in get_children():
			print("  - ", child.name)
	else:
		print("[BossUI] 找到Control_BossHUD節點")
		boss_health_bar = control_hud.get_node_or_null("TextureProgressBar_BossHP")
		if boss_health_bar:
			print("[BossUI] 找到血條節點")
			boss_hp_decors = [
				control_hud.get_node_or_null("TextureRect_Deer1"),
				control_hud.get_node_or_null("TextureRect_Deer2"),
				control_hud.get_node_or_null("TextureRect_Deer3"),
				control_hud.get_node_or_null("TextureRect_Deer4"),
				control_hud.get_node_or_null("TextureRect_Deer5")
			]
			
			# 檢查裝飾物節點
			for i in range(boss_hp_decors.size()):
				if boss_hp_decors[i]:
					print("[BossUI] 找到裝飾物", i+1)
				else:
					print("[BossUI] 錯誤：找不到裝飾物", i+1)
		else:
			print("[BossUI] 錯誤：找不到TextureProgressBar_BossHP節點！")
			print("[BossUI] Control_BossHUD的子節點:")
			for child in control_hud.get_children():
				print("  - ", child.name)
	
	_initialize_ui()
	
	# 連接節點添加信號
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	
	# 檢查當前場景是否已有Boss
	call_deferred("_check_existing_boss")

# 檢查父節點是否正確
func _check_parent_node():
	var parent = get_parent()
	if not parent:
		print("[BossUI] 錯誤：BossUI沒有父節點！")
		return false
	
	if parent.name == "Main":
		print("[BossUI] 正確：BossUI是Main的子節點")
		return true
	elif parent.name == "root":
		print("[BossUI] 錯誤：BossUI是root的子節點，這表示它被設置為autoload！應該是Main的子節點")
		# 這裡可以嘗試自動修復，但建議從project.godot中移除autoload配置
		return false
	else:
		print("[BossUI] 警告：BossUI的父節點是 ", parent.name, "，預期為Main")
		return false

# 調試函數：打印完整場景樹
func _debug_print_scene_tree(node, indent_level):
	var indent = ""
	for i in range(indent_level):
		indent += "  "
	
	print(indent + "- " + node.name + " (" + node.get_class() + ")" + " 路徑:" + str(node.get_path()))
	
	for child in node.get_children():
		_debug_print_scene_tree(child, indent_level + 1)

func _initialize_ui():
	if boss_health_bar:
		print("[BossUI] 初始化血條和裝飾物")
		boss_health_bar.hide()
		
		# 檢查血條的屬性
		print("[BossUI] 血條屬性：位置=", boss_health_bar.position, " 尺寸=", boss_health_bar.size, " 縮放=", boss_health_bar.scale)
		
		# 檢查裝飾物的屬性
		for i in range(boss_hp_decors.size()):
			var decor = boss_hp_decors[i]
			if decor:
				print("[BossUI] 裝飾物", i+1, "屬性：位置=", decor.position, " 尺寸=", decor.size)
				decor.hide()
	else:
		print("[BossUI] 無法初始化UI，節點引用不存在")

# 診斷函數：檢查場景路徑
func _diagnose_scene_path():
	var scenes = {}
	_collect_scenes(get_tree().root, scenes)
	print("[BossUI] 場景診斷結果:")
	for path in scenes:
		print("  - ", path, ": ", scenes[path])

# 輔助函數：收集場景路徑
func _collect_scenes(node, scenes):
	if node.get_filename() != "":
		scenes[node.get_path()] = node.get_filename()
	
	for child in node.get_children():
		_collect_scenes(child, scenes)

func _check_existing_boss():
	# 檢查當前場景是否已有Boss
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		print("[BossUI] 發現Boss節點:", boss.name, "路徑:", boss.get_path())
		_connect_boss_signals(boss)

func _exit_tree():
	if get_tree():
		if get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)
		
		# 斷開 boss 信號
		var boss = get_tree().get_first_node_in_group("boss")
		if boss:
			if boss.health_changed.is_connected(_on_boss_health_changed):
				boss.health_changed.disconnect(_on_boss_health_changed)
			if boss.phase_changed.is_connected(_on_boss_phase_changed):
				boss.phase_changed.disconnect(_on_boss_phase_changed)
			if boss.boss_defeated.is_connected(_on_boss_defeated):
				boss.boss_defeated.disconnect(_on_boss_defeated)

func _on_node_added(node: Node):
	if node.is_in_group("boss"):
		print("[BossUI] 新增Boss節點:", node.name)
		call_deferred("_connect_boss_signals", node)

func _connect_boss_signals(boss: Node) -> void:
	print("[BossUI] 嘗試連接Boss信號")
	
	# 先斷開可能存在的連接
	if boss.has_signal("health_changed") and boss.health_changed.is_connected(_on_boss_health_changed):
		boss.health_changed.disconnect(_on_boss_health_changed)
	if boss.has_signal("phase_changed") and boss.phase_changed.is_connected(_on_boss_phase_changed):
		boss.phase_changed.disconnect(_on_boss_phase_changed)
	if boss.has_signal("boss_defeated") and boss.boss_defeated.is_connected(_on_boss_defeated):
		boss.boss_defeated.disconnect(_on_boss_defeated)
	# 檢查舊版信號
	if boss.has_signal("defeated") and boss.defeated.is_connected(_on_boss_defeated):
		boss.defeated.disconnect(_on_boss_defeated)
	
	# 重新連接信號
	if boss.has_signal("health_changed"):
		boss.health_changed.connect(_on_boss_health_changed)
		print("[BossUI] 已連接health_changed信號")
	else:
		print("[BossUI] 警告：Boss沒有health_changed信號")
		
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(_on_boss_phase_changed)
		print("[BossUI] 已連接phase_changed信號")
	else:
		print("[BossUI] 警告：Boss沒有phase_changed信號")
	
	# 處理不同名稱的擊敗信號
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
		print("[BossUI] 已連接boss_defeated信號")
	elif boss.has_signal("defeated"):  # 舊版信號名稱
		boss.defeated.connect(_on_boss_defeated)
		print("[BossUI] 已連接defeated信號(舊版)")
	else:
		print("[BossUI] 警告：Boss沒有boss_defeated或defeated信號")
	
	# 在deer.gd中添加current_health屬性的兼容處理
	if boss_health_bar:
		print("[BossUI] 更新血條數據")
		if boss.has_method("get_max_health") and boss.has_method("get_current_health"):
			boss_health_bar.max_value = boss.get_max_health()
			boss_health_bar.value = boss.get_current_health()
			print("[BossUI] 使用getter方法獲取血量:", boss.get_current_health(), "/", boss.get_max_health())
		elif "max_health" in boss and "current_health" in boss:
			boss_health_bar.max_value = boss.max_health
			boss_health_bar.value = boss.current_health
			print("[BossUI] 使用屬性獲取血量:", boss.current_health, "/", boss.max_health)
		else:
			# 最後的兼容方案
			boss_health_bar.max_value = boss.max_health if "max_health" in boss else 1000
			boss_health_bar.value = boss.health if "health" in boss else 1000
			print("[BossUI] 使用兼容方式獲取血量")
		
		boss_health_bar.show()
		# 顯示所有裝飾
		for decor in boss_hp_decors:
			if decor:
				decor.show()
	else:
		print("[BossUI] 錯誤：無法更新血條，boss_health_bar不存在")

func _on_boss_phase_changed(phase: int) -> void:
	print("[BossUI] 收到 phase_changed 信號，階段：", phase)
	
	if boss_health_bar:
		boss_health_bar.show()
		for decor in boss_hp_decors:
			if decor:
				decor.show()
	else:
		print("[BossUI] 錯誤：無法顯示UI，boss_health_bar不存在")

func _on_boss_health_changed(current: float, max_health: float) -> void:
	print("[BossUI] 收到 health_changed 信號，血量：", current, "/", max_health)
	
	if boss_health_bar:
		# 確保血條顯示
		if not boss_health_bar.visible:
			boss_health_bar.show()
			# 顯示所有裝飾
			for decor in boss_hp_decors:
				if decor:
					decor.show()
		
		# 更新血條數值		
		boss_health_bar.max_value = max_health
		boss_health_bar.value = current
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(boss_health_bar, "value", current, 0.3)
	else:
		print("[BossUI] 錯誤：無法更新血條，boss_health_bar不存在")

func _on_boss_defeated() -> void:
	print("[BossUI] 收到 boss_defeated 信號")
	if boss_health_bar:
		boss_health_bar.hide()
		# 隱藏所有裝飾
		for decor in boss_hp_decors:
			if decor:
				decor.hide()
	else:
		print("[BossUI] 錯誤：無法隱藏UI，boss_health_bar不存在")

func _process(_delta: float) -> void:
	# 檢查是否有新的 boss 節點
	if get_tree():
		var boss = get_tree().get_first_node_in_group("boss")
		
		if boss:
			# 如果找到了Boss但boss_health_bar為null，這是一個錯誤
			if not boss_health_bar:
				# 不再嘗試創建節點，而是診斷問題
				if Engine.get_frames_drawn() % 60 == 0:  # 每60幀診斷一次，避免日誌過多
					print("[BossUI] 警告：找到Boss但boss_health_bar為null，進行診斷")
					_diagnose_scene_path()
			
			# 確保信號正確連接
			elif boss.has_signal("health_changed") and not boss.health_changed.is_connected(_on_boss_health_changed):
				print("[BossUI] 重新連接health_changed信號")
				_connect_boss_signals(boss)

# 提供給外部調用的公共方法
func show_boss_health(boss: Node) -> void:
	if boss_health_bar:
		if boss.has_method("get_max_health") and boss.has_method("get_current_health"):
			boss_health_bar.max_value = boss.get_max_health()
			boss_health_bar.value = boss.get_current_health()
		elif "max_health" in boss and "current_health" in boss:
			boss_health_bar.max_value = boss.max_health
			boss_health_bar.value = boss.current_health
		else:
			# 最後的兼容方案
			boss_health_bar.max_value = boss.max_health if "max_health" in boss else 1000
			boss_health_bar.value = boss.health if "health" in boss else 1000
		
		boss_health_bar.show()
		
		# 顯示所有裝飾
		for decor in boss_hp_decors:
			if decor:
				decor.show()

func hide_boss_health() -> void:
	if boss_health_bar:
		boss_health_bar.hide()
		
		# 隱藏所有裝飾
		for decor in boss_hp_decors:
			if decor:
				decor.hide() 
