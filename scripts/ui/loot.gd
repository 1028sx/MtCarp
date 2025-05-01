extends Area2D

signal collected

@onready var sprite = $AnimatedSprite2D
@onready var interaction_prompt = $InteractionPrompt

var can_interact := false
var is_collected := false
var selection_ui: CanvasLayer
var is_being_selected := false
var fade_out_timer := 0.0
var fade_tween: Tween

var available_effects := [
	{
		"name": "汲取",
		"description": "最大生命值減少，但每次攻擊恢復生命值",
		"icon": preload("res://assets/icons/life_steal.png"),
		"effect": "life_steal"
	},
	{
		"name": "連擊",
		"description": "特殊攻擊的攻擊次數增加，每次傷害遞增",
		"icon": preload("res://assets/icons/multi_strike.png"),
		"effect": "multi_strike"
	},
	{
		"name": "嗜血",
		"description": "生命值越低，移動和攻擊速度越快",
		"icon": preload("res://assets/icons/berserker.png"),
		"effect": "berserker"
	},
	{
		"name": "波動",
		"description": "衝刺攻擊時產生傷害波動，能大幅擊退敵人",
		"icon": preload("res://assets/icons/dash_wave.png"),
		"effect": "dash_wave"
	},
	{
		"name": "爆震",
		"description": "跳躍時產生傷害衝擊波，並且連續跳躍次數增加",
		"icon": preload("res://assets/icons/jump_impact.png"),
		"effect": "jump_impact"
	},
	{
		"name": "疾風",
		"description": "衝刺冷卻時間大幅減少，同時衝刺距離增加",
		"icon": preload("res://assets/icons/swift_dash.png"),
		"effect": "swift_dash"
	},
	# {
	# 	"name": "冰結",
	# 	"description": "每五秒能使用一次冰結攻擊，對敵人造成冰凍效果",
	# 	"icon": null,
	# 	"effect": "ice_freeze"
	# },
	{
		"name": "憤怒",
		"description": "每次受傷增加攻擊力，但一段時間沒被攻擊會減少",
		"icon": preload("res://assets/icons/rage.png"),
		"effect": "rage"
	},
	{
		"name": "靈巧",
		"description": "完美迴避時下次攻擊傷害翻倍",
		"icon": preload("res://assets/icons/agile.png"),
		"effect": "agile"
	},
	{
		"name": "專注",
		"description": "連續命中同一敵人時提升傷害",
		"icon": preload("res://assets/icons/focus.png"),
		"effect": "focus"
	},
	{
		"name": "收割",
		"description": "以特殊攻擊擊殺敵人回復最大生命值",
		"icon": preload("res://assets/icons/harvest.png"),
		"effect": "harvest"
	},
	{
		"name": "荊棘",
		"description": "攻擊力降低但最大生命值增加，受傷時能反彈傷害",
		"icon": preload("res://assets/icons/thorns.png"),
		"effect": "thorns"
	},
	{
		"name": "敏捷",
		"description": "衝刺後的三次攻擊速度提升，並具有衝刺攻擊的傷害加成",
		"icon": preload("res://assets/icons/agile_dash.png"),
		"effect": "agile_dash"
	}
]

func _ready() -> void:
	add_to_group("loot")
	collision_layer = 0
	collision_mask = 2
	
	if sprite:
		sprite.play("default")  # 播放預設動畫
	
	if interaction_prompt:
		interaction_prompt.text = "按下S以收集"
		interaction_prompt.modulate.a = 0
		interaction_prompt.show()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_ensure_selection_ui()

func _process(delta: float) -> void:
	if fade_out_timer > 0:
		fade_out_timer -= delta
		if fade_out_timer <= 0:
			_fade_out()

func _fade_in() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(interaction_prompt, "modulate:a", 1.0, 0.3)

func _fade_out() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN)
	fade_tween.tween_property(interaction_prompt, "modulate:a", 0.0, 0.3)

func _ensure_selection_ui() -> void:
	selection_ui = get_tree().get_first_node_in_group("loot_selection_ui")
	
	if not selection_ui:
		var main_scene = get_tree().get_first_node_in_group("main")
		if not main_scene:
			await get_tree().process_frame
			main_scene = get_tree().get_first_node_in_group("main")
			
		if main_scene:
			var loot_selection_scene = load("res://scenes/ui/loot_selection_ui.tscn")
			if loot_selection_scene:
				
				selection_ui = loot_selection_scene.instantiate()
				main_scene.add_child(selection_ui)
				selection_ui.hide()
			else:
				return
		else:
			var current_scene = get_tree().current_scene
			if current_scene:
				var loot_selection_scene = load("res://scenes/ui/loot_selection_ui.tscn")
				if loot_selection_scene:
					selection_ui = loot_selection_scene.instantiate()
					current_scene.add_child(selection_ui)
					selection_ui.hide()
				else:
					return
			else:
				return
	
	if selection_ui:
		selection_ui.hide()
		if selection_ui.has_method("reset"):
			selection_ui.reset()
		if selection_ui.has_signal("effect_selected"):
			var connections = selection_ui.get_signal_connection_list("effect_selected")
			for connection in connections:
				if connection.callable.get_object() == self:
					selection_ui.effect_selected.disconnect(connection.callable)

func _input(event: InputEvent) -> void:
	if can_interact and not is_collected and not is_being_selected:
		if event.is_action_pressed("interact"):
			_ensure_selection_ui()
			
			if selection_ui and is_instance_valid(selection_ui):
				is_being_selected = true
				
				if selection_ui.has_signal("effect_selected"):
					var connections = selection_ui.get_signal_connection_list("effect_selected")
					for connection in connections:
						if connection.callable.get_object() == self:
							selection_ui.effect_selected.disconnect(connection.callable)
				
				selection_ui.effect_selected.connect(_on_effect_selected)
				selection_ui.show_effects(available_effects)
				if fade_tween and fade_tween.is_valid():
					fade_tween.kill()
				interaction_prompt.modulate.a = 0

func _on_effect_selected(effect: Dictionary) -> void:
	if not is_being_selected or not is_instance_valid(selection_ui):
		queue_free()
		return
		
	is_being_selected = false
	_process_effect(effect.get("effect", "unknown"))
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.emit_signal("effect_changed", player.active_effects)

func _process_effect(effect: String) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.process_loot_effect(effect)
	
	if selection_ui and selection_ui.has_signal("effect_selected"):
		var connections = selection_ui.get_signal_connection_list("effect_selected")
		for connection in connections:
			if connection.callable.get_object() == self:
				selection_ui.effect_selected.disconnect(connection.callable)
		
		selection_ui.hide_menu()
	
	# 發送收集信號
	collected.emit()
	
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0, 0.2)
	fade_tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_collected:
		can_interact = true
		_fade_in()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		can_interact = false
		if interaction_prompt:
			interaction_prompt.modulate.a = 0.0

func collect() -> void:
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _exit_tree() -> void:
	if selection_ui and selection_ui.has_signal("effect_selected"):
		var connections = selection_ui.get_signal_connection_list("effect_selected")
		for connection in connections:
			if connection.callable.get_object() == self:
				selection_ui.effect_selected.disconnect(connection.callable)
