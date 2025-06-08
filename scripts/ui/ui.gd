extends CanvasLayer

@onready var hud = $Control_HUD
@onready var health_bar = $Control_HUD/TextureProgressBar_HP
@onready var mana_bar = $Control_HUD/TextureProgressBar_MP
@onready var revive_heart = $Control_HUD/TextureRect_Heart

const PauseMenu = preload("res://scenes/ui/pause_menu.tscn")
var pause_menu
var is_initialized := false

func _ready():
	add_to_group("ui")
	_initialize_bars()
	
	pause_menu = PauseMenu.instantiate()
	add_child(pause_menu)
	if pause_menu:
		pause_menu.back_to_menu.connect(_on_back_to_menu)
	
	await get_tree().process_frame
	_setup_signals()

func _initialize_bars():
	if health_bar:
		health_bar.min_value = 0
		health_bar.max_value = 100
		health_bar.value = 100
		health_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	
	if mana_bar:
		mana_bar.min_value = 0
		mana_bar.max_value = 100
		mana_bar.value = 100
		mana_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT

func _setup_signals() -> void:
	if not is_initialized and is_inside_tree():
		is_initialized = true
		
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if not player.gold_changed.is_connected(update_gold):
				player.gold_changed.connect(update_gold)
			update_gold(player.gold)

func _connect_player():
	if not is_inside_tree():
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.disconnect(_on_player_health_changed)
		if player.gold_changed.is_connected(update_gold):
			player.gold_changed.disconnect(update_gold)
		
		player.health_changed.connect(_on_player_health_changed)
		player.gold_changed.connect(update_gold)
		
		_update_health_bar(player)
		update_gold(player.gold)

func _update_health_bar(player: Node) -> void:
	if health_bar and player:
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health

func _exit_tree():
	if get_tree():
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if player.health_changed.is_connected(_on_player_health_changed):
				player.health_changed.disconnect(_on_player_health_changed)
			if player.gold_changed.is_connected(update_gold):
				player.gold_changed.disconnect(update_gold)

func _on_player_health_changed(new_health: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and health_bar:
		health_bar.max_value = player.max_health
		update_health(new_health)

func update_health(health: int):
	if health_bar:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(health_bar, "value", health, 0.3)

func update_gold(gold: int):
	if not hud:
		return
		
	var gold_label = hud.get_node_or_null("Label_Gold")
	if gold_label:
		gold_label.text = "Gold: " + str(gold)

func update_mana(mana: int):
	if mana_bar:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(mana_bar, "value", mana, 0.3)

func use_revive_heart():
	if revive_heart and is_instance_valid(revive_heart):
		revive_heart.visible = false
		
		var tween = create_tween()
		tween.tween_property(revive_heart, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): pass)
	
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		var canvas_layers = []
		for child in main_node.get_children():
			if child is CanvasLayer:
				canvas_layers.append(child)
		
		for canvas in canvas_layers:
			var hud_node = canvas.get_node_or_null("Control_HUD")
			if hud_node:
				var heart = hud_node.get_node_or_null("TextureRect_Heart")
				if heart and heart != revive_heart:
					heart.visible = false
					var other_tween = create_tween()
					other_tween.tween_property(heart, "modulate:a", 0.0, 0.3)

func restore_revive_heart() -> void:
	if revive_heart and is_instance_valid(revive_heart):
		revive_heart.visible = true
		revive_heart.modulate.a = 1.0
		
		var tween = create_tween()
		tween.tween_property(revive_heart, "modulate:a", 1.0, 0.3)
		tween.tween_callback(func(): pass)
	
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node:
		var canvas_layers = []
		for child in main_node.get_children():
			if child is CanvasLayer:
				canvas_layers.append(child)
		
		for canvas in canvas_layers:
			var hud_node = canvas.get_node_or_null("Control_HUD")
			if hud_node:
				var heart = hud_node.get_node_or_null("TextureRect_Heart")
				if heart and heart != revive_heart:
					heart.visible = true
					heart.modulate.a = 1.0
					var other_tween = create_tween()
					other_tween.tween_property(heart, "modulate:a", 1.0, 0.3)

func _on_back_to_menu():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
