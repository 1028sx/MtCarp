extends CanvasLayer

var boss_health_bar = null
var boss_hp_decors = []
var boss_name_label = null
var boss_name_cache = "Boss"

func _ready():
	add_to_group("boss_ui")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_check_parent_node()
	
	var control_hud = get_node_or_null("Control_BossHUD")
	if control_hud:
		boss_health_bar = control_hud.get_node_or_null("TextureProgressBar_BossHP")
		if boss_health_bar:
			boss_hp_decors = [
				control_hud.get_node_or_null("TextureRect_Deer1"),
				control_hud.get_node_or_null("TextureRect_Deer2"),
				control_hud.get_node_or_null("TextureRect_Deer3"),
				control_hud.get_node_or_null("TextureRect_Deer4"),
				control_hud.get_node_or_null("TextureRect_Deer5")
			]
			
			for i in range(boss_hp_decors.size()):
				if not boss_hp_decors[i]:
					pass
					
	_initialize_ui()
	
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	
	call_deferred("_check_existing_boss")

func _check_parent_node():
	var parent = get_parent()
	if not parent:
		return false
	
	if parent.name == "Main":
		return true
	elif parent.name == "root":
		return false
	else:
		return false

func _debug_print_scene_tree(node, indent_level):
	var _indent = ""
	for i in range(indent_level):
		_indent += "  "
	
	for child in node.get_children():
		_debug_print_scene_tree(child, indent_level + 1)

func _initialize_ui():
	if boss_health_bar:
		boss_health_bar.hide()
		
		for i in range(boss_hp_decors.size()):
			var decor = boss_hp_decors[i]
			if decor:
				decor.hide()

func _diagnose_scene_path():
	var scenes = {}
	_collect_scenes(get_tree().root, scenes)
	for path in scenes:
		pass

func _collect_scenes(node, scenes):
	if node.has_method("get_filename") and node.get_filename() != "":
		scenes[node.get_path()] = node.get_filename()
	
	for child in node.get_children():
		_collect_scenes(child, scenes)

func _check_existing_boss():
	var boss = get_tree().get_first_node_in_group("boss")
	if boss:
		_connect_boss_signals(boss)

func _exit_tree():
	if get_tree():
		if get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)
			
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
		call_deferred("_connect_boss_signals", node)

func _connect_boss_signals(boss: Node) -> void:
	if boss.has_signal("health_changed") and boss.health_changed.is_connected(_on_boss_health_changed):
		boss.health_changed.disconnect(_on_boss_health_changed)
	if boss.has_signal("phase_changed") and boss.phase_changed.is_connected(_on_boss_phase_changed):
		boss.phase_changed.disconnect(_on_boss_phase_changed)
	if boss.has_signal("boss_defeated") and boss.boss_defeated.is_connected(_on_boss_defeated):
		boss.boss_defeated.disconnect(_on_boss_defeated)
	if boss.has_signal("defeated") and boss.defeated.is_connected(_on_boss_defeated):
		boss.defeated.disconnect(_on_boss_defeated)
	
	if boss.has_signal("health_changed"):
		boss.health_changed.connect(_on_boss_health_changed)
		
	if boss.has_signal("phase_changed"):
		boss.phase_changed.connect(_on_boss_phase_changed)

	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	elif boss.has_signal("defeated"):
		boss.defeated.connect(_on_boss_defeated)
	
	if boss_health_bar:
		if boss.has_method("get_name") and boss.get_name() != "":
			boss_name_cache = boss.get_name()
		elif "boss_name" in boss and boss.boss_name != "":
			boss_name_cache = boss.boss_name
		elif "name" in boss and boss.name != "":
			boss_name_cache = boss.name

		if boss.has_method("get_max_health") and boss.has_method("get_current_health"):
			boss_health_bar.max_value = boss.get_max_health()
			boss_health_bar.value = boss.get_current_health()
		elif "max_health" in boss and "current_health" in boss:
			boss_health_bar.max_value = boss.max_health
			boss_health_bar.value = boss.current_health
		else:
			boss_health_bar.max_value = boss.max_health if "max_health" in boss else 1000
			boss_health_bar.value = boss.health if "health" in boss else boss.max_health if "max_health" in boss else 1000
		
		boss_health_bar.show()
		for decor in boss_hp_decors:
			if decor:
				decor.show()
		if boss_name_label:
			boss_name_label.text = "%s: %d/%d" % [boss_name_cache, boss_health_bar.value, boss_health_bar.max_value]

func _on_boss_phase_changed(_phase: int) -> void:
	if boss_health_bar:
		boss_health_bar.show()
		for decor in boss_hp_decors:
			if decor:
				decor.show()

func _on_boss_health_changed(current: float, max_health: float) -> void:
	if boss_health_bar:
		if not boss_health_bar.visible:
			boss_health_bar.show()
			for decor in boss_hp_decors:
				if decor:
					decor.show()
		
		boss_health_bar.max_value = max_health
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(boss_health_bar, "value", current, 0.25)

		if boss_name_label:
			boss_name_label.text = "%s: %d/%d" % [boss_name_cache, current, max_health]

func _on_boss_defeated() -> void:
	if boss_health_bar:
		boss_health_bar.hide()
		for decor in boss_hp_decors:
			if decor:
				decor.hide()

func _process(_delta: float) -> void:
	if get_tree():
		var boss = get_tree().get_first_node_in_group("boss")
		
		if boss:
			if not boss_health_bar:
				if Engine.get_frames_drawn() % 60 == 0:
					_diagnose_scene_path()
			
			elif boss.has_signal("health_changed") and not boss.health_changed.is_connected(_on_boss_health_changed):
				_connect_boss_signals(boss)

func show_boss_health(boss: Node) -> void:
	if boss_health_bar:
		if boss.has_method("get_max_health") and boss.has_method("get_current_health"):
			boss_health_bar.max_value = boss.get_max_health()
			boss_health_bar.value = boss.get_current_health()
		elif "max_health" in boss and "current_health" in boss:
			boss_health_bar.max_value = boss.max_health
			boss_health_bar.value = boss.current_health
		else:
			boss_health_bar.max_value = boss.max_health if "max_health" in boss else 1000
			boss_health_bar.value = boss.health if "health" in boss else 1000
		
		boss_health_bar.show()
		
		for decor in boss_hp_decors:
			if decor:
				decor.show()

func hide_boss_health() -> void:
	if boss_health_bar:
		boss_health_bar.hide()
		
		for decor in boss_hp_decors:
			if decor:
				decor.hide() 
