extends Node2D

# 預加載道具場景
@export var item_scenes = {
	"word": preload("res://scenes/items/Word.tscn"),
	"loot": preload("res://scenes/ui/loot.tscn"),
	# 暫時註釋掉尚未實現的道具
	# "health_potion": preload("res://scenes/items/HealthPotion.tscn"),
	# "speed_boost": preload("res://scenes/items/SpeedBoost.tscn"),
	# "damage_up": preload("res://scenes/items/DamageUp.tscn")
}

# 信號
# 暫時註釋掉未使用的信號
# signal item_collected(item_type: String)

# 當前房間的道具列表
var current_items = []

func _ready():
	# 初始化時可能需要進行的設置
	pass

func spawn_items_for_room(room: Node2D, difficulty: int):
	# 清除當前房間的道具
	clear_current_items()
	
	# 獲取房間中的道具生成點
	var spawn_points = room.get_node("ItemSpawnPoints").get_children()
	
	# 根據難度決定要生成的道具數量和類型
	var num_items = calculate_num_items(difficulty)
	
	# 生成道具
	for i in range(min(num_items, spawn_points.size())):
		if item_scenes.is_empty():
			print("警告：沒有可用的道具場景")
			return
		var item_type = choose_item_type(difficulty)
		var item = item_scenes[item_type].instantiate()
		item.global_position = spawn_points[i].global_position
		room.add_child(item)
		current_items.append(item)
		
		# 連接道具的信號
		if item.has_signal("collected"):
			item.connect("collected", Callable(self, "_on_item_collected"))

func calculate_num_items(difficulty: int) -> int:
	# 修改計算邏輯以避免整數除法警告
	return max(1, int(difficulty / 2.0))  # 使用浮點數除法

func choose_item_type(_difficulty: int) -> String:
	# 添加下劃線以表示未使用的參數
	if item_scenes.is_empty():
		return ""
	var available_items = item_scenes.keys()
	return available_items[randi() % available_items.size()]

func clear_current_items():
	for item in current_items:
		if is_instance_valid(item):
			item.queue_free()
	current_items.clear()

func _on_item_collected(item):
	if item.is_in_group("word"):
		var word_system = get_node("/root/WordSystem")
		if word_system:
			word_system.collected_words.append(item.character)
			word_system.check_idioms()  # 檢查是否可以組成成語
	
	current_items.erase(item)

func apply_item_effect(item_type: String, player: CharacterBody2D):
	match item_type:
		"health_potion":
			player.heal(20)  # 假設恢復20點生命值
		"speed_boost":
			player.apply_speed_boost(1.5, 10.0)  # 假設增加50%速度，持續10秒
		"damage_up":
			player.increase_damage(5)  # 假設增加5點傷害

func _process(_delta):
	# 移除無效的道具引用
	current_items = current_items.filter(func(item): return is_instance_valid(item))

func get_nearest_item(item_position: Vector2) -> Node2D:
	var nearest_item = null
	var nearest_distance = INF
	
	for item in current_items:
		if is_instance_valid(item):
			var distance = item_position.distance_to(item.global_position)
			if distance < nearest_distance:
				nearest_item = item
				nearest_distance = distance
	
	return nearest_item

func get_items_in_range(item_position: Vector2, search_range: float) -> Array:
	var items_in_range = []
	
	for item in current_items:
		if is_instance_valid(item):
			if item_position.distance_to(item.global_position) <= search_range:
				items_in_range.append(item)
	
	return items_in_range

func spawn_word_drop(enemy: Node2D) -> void:
	var word_system = get_node("/root/WordSystem")
	if not word_system:
		return
		
	var enemy_type = enemy.name
	if word_system.ENEMY_WORDS.has(enemy_type):
		var possible_words = word_system.ENEMY_WORDS[enemy_type]
		var word = possible_words[randi() % possible_words.size()]
		
		if item_scenes.has("word"):
			var word_instance = item_scenes["word"].instantiate()
			word_instance.setup({
				"character": word
			})
			word_instance.global_position = enemy.global_position
			enemy.get_parent().add_child(word_instance)
			current_items.append(word_instance)

func spawn_loot_at_position(pos: Vector2) -> void:
	# 檢查是否應該生成戰利品
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and not game_manager.should_spawn_loot():
		return
		
	# 生成戰利品
	if item_scenes.has("loot"):
		var loot = item_scenes["loot"].instantiate()
		loot.global_position = pos
		get_tree().current_scene.add_child(loot)
		current_items.append(loot)
