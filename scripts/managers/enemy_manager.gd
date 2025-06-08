extends Node2D

@export var enemy_scenes = {
	"archer": preload("res://scenes/enemies/archer.tscn"),
	"boar": preload("res://scenes/enemies/boar.tscn"),  # Boss
	"bird": preload("res://scenes/enemies/small_bird.tscn"),
	"deer": preload("res://scenes/enemies/deer.tscn"),  # Boss
	"chicken": preload("res://scenes/enemies/chicken.tscn")
}

signal all_enemies_defeated
signal special_event_triggered(event_name: String)
signal elite_enemy_spawned(enemy_type: String)  # 用於通知文字系統

var current_enemies = []
var has_emitted_defeat = false
var explored_rooms = []  # 已探索的房間列表
var room_enemy_states = {}  # 保存每個房間的敵人狀態
var enemy_container: Node2D  # 用於存放敵人的容器節點
var current_room: String = ""  # 當前房間名稱

# 房間敵人基礎配置（首次進入時）
const INITIAL_ROOM_ENEMIES = {
	"room1": {  # 雞群房
		"1": "chicken",
		"2": "chicken",
		"3": "chicken"
	},
	"room2": {  # 弓箭手房
		"1": "archer",
		"2": "archer",
		"3": "archer"
	},
	"room3": {  # 混合房
		"1": "archer",
		"2": "chicken",
		"3": "archer"
	},
	"room4": {  # 山豬Boss房
		"1": "archer",
		"2": "boar",  # Boss
		"3": "chicken"
	},
	"room6": {  # 鹿Boss房
		"1": "archer",
		"2": "deer",  # Boss
		"3": "chicken"
	}
}

# 房間敵人重生配置（重返已探索房間時）
const REVISIT_ROOM_ENEMIES = {
	"room1": {  # 雞群房變成鳥群
		"1": "bird",
		"2": "chicken",
		"3": "bird"
	},
	"room2": {  # 弓箭手房保持弓箭手為主
		"1": "archer",
		"2": "bird",
		"3": "archer"
	},
	"room3": {  # 混合房增加鳥
		"1": "bird",
		"2": "archer",
		"3": "bird"
	},
	"room4": {  # Boss房不變
		"1": "archer",
		"2": "boar",
		"3": "chicken"
	},
	"room6": {  # Boss房不變
		"1": "archer",
		"2": "deer",
		"3": "chicken"
	}
}

const SPECIAL_EVENTS = {
	"ambush": {
		"chance": 0.2,  # 20%機率觸發
		"min_explored_rooms": 2  # 至少探索2個房間後才會觸發
	},
	"elite_spawn": {
		"chance": 0.15,  # 15%機率觸發
		"min_explored_rooms": 3
	}
}

# 定期生成敵人的相關變量
var spawn_timer: Timer
var base_spawn_interval: float = 5.0  # 基礎生成間隔（秒）
var min_spawn_interval: float = 15.0  # 最小生成間隔（秒）
var spawn_interval_increment: float = 2.0  # 每次生成後增加的間隔（秒）
var current_spawn_interval: float = base_spawn_interval
var max_enemies: int = 6  # 最大敵人數量
var auto_spawn_enabled: bool = false  # 是否啟用自動生成

func _ready():
	# 檢查是否已經存在實例
	var existing_managers = get_tree().get_nodes_in_group("enemy_manager")
	if existing_managers.size() > 1:
		for manager in existing_managers:
			if manager != self:
				manager.queue_free()
	
	if not is_in_group("enemy_manager"):
		add_to_group("enemy_manager", true)  # 持久化組成員資格
		
	# 創建敵人容器節點
	enemy_container = Node2D.new()
	enemy_container.name = "EnemyContainer"
	add_child(enemy_container)
	
	# 初始化生成計時器
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# 確保不會在場景切換時被暫停
	# process_mode = Node.PROCESS_MODE_ALWAYS # MODIFIED: Commented out
	process_mode = Node.PROCESS_MODE_INHERIT # MODIFIED: Explicitly set to INHERIT (default behavior)
	
	# 連接自己的信號
	all_enemies_defeated.connect(_on_all_enemies_defeated)
	has_emitted_defeat = false

func start_auto_spawn() -> void:
	if not auto_spawn_enabled:
		auto_spawn_enabled = true
		current_spawn_interval = base_spawn_interval
		spawn_timer.start(current_spawn_interval)

func stop_auto_spawn() -> void:
	if auto_spawn_enabled:
		auto_spawn_enabled = false
		spawn_timer.stop()

func _on_spawn_timer_timeout() -> void:
	if not auto_spawn_enabled:
		return
		
	if current_enemies.size() >= max_enemies:
		spawn_timer.start(current_spawn_interval)
		return
		
	var spawn_points_node = _find_spawn_points(get_tree().current_scene)
	if not spawn_points_node:
		return
		
	var spawn_points = spawn_points_node.get_children()
	if spawn_points.is_empty():
		return
		
	var spawn_point = spawn_points.pick_random()
	var enemy_type = _get_random_enemy_type_for_room(current_room)
	_spawn_enemy(spawn_point, enemy_type)
	
	current_spawn_interval = min(current_spawn_interval + spawn_interval_increment, min_spawn_interval)
	spawn_timer.start(current_spawn_interval)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear_current_enemies()
	elif what == NOTIFICATION_PARENTED:
		pass
	elif what == NOTIFICATION_UNPARENTED:
		pass

func reset_state() -> void:
	if not current_room.is_empty() and not current_enemies.is_empty():
		save_room_state(current_room)
	
	clear_current_enemies()
	has_emitted_defeat = false

func spawn_enemies_for_room(room_name: String) -> void:
	stop_auto_spawn()
	current_room = room_name
	
	if room_name == "room5":
		emit_signal("all_enemies_defeated")
		return
	
	reset_state()
	
	if room_name == "room1" and not room_enemy_states.has(room_name):
		await get_tree().create_timer(0.1).timeout
		var loot = get_tree().get_first_node_in_group("loot")
		if loot:
			if not loot.is_connected("collected", _on_loot_collected):
				loot.collected.connect(_on_loot_collected.bind(room_name))
		else:
			_spawn_new_room_enemies_by_name(room_name)
		return
	
	if room_enemy_states.has(room_name):
		_restore_room_enemies_by_name(room_name)
	else:
		_spawn_new_room_enemies_by_name(room_name)
		start_auto_spawn()

func _on_loot_collected(room_name: String) -> void:
	_spawn_new_room_enemies_by_name(room_name)
	start_auto_spawn()

func _spawn_enemy(spawn_point: Node2D, enemy_type: String = "") -> void:
	if not spawn_point:
		push_error("[EnemyManager] 錯誤：生成點為空")
		return
		
	var spawn_position = spawn_point.global_position
	var enemy_scene: PackedScene
	
	# 檢查殺雞取卵效果
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.all_drops_once_enabled and game_manager.all_drops_once_used:
		print("[EnemyManager] 殺雞取卵效果已使用，不生成新敵人")
		return
	
	if enemy_type.is_empty():
		enemy_scene = _get_random_enemy_scene()
	else:
		enemy_scene = _get_enemy_scene(enemy_type)
	
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		if enemy:
			enemy_container.add_child(enemy)
			enemy.global_position = spawn_position
			
			if not enemy.defeated.is_connected(_on_enemy_defeated):
				enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
			current_enemies.append(enemy)
		else:
			push_error("[EnemyManager] 錯誤：敵人實例化失敗")
	else:
		push_error("[EnemyManager] 錯誤：無法加載敵人場景")

func clear_current_enemies() -> void:
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	current_enemies.clear()

func _on_enemy_defeated(enemy) -> void:
	if not is_instance_valid(enemy):
		return
		
	if enemy in current_enemies:
		current_enemies.erase(enemy)
		
		# 檢查是否所有敵人都被擊敗
		var active_enemies = []
		for e in current_enemies:
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				if not e.has_method("is_dying") or not e.is_dying:
					active_enemies.append(e)
		
		if active_enemies.is_empty():
			stop_auto_spawn()  # 停止自動生成
			# 清除當前房間的敵人狀態
			if room_enemy_states.has(current_room):
				room_enemy_states.erase(current_room)
			
			# 生成戰利品
			var spawn_position = enemy.global_position
			var item_manager = get_tree().get_first_node_in_group("item_manager")
			var game_manager = get_tree().get_first_node_in_group("game_manager")
			
			# 檢查殺雞取卵效果
			if game_manager and game_manager.all_drops_once_enabled and not game_manager.all_drops_once_used:
				# 對所有存活的敵人執行掉落
				for remaining_enemy in current_enemies:
					if is_instance_valid(remaining_enemy) and not remaining_enemy.is_queued_for_deletion():
						if item_manager and item_manager.has_method("spawn_loot_at_position"):
							item_manager.spawn_loot_at_position(remaining_enemy.global_position)
				# 標記殺雞取卵效果已使用
				game_manager.all_drops_once_used = true
				print("[EnemyManager] 殺雞取卵效果觸發，所有敵人掉落戰利品")
			else:
				# 正常掉落邏輯
				if item_manager and item_manager.has_method("spawn_loot_at_position"):
					item_manager.spawn_loot_at_position(spawn_position)
			
			# --- 加入 Print 語句 --- 
			print("EnemyManager emitting all_enemies_defeated for room: ", current_room) 
			# --- 結束 Print 語句 ---
			# 發送清場信號
			emit_signal("all_enemies_defeated")

func _find_spawn_points(node: Node) -> Node:
	# 遞迴搜索 EnemySpawnPoints 節點
	if node.name == "EnemySpawnPoints":
		return node
		
	for child in node.get_children():
		var result = _find_spawn_points(child)
		if result:
			return result
			
	return null

func _spawn_new_room_enemies_by_name(room_name: String) -> void:
	var spawn_points = _find_spawn_points(get_tree().current_scene)
	if not spawn_points:
		return
	
	var _spawn_point_count = spawn_points.get_child_count()
	
	# 檢查是否為重訪
	var is_revisit = room_enemy_states.has(room_name)
	
	# 根據是否重訪選擇配置
	var config = REVISIT_ROOM_ENEMIES if is_revisit else INITIAL_ROOM_ENEMIES
	
	if not config.has(room_name):
		return
	
	var _room_config = config[room_name]
	
	# 遍歷所有生成點
	for spawn_point in spawn_points.get_children():
		var spawn_number = _get_spawn_number(spawn_point.name)
		if spawn_number.is_empty():
			continue
			
		# 獲取該生成點應該生成的敵人類型
		var enemy_type = _get_enemy_type_for_room(room_name, spawn_number, is_revisit)
		if enemy_type.is_empty():
			continue
			
		_spawn_enemy(spawn_point, enemy_type)
	
	# 如果不是重訪且是特定房間，生成伏擊敵人
	if not is_revisit and _should_spawn_ambush(room_name):
		_spawn_ambush()

func _get_enemy_type_for_room(room_name: String, spawn_number: String, is_revisit: bool) -> String:
	var config = REVISIT_ROOM_ENEMIES if is_revisit else INITIAL_ROOM_ENEMIES
	if not config.has(room_name):
		return ""
		
	var _room_config = config[room_name]
	if not _room_config.has(spawn_number):
		return ""
		
	return _room_config[spawn_number]

func _get_spawn_number(spawn_name: String) -> String:
	# 假設生成點名稱格式為 "Spawn1", "Spawn2" 等
	var regex = RegEx.new()
	regex.compile("Spawn(\\d+)")
	var result = regex.search(spawn_name)
	if result:
		return result.get_string(1)
	return ""

func _should_spawn_ambush(room_name: String) -> bool:
	# 在這裡定義需要生成伏擊敵人的房間
	var ambush_rooms = ["room3", "room4"]
	return ambush_rooms.has(room_name)

func _spawn_ambush() -> void:
	# 在這裡實現伏擊敵人的生成邏輯
	pass

func _get_enemy_scene(enemy_type: String) -> PackedScene:
	if enemy_scenes.has(enemy_type):
		return enemy_scenes[enemy_type]
	return enemy_scenes["archer"]  # 預設返回弓箭手

func _get_random_enemy_scene() -> PackedScene:
	var types = enemy_scenes.keys()
	var random_type = types.pick_random()
	return enemy_scenes[random_type]

func _check_special_events(_room_name: String) -> void:
	for event_name in SPECIAL_EVENTS:
		var event = SPECIAL_EVENTS[event_name]
		if explored_rooms.size() >= event.min_explored_rooms:
			if randf() <= event.chance:
				_trigger_special_event(event_name)

func _trigger_special_event(event_name: String) -> void:
	match event_name:
		"ambush":
			_spawn_ambush()
		"elite_spawn":
			_spawn_elite()
	special_event_triggered.emit(event_name)

func _spawn_elite() -> void:
	var normal_enemies = current_enemies.filter(func(e): 
		return is_instance_valid(e) and not e.name.contains("Boss")
	)
	if normal_enemies.is_empty():
		return
		
	var chosen_enemy = normal_enemies.pick_random()
	chosen_enemy.health *= 2
	chosen_enemy.damage *= 1.5
	chosen_enemy.modulate = Color(1.2, 1.2, 0.8)
	chosen_enemy.set_meta("is_elite", true)
	
	elite_enemy_spawned.emit(chosen_enemy.name)

func save_room_state(room_name: String) -> void:
	if current_enemies.is_empty():
		room_enemy_states.erase(room_name)
		return
	
	var enemy_states = []
	for enemy in current_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if not enemy.has_method("is_dying") or not enemy.is_dying:
				var state = {
					"type": enemy.enemy_type if enemy.has_method("get_enemy_type") else "unknown",
					"position": enemy.global_position,
					"health": enemy.health if enemy.has_method("get_health") else 100
				}
				enemy_states.append(state)
	
	if enemy_states.is_empty():
		room_enemy_states.erase(room_name)
	else:
		room_enemy_states[room_name] = enemy_states

func _restore_room_enemies_by_name(room_name: String) -> void:
	if not room_enemy_states.has(room_name):
		return
	
	var enemy_states = room_enemy_states[room_name]
	
	for state in enemy_states:
		var enemy_scene = load("res://scenes/enemies/%s.tscn" % state.type)
		if enemy_scene:
			var enemy = enemy_scene.instantiate()
			enemy.global_position = state.position
			if enemy.has_method("set_health"):
				enemy.set_health(state.health)
			add_child(enemy)
			current_enemies.append(enemy)

func _get_random_enemy_type_for_room(room_name: String) -> String:
	# 根據房間選擇適合的敵人類型
	match room_name:
		"room1":  # 雞群房
			return ["chicken", "bird"].pick_random()
		"room2":  # 弓箭手房
			return ["archer", "bird"].pick_random()
		"room3":  # 混合房
			return ["archer", "chicken", "bird"].pick_random()
		"room4":  # 山豬Boss房
			return ["archer", "chicken"].pick_random()  # Boss房不自動生成Boss
		"room6":  # 鹿Boss房
			return ["archer", "chicken"].pick_random()  # Boss房不自動生成Boss
		_:
			return ["chicken", "archer", "bird"].pick_random()  # 預設隨機

func _on_all_enemies_defeated() -> void:
	pass
