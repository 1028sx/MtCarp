extends Control

@onready var label = $Label

var fade_tween: Tween
var last_hit_time := 0.0
const SHOW_DELAY := 5.0  # 5秒後顯示
var is_showing := false

func _ready() -> void:
	if label:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.modulate.a = 0.0
		label.show()
	
	# 監聽房間切換
	var room_manager = get_tree().get_first_node_in_group("room_manager")
	if room_manager and room_manager.has_signal("room_changed"):
		room_manager.room_changed.connect(_on_room_changed)

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	# 如果沒有敵人，隱藏指示器
	if enemies.is_empty():
		if is_showing:
			_hide_indicator()
		return
	
	# 如果還沒超過5秒，保持隱藏
	var current_time = Time.get_unix_time_from_system()
	var time_diff = current_time - last_hit_time
	
	if time_diff < SHOW_DELAY:
		if is_showing:
			_hide_indicator()
		return
	
	# 超過5秒且有敵人，顯示指示器
	if player:
		var nearest_enemy = enemies[0]
		var nearest_distance = player.global_position.distance_to(enemies[0].global_position)
		
		for enemy in enemies:
			var distance = player.global_position.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
		
		var direction = nearest_enemy.global_position - player.global_position
		var angle = rad_to_deg(direction.angle())
		
		# 八方位判斷
		var direction_text = ""
		if angle > -22.5 and angle <= 22.5:
			direction_text = "→"
		elif angle > 22.5 and angle <= 67.5:
			direction_text = "↘"
		elif angle > 67.5 and angle <= 112.5:
			direction_text = "↓"
		elif angle > 112.5 and angle <= 157.5:
			direction_text = "↙"
		elif angle > 157.5 or angle <= -157.5:
			direction_text = "←"
		elif angle > -157.5 and angle <= -112.5:
			direction_text = "↖"
		elif angle > -112.5 and angle <= -67.5:
			direction_text = "↑"
		else:
			direction_text = "↗"
		
		direction_text += " 敵人"
		
		# 如果已經顯示，只在方向改變時更新文字
		if is_showing:
			if label.text != direction_text:
				label.text = direction_text
		else:
			_show_indicator(direction_text)

func _show_indicator(text: String) -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	is_showing = true
	label.text = text
	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(label, "modulate:a", 1.0, 0.07)

func _hide_indicator(_reason: String = "") -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	is_showing = false
	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.07)

func on_enemy_hit() -> void:
	var current_time = Time.get_unix_time_from_system()
	last_hit_time = current_time
	if is_showing:
		_hide_indicator()

func _on_room_changed(_old_room: Node, _new_room: Node) -> void:
	last_hit_time = Time.get_unix_time_from_system()
	if is_showing:
		_hide_indicator()
