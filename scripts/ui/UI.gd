extends CanvasLayer

@onready var hud = $Control_HUD
@onready var health_bar = $Control_HUD/TextureProgressBar_HP
@onready var mana_bar = $Control_HUD/TextureProgressBar_MP
@onready var revive_heart = $Control_HUD/TextureRect_Heart

const PauseMenu = preload("res://scenes/ui/PauseMenu.tscn")
var pause_menu
var is_initialized := false

func _ready():
	add_to_group("ui")
	_initialize_bars()
	
	# 添加暫停選單
	pause_menu = PauseMenu.instantiate()
	add_child(pause_menu)
	if pause_menu:
		pause_menu.back_to_menu.connect(_on_back_to_menu)
	
	# 等待一幀後再設置信號
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
		
		# 連接玩家金錢變化信號
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if not player.gold_changed.is_connected(update_gold):
				player.gold_changed.connect(update_gold)
			# 立即更新當前金錢顯示
			update_gold(player.gold)

func _connect_player():
	# 確保節點已經在場景樹中
	if not is_inside_tree():
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 先斷開可能存在的連接
		if player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.disconnect(_on_player_health_changed)
		if player.gold_changed.is_connected(update_gold):
			player.gold_changed.disconnect(update_gold)
		
		# 重新連接信號
		player.health_changed.connect(_on_player_health_changed)
		player.gold_changed.connect(update_gold)
		
		# 更新血量和金錢顯示
		_update_health_bar(player)
		update_gold(player.gold)

func _update_health_bar(player: Node) -> void:
	if health_bar and player:
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health

func _exit_tree():
	if get_tree():
		# 斷開玩家信號
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
	print("[UI] 隱藏重生之心")
	if revive_heart and is_instance_valid(revive_heart):
		revive_heart.visible = false

func restore_revive_heart() -> void:
	print("[UI] 顯示重生之心")
	if revive_heart and is_instance_valid(revive_heart):
		revive_heart.visible = true

func _on_back_to_menu():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
