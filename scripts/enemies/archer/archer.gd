extends "res://scripts/enemies/base/enemy_ai_base.gd"

# 預載入狀態類別
const IdleState = preload("res://scripts/enemies/base/states/common/enemy_idle_state.gd")
const WanderState = preload("res://scripts/enemies/base/states/common/enemy_wander_state.gd")
const DeadState = preload("res://scripts/enemies/base/states/common/enemy_dead_state.gd")
const ChaseState = preload("res://scripts/enemies/archer/states/archer_chase_state.gd")
const AttackState = preload("res://scripts/enemies/archer/states/archer_attack_state.gd")
const HurtState = preload("res://scripts/enemies/archer/states/archer_hurt_state.gd")
const HoldPositionState = preload("res://scripts/enemies/archer/states/archer_hold_position_state.gd")

@export_group("理想距離區間")
@export var optimal_attack_range_min: float = 150.0 # 理想攻擊距離下限
@export var optimal_attack_range_max: float = 300.0 # 理想攻擊距離上限
@export var stop_chase_distance: float = 170.0 # 停止追擊的距離 (略大於下限，防抖)

#region 節點引用
@onready var arrow_spawn_point: Marker2D = $AnimatedSprite2D/ArrowSpawnPoint
#endregion

#region 場景預載
var arrow_scene = preload("res://scenes/enemies/archer/arrow.tscn")
#endregion

#region 狀態變量
var attack_direction: Vector2 = Vector2.RIGHT
var locked_target_position: Vector2 = Vector2.ZERO # 用於儲存鎖定的目標位置
#endregion


func _ready() -> void:
	super._ready()
	
	register_zone("in_attack_zone", $AttackArea)
	register_zone("in_retreat_zone", $RetreatRangeArea)
	
	add_state("Idle", IdleState.new())
	add_state("Wander", WanderState.new())
	add_state("Chase", ChaseState.new())
	add_state("Attack", AttackState.new())
	add_state("Hurt", HurtState.new())
	add_state("Dead", DeadState.new())
	add_state("HoldPosition", HoldPositionState.new())
	
	change_state("Idle")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	

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
	return "idle"

func _get_death_animation() -> String:
	return "die"
#endregion


#region 核心功能覆寫
func take_damage(amount: float, attacker: Node) -> void:
	super.take_damage(amount, attacker)


func _on_death() -> void:
	# 遊戲邏輯 (通知 CombatSystem、掉落物等)
	var combat_system = get_node_or_null("/root/CombatSystem")
	if combat_system and combat_system.has_method("enemy_killed"):
		combat_system.enemy_killed()
		
	# 執行父類的死亡邏輯 (禁用物理、碰撞等)
	super._on_death()


func _on_attack_animation_finished() -> void:
	shoot_arrow()
#endregion

#region 弓箭手專用函式
func attack_is_ready() -> bool:
	# 檢查攻擊是否冷卻完畢。
	return attack_cooldown_timer.is_stopped()

func shoot_arrow() -> void:
	if locked_target_position == Vector2.ZERO:
		return

	# 計算箭矢生成位置
	var spawn_pos = _get_corrected_spawn_position()
	
	# 臨時實例化箭矢以獲取物理參數
	var temp_arrow = arrow_scene.instantiate()
	var arrow_speed = temp_arrow.speed
	var arrow_gravity_scale = temp_arrow.gravity_scale
	var arrow_gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * arrow_gravity_scale
	temp_arrow.queue_free()
	
	# 計算考慮重力補償的攻擊方向
	attack_direction = _calculate_attack_direction(spawn_pos, locked_target_position, arrow_speed, arrow_gravity)
	
	# 生成並初始化箭矢
	_spawn_arrow(spawn_pos)
	
	# 重置鎖定目標，準備下次攻擊
	locked_target_position = Vector2.ZERO

func _get_corrected_spawn_position() -> Vector2:
	# 獲取考慮角色朝向的正確箭矢生成位置。
	var local_spawn_pos = arrow_spawn_point.position
	
	# 翻轉生成點 X 座標
	if animated_sprite.flip_h:
		local_spawn_pos.x = -local_spawn_pos.x
	
	return to_global(local_spawn_pos)

func _calculate_attack_direction(spawn_pos: Vector2, target_pos: Vector2, arrow_speed: float, arrow_gravity: float) -> Vector2:
	# 計算考慮重力補償的最佳攻擊方向。
	var compensated_target = _calculate_compensated_target(spawn_pos, target_pos, arrow_speed, arrow_gravity)
	
	return (compensated_target - spawn_pos).normalized()

func _spawn_arrow(spawn_pos: Vector2) -> void:
	# 在指定位置生成並初始化箭矢。
	var arrow = arrow_scene.instantiate()
	
	get_tree().root.add_child(arrow)
	arrow.global_position = spawn_pos
	
	if arrow.has_method("initialize"):
		arrow.initialize(attack_direction, self)

func _calculate_compensated_target(spawn_pos: Vector2, original_target: Vector2, arrow_speed: float, arrow_gravity: float) -> Vector2:
	var displacement = original_target - spawn_pos
	var horizontal_distance = abs(displacement.x)
	
	# 近距離攻擊閾值：80 像素內不進行重力補償
	const MIN_COMPENSATION_DISTANCE = 80.0
	if horizontal_distance < MIN_COMPENSATION_DISTANCE:
		return original_target
	
	# 計算箭矢飛行時間
	var flight_time = _calculate_flight_time(displacement, arrow_speed)
	
	# 計算重力造成的垂直位移
	var gravity_drop = _calculate_gravity_drop(arrow_gravity, flight_time)
	
	# 應用補償（使用 70% 補償係數防止過度瞄準）
	const COMPENSATION_FACTOR = 0.7
	var compensated_target = original_target
	compensated_target.y -= gravity_drop * COMPENSATION_FACTOR
	
	return compensated_target

func _calculate_flight_time(displacement: Vector2, arrow_speed: float) -> float:
	var horizontal_distance = abs(displacement.x)
	var direct_distance = displacement.length()
	
	# 計算水平速度分量比例
	var horizontal_ratio = horizontal_distance / direct_distance if direct_distance > 0 else 1.0
	var effective_horizontal_velocity = arrow_speed * horizontal_ratio
	
	return horizontal_distance / effective_horizontal_velocity

func _calculate_gravity_drop(arrow_gravity: float, flight_time: float) -> float:
	return 0.5 * arrow_gravity * flight_time * flight_time

func _is_wall_or_ledge_behind() -> bool:
	# 判斷當前朝向
	var is_facing_left = animated_sprite.flip_h
	
	# 牆壁檢測
	var wall_check_direction = Vector2.RIGHT if is_facing_left else Vector2.LEFT
	var motion = wall_check_direction * 1.0
	var wall_is_behind = test_move(global_transform, motion)

	# 懸崖檢測
	var edge_check_ray = $EdgeCheckRight if is_facing_left else $EdgeCheckLeft
	var ledge_is_behind = not edge_check_ray.is_colliding()
	
	return wall_is_behind or ledge_is_behind

#endregion 
