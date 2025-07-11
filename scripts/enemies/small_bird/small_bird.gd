extends "res://scripts/enemies/base/enemy_ai_base.gd"

#region 狀態腳本預載入
const SmallBirdPatrolState = preload("res://scripts/enemies/small_bird/states/SmallBirdPatrolState.gd")
const SmallBirdChaseState = preload("res://scripts/enemies/small_bird/states/SmallBirdChaseState.gd")
const SmallBirdAttackState = preload("res://scripts/enemies/small_bird/states/SmallBirdAttackState.gd")
const SmallBirdHurtState = preload("res://scripts/enemies/small_bird/states/SmallBirdHurtState.gd")
const DeadState = preload("res://scripts/enemies/base/states/common/DeadState.gd")
#endregion


#region 導出屬性 (覆寫或新增)
@export_group("飛行行為")
@export var patrol_area_radius: float = 300.0
@export var patrol_speed: float = 100.0
@export var chase_speed: float = 250.0
@export var dive_speed: float = 400.0
@export var climb_speed: float = 200.0
@export var ideal_attack_height: float = 150.0

@export_group("攻擊行為")
@export var dive_attack_damage: int = 15
#endregion


#region 節點與變數
var patrol_center: Vector2
@onready var standing_collision_shape: CollisionShape2D = $StandingCollisionShape
@onready var flying_collision_shape: CollisionShape2D = $FlyingCollisionShape
#endregion


func _ready() -> void:
	super._ready()
	
	patrol_center = global_position
	
	gravity_scale = 0
	
	_initialize_states()
	
	if is_instance_valid(animated_sprite):
		animated_sprite.animation_changed.connect(set_collision_shape_state)
		set_collision_shape_state()
	else:
		push_warning("SmallBird: 找不到 AnimatedSprite2D 節點！形狀切換將無法運作。")
	
	change_state("Patrol")


func set_collision_shape_state() -> void:
	"""
	根據當前的動畫名稱，啟用對應的主要物理碰撞體，並禁用另一個。
	"""
	if not is_instance_valid(animated_sprite):
		return

	var animation_name = animated_sprite.animation
	
	if animation_name.begins_with("sit"):
		standing_collision_shape.set_deferred("disabled", false)
		flying_collision_shape.set_deferred("disabled", true)
	else:
		standing_collision_shape.set_deferred("disabled", true)
		flying_collision_shape.set_deferred("disabled", false)
	
	if is_node_ready():
		update_shared_shapes()


func _initialize_states() -> void:
	"""初始化並註冊所有狀態。"""
	add_state("Patrol", SmallBirdPatrolState.new())
	add_state("Chase", SmallBirdChaseState.new())
	add_state("Attack", SmallBirdAttackState.new())
	add_state("Hurt", SmallBirdHurtState.new())
	add_state("Dead", DeadState.new())


#region 動畫名稱覆寫
func _get_idle_animation() -> String: return "idle"
func _get_walk_animation() -> String: return "walk"
func _get_fly_animation() -> String: return "fly"
func _get_soar_animation() -> String: return "soar"
func _get_attack_animation() -> String: return "attack_air"
func _get_hurt_animation() -> String: return "hurt"
func _get_death_animation() -> String: return "die"
func _get_fall_animation() -> String: return "fall"
func _get_takeoff_animation() -> String: return "takeoff"
func _get_land_animation() -> String: return "land"
#endregion

# region 狀態切換邏輯
# 基於 EnemyAIBase 的信號回調，實現小鳥的狀態切換邏輯

func _on_detection_area_body_entered(body: Node) -> void:
	super._on_detection_area_body_entered(body) # 呼叫父類方法以設定 self.player
	# 只有在可以被中斷的狀態下，偵測到玩家才會切換到追擊狀態
	if current_state_name in ["Patrol", "Idle"]:
		change_state("Chase")

func _on_detection_area_body_exited(body: Node) -> void:
	super._on_detection_area_body_exited(body) # 呼叫父類方法以清除 self.player
	# 只有在追擊狀態下，丟失玩家才會切換回巡邏狀態
	if current_state_name == "Chase":
		change_state("Patrol")

# endregion


func take_damage(amount: float, _attacker: Node) -> void:
	if current_state_name == "Dead":
		return
		
	health -= amount
	
	if health <= 0:
		change_state("Dead")
	else:
		change_state("Hurt")
