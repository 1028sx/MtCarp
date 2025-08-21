extends "res://scripts/enemies/base/enemy_ai_base.gd"


@export_group("理想距離區間")
@export var optimal_attack_range_min: float = 150.0 # 理想攻擊距離下限
@export var optimal_attack_range_max: float = 300.0 # 理想攻擊距離上限
@export var stop_chase_distance: float = 170.0 # 停止追擊的距離 (略大於min，防抖)

#region 節點引用
@onready var health_bar: ProgressBar = $HealthBar
@onready var arrow_spawn_point: Marker2D = $AnimatedSprite2D/ArrowSpawnPoint
#endregion

#region 場景預載
var arrow_scene = preload("res://scenes/enemies/arrow.tscn")
#endregion

#region 狀態變量
var attack_direction: Vector2 = Vector2.RIGHT
var locked_target_position: Vector2 = Vector2.ZERO # 新增：用於儲存鎖定的目標位置
#endregion


func _ready() -> void:
	super._ready()
	
	register_zone("in_attack_zone", $AttackArea)
	register_zone("in_retreat_zone", $RetreatRangeArea)
	
	add_state("Idle", EnemyIdleState.new())
	add_state("Wander", EnemyWanderState.new())
	add_state("Chase", ArcherChaseState.new())
	add_state("Attack", ArcherAttackState.new())
	add_state("Hurt", ArcherHurtState.new())
	add_state("Dead", EnemyDeadState.new())
	add_state("HoldPosition", ArcherHoldPositionState.new())
	
	change_state("Idle")

	if health_bar:
		health_bar.max_value = health
		health_bar.value = health

func _physics_process(delta: float) -> void:
	super._physics_process(delta) # 調用父類的 _physics_process
	

#region 動畫名稱覆寫
func _get_idle_animation() -> String:
	return "idle"

func _get_walk_animation() -> String:
	return "run"

func _get_attack_animation() -> String:
	return "attack"

func _get_hurt_animation() -> String:
	return "hit"
	
func _get_hold_position_animation() -> String:
	# 堅守陣地時，我們希望它播放待機動畫
	return "idle"

func _get_death_animation() -> String:
	return "die"
#endregion


#region 核心功能覆寫
func take_damage(amount: float, attacker: Node) -> void:
	super.take_damage(amount, attacker) # 調用父類別的 take_damage
	if health_bar:
		health_bar.value = health


func _on_death() -> void:
	# 遊戲邏輯 (通知 GameManager、掉落物等)
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("enemy_killed"):
		game_manager.enemy_killed()
		
	var word_system = get_tree().get_first_node_in_group("word_system")
	if word_system and word_system.has_method("handle_enemy_drops"):
		word_system.handle_enemy_drops("Archer", global_position)
		
	# 執行父類的死亡邏輯 (禁用物理、碰撞等)
	super._on_death()


func _on_attack_animation_finished() -> void:
	# 這個函式現在由 AttackState 透過信號呼叫。
	# 我們在這裡只執行射箭的動作。
	# 狀態轉換和冷卻的邏輯已經移到 AttackState 中。
	shoot_arrow()
#endregion

#region 弓箭手專用函式
func attack_is_ready() -> bool:
	"""檢查攻擊是否冷卻完畢。"""
	return attack_cooldown_timer.is_stopped()

func shoot_arrow() -> void:
	# 如果沒有鎖定的目標位置，則不執行任何操作
	if locked_target_position == Vector2.ZERO:
		return

	# --- 關鍵修正：確保箭矢生成點與角色朝向同步 ---
	# 1. 獲取原始的本地生成點位置 (相對於弓箭手)
	var local_spawn_pos = arrow_spawn_point.position
	# 2. 如果角色朝左 (flip_h = true)，手動將生成點的 X 座標翻轉
	if animated_sprite.flip_h:
		local_spawn_pos.x = -local_spawn_pos.x
	# 3. 將校正後的本地位置轉換為絕對的全域位置
	var spawn_pos = to_global(local_spawn_pos)

	# 計算攻擊方向（基於鎖定的位置）
	var target_pos = locked_target_position
	# 根據與目標的距離，動態調整拋物線補償
	var distance = global_position.distance_to(target_pos)
	var height_compensation = distance * 0.1 # 輕微的拋物線補償
	target_pos.y -= height_compensation # 向上拋射，所以是減
	attack_direction = (target_pos - spawn_pos).normalized()

	var arrow = arrow_scene.instantiate()
	
	get_tree().root.add_child(arrow)
	# 使用校正後的全域位置來放置箭矢
	arrow.global_position = spawn_pos
	
	if arrow.has_method("initialize"):
		arrow.initialize(attack_direction, self)
		
	# 重置鎖定的位置，為下一次攻擊做準備
	locked_target_position = Vector2.ZERO

func _is_wall_or_ledge_behind() -> bool:
	"""
	檢查角色身後是否有牆壁或懸崖。
	這個函式對於 AI 的「風箏」行為至關重要，特別是在決定是否可以安全後退時。
	此函式經過最終升級，使用 test_move 來可靠地檢測牆壁，無論角色是否正在移動。

	返回:
		bool: 如果身後有真正的牆或懸崖，則返回 true；否則返回 false。
	"""
	# 判斷當前朝向。flip_h 為 true 表示朝左，我們想檢查右邊。
	var is_facing_left = animated_sprite.flip_h
	
	# --- 升級後的牆壁檢測 (使用 test_move) ---
	var wall_check_direction = Vector2.RIGHT if is_facing_left else Vector2.LEFT
	var motion = wall_check_direction * 1.0 # 檢查身後 1 個像素的距離
	var wall_is_behind = test_move(global_transform, motion)

	# --- 懸崖檢測 (維持不變) ---
	var edge_check_ray = $EdgeCheckRight if is_facing_left else $EdgeCheckLeft
	var ledge_is_behind = not edge_check_ray.is_colliding()
	
	return wall_is_behind or ledge_is_behind

#endregion 
