extends Node

signal walls_activated()
signal walls_deactivated()

var temporary_walls: Array[Node] = []
var is_walls_active: bool = false

func _ready() -> void:
	add_to_group("wall_manager")
	name = "WallManager"
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_connect_signals()

func _connect_signals() -> void:
	var combat_system = get_node_or_null("/root/CombatSystem")
	if combat_system:
		if not combat_system.boss_spawned.is_connected(_on_boss_spawned):
			combat_system.boss_spawned.connect(_on_boss_spawned)
		if not combat_system.boss_defeated_manager.is_connected(_on_boss_defeated):
			combat_system.boss_defeated_manager.connect(_on_boss_defeated)
	
	_connect_player_signals()

func _connect_player_signals() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = PlayerSystem.get_player()
	
	if player:
		if player.has_signal("player_fully_died"):
			if not player.player_fully_died.is_connected(_on_player_died):
				player.player_fully_died.connect(_on_player_died)
		elif player.has_signal("died"):
			if not player.died.is_connected(_on_player_died):
				player.died.connect(_on_player_died)

func activate_temporary_walls() -> void:
	if is_walls_active:
		return
	
	find_temporary_walls()
	
	if temporary_walls.is_empty():
		return
	
	for wall in temporary_walls:
		if is_instance_valid(wall):
			wall.play_spawn_animation()
	
	is_walls_active = true
	walls_activated.emit()

func deactivate_temporary_walls() -> void:
	if not is_walls_active:
		return
	
	if temporary_walls.is_empty():
		return
	
	for wall in temporary_walls:
		if is_instance_valid(wall):
			wall.play_despawn_animation()
	
	is_walls_active = false
	walls_deactivated.emit()

func find_temporary_walls() -> void:
	temporary_walls.clear()
	var all_walls = get_tree().get_nodes_in_group("temporary_walls")
	temporary_walls = all_walls

func _on_boss_spawned(_boss_name: String, _boss_position: Vector2) -> void:
	await get_tree().create_timer(0.5).timeout
	# 確保玩家完全進入房間
	var current_bosses = get_tree().get_nodes_in_group("boss")
	if current_bosses.size() > 0:
		activate_temporary_walls()

func _on_boss_defeated(_boss_name: String) -> void:
	deactivate_temporary_walls()

func _on_player_died() -> void:
	deactivate_temporary_walls()

func force_activate_walls() -> void:
	activate_temporary_walls()

func force_deactivate_walls() -> void:
	deactivate_temporary_walls()

func is_walls_currently_active() -> bool:
	return is_walls_active and not temporary_walls.is_empty()

func reset_wall_system() -> void:
	is_walls_active = false
	temporary_walls.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		deactivate_temporary_walls()
		temporary_walls.clear()
