extends CanvasLayer

@onready var hud = $Control_HUD
@onready var health_bar = $Control_HUD/TextureProgressBar_HP
@onready var mana_bar = $Control_HUD/TextureProgressBar_MP
@onready var revive_heart = $Control_HUD/TextureRect_Heart

const PauseMenu = preload("res://scenes/ui/pause_menu.tscn")
var pause_menu
var is_initialized := false
var ui_system: Node
var player: Node

func _ready():
	add_to_group("ui")
	_initialize_bars()
	
	# 獲取系統引用
	ui_system = get_node_or_null("/root/UISystem")
	
	# 創建系統UI層的CanvasLayer（高於遊戲內UI）
	var system_ui_canvas = CanvasLayer.new()
	system_ui_canvas.name = "SystemUICanvas"
	system_ui_canvas.layer = 25  # 系統UI層 (20-29)  
	system_ui_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(system_ui_canvas)
	
	pause_menu = PauseMenu.instantiate()
	system_ui_canvas.add_child(pause_menu)
	if pause_menu:
		pause_menu.back_to_menu.connect(_on_back_to_menu)
	
	await get_tree().process_frame
	_setup_player_connection()

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

func _setup_player_connection() -> void:
	if is_initialized:
		return
		
	player = get_tree().get_first_node_in_group("player")
	if player:
		_connect_to_player()
		is_initialized = true

func _connect_to_player() -> void:
	if not player:
		return
		
	# 清理舊連接
	if player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.disconnect(_on_player_health_changed)
	if player.gold_changed.is_connected(update_gold):
		player.gold_changed.disconnect(update_gold)
	
	# 建立新連接
	player.health_changed.connect(_on_player_health_changed)
	player.gold_changed.connect(update_gold)
	
	# 初始化顯示
	_update_health_bar(player)
	update_gold(player.gold)

func _disconnect_from_player() -> void:
	if player and is_instance_valid(player):
		if player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.disconnect(_on_player_health_changed)
		if player.gold_changed.is_connected(update_gold):
			player.gold_changed.disconnect(update_gold)

func _update_health_bar(player_node: Node) -> void:
	if health_bar and player_node:
		health_bar.max_value = player_node.max_health
		health_bar.value = player_node.current_health

func _exit_tree():
	_disconnect_from_player()

func _on_player_health_changed(new_health: int) -> void:
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
	
	# 通過UI系統統一處理其他UI實例
	_sync_revive_hearts(false)

func restore_revive_heart() -> void:
	if revive_heart and is_instance_valid(revive_heart):
		revive_heart.visible = true
		revive_heart.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(revive_heart, "modulate:a", 1.0, 0.3)
	
	# 通過UI系統統一處理其他UI實例
	_sync_revive_hearts(true)

func _sync_revive_hearts(heart_visible: bool) -> void:
	# 統一處理所有UI實例的復活心形圖標
	var all_uis = get_tree().get_nodes_in_group("ui")
	for ui_node in all_uis:
		if ui_node != self and ui_node.has_method("_set_revive_heart_visibility"):
			ui_node._set_revive_heart_visibility(heart_visible)

func _set_revive_heart_visibility(heart_visible: bool) -> void:
	if revive_heart and is_instance_valid(revive_heart):
		revive_heart.visible = heart_visible
		revive_heart.modulate.a = 1.0 if heart_visible else 0.0

func _on_back_to_menu():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
