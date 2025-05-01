extends CharacterBody2D

# 正確宣告信號
signal defeated

# 常量
const TRANSPARENT_DISTANCE = 500.0  # 距離超過此值時進入半透明狀態
const TRANSPARENT_ALPHA = 0.5  # 半透明狀態的透明度
const BASE_SPEED = 200.0  # 基本速度
const MAX_SPEED = 500.0  # 最大速度
const FALL_SPEED = 400.0  # 降落速度
const FLAP_INTERVAL = 1.0  # 拍翅間隔

# 戰鬥相關
@export var health = 200  # 添加生命值
@export var damage = 10   # 改為導出變量
var is_dying = false  # 添加死亡狀態標記

# 狀態變量
var is_transparent = false
var player_detected = false
var flap_timer = 0.0
var current_speed = BASE_SPEED

# 添加動畫狀態枚舉
enum AnimationState {
	IDLE,
	WALK,
	FLY,
	SOAR,
	ATTACK_AIR,
	ATTACK_GROUND,
	HURT,
	DIE,
	FALL,
	LAND,
	DASH,
	TAKEOFF,
	SIT_IDLE,
	SIT_CALL,
	IDLE_CALL,
	SOAR_CALL
}

# 添加狀態變量
var current_animation_state = AnimationState.IDLE
var is_on_ground = false
var is_attacking = false
var is_sitting = false
var is_calling = false

# 動畫
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_timer = $AttackTimer
@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackArea
@onready var hitbox = $Hitbox

# 修改攻擊計時器相關邏輯
@export var attack_cooldown: float = 2.0  # 攻擊冷卻時間
@export var attack_range: float = 150.0   # 攻擊範圍

func _ready() -> void:
	animated_sprite.play("idle")
	
	# 設置攻擊計時器
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true  # 設置為單次觸發
	
	_initialize_enemy()
	_setup_collisions()
	_connect_signals()
	
	# 連接動畫完成信號
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _initialize_enemy():
	add_to_group("enemy")

func _setup_collisions():
	# 設置鳥本體的碰撞層
	set_collision_layer_value(1, false)  # 不與地形碰撞
	set_collision_layer_value(2, false)  # 不與玩家碰撞
	set_collision_layer_value(3, false)  # 不作為受傷區域
	set_collision_layer_value(4, false)  # 不作為攻擊區域
	set_collision_layer_value(5, true)   # 設為敵人專用層
	
	# 設置鳥的碰撞檢測
	set_collision_mask_value(1, true)    # 檢測地形
	set_collision_mask_value(2, false)   # 不檢測玩家
	set_collision_mask_value(3, false)   # 不檢測受傷區域
	set_collision_mask_value(4, false)   # 不檢測攻擊區域
	set_collision_mask_value(5, false)   # 不檢測其他敵人
	
	# 設置鳥的受傷區域
	if hitbox:
		hitbox.set_collision_layer_value(3, true)   # 設為受傷區域
		hitbox.set_collision_mask_value(4, true)    # 檢測攻擊區域

	# 設置鳥的攻擊區域
	if attack_area:
		attack_area.set_collision_layer_value(4, true)  # 設為攻擊區域
		attack_area.set_collision_mask_value(3, true)   # 檢測受傷區域
		attack_area.monitoring = false  # 初始時關閉攻擊檢測
		
	# 設置檢測區域
	if detection_area:
		detection_area.set_collision_layer_value(1, false)
		detection_area.set_collision_mask_value(2, true)    # 檢測玩家層
		detection_area.monitoring = true  # 開啟玩家檢測

func _connect_signals():
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

func _process(delta: float) -> void:
	_update_transparency()
	_handle_movement(delta)
	_update_animation(delta)

func _update_transparency() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player > TRANSPARENT_DISTANCE:
			if not is_transparent:
				_enter_transparent_state()
		else:
			if is_transparent:
				_exit_transparent_state()

func _enter_transparent_state() -> void:
	is_transparent = true
	modulate.a = TRANSPARENT_ALPHA
	collision_layer = 0

func _exit_transparent_state() -> void:
	is_transparent = false
	modulate.a = 1.0
	collision_layer = 1

func _handle_movement(delta: float) -> void:
	if not is_transparent and not is_dying and not is_attacking:
		if player_detected:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				var direction = (player.global_position - global_position).normalized()
				var distance = global_position.distance_to(player.global_position)
				
				# 在攻擊範圍內停止移動並開始攻擊
				if distance <= attack_range:
					velocity = Vector2.ZERO
					if not attack_timer.is_stopped():
						_try_attack()
				else:
					velocity = direction * current_speed
				
				# 根據與玩家的距離決定是否坐下
				is_sitting = distance < 100.0
				
				# 隨機呼叫
				if randf() < delta * 0.1:  # 10%機率每秒
					is_calling = true
		else:
			velocity.x = current_speed + randf_range(-20, 20)
			is_sitting = randf() < delta * 0.05  # 5%機率每秒
			
			# 隨機呼叫
			if randf() < delta * 0.05:  # 5%機率每秒
				is_calling = true
		
		if velocity.x != 0:
			animated_sprite.flip_h = velocity.x < 0
		
		# 檢測是否在地面
		is_on_ground = is_on_floor()
		
		# 如果在地面上且要起飛
		if is_on_ground and abs(velocity.y) > 10:
			_play_animation("takeoff")
		# 如果在空中且要降落
		elif not is_on_ground and is_on_floor():
			_play_animation("land")
		
		move_and_slide()
		
		# 增加速度直到達到最大速度
		current_speed = min(current_speed + 10 * delta, MAX_SPEED)

func _update_animation(delta: float) -> void:
	if is_dying:
		return
		
	if is_transparent:
		_play_animation("fly")
		return
		
	flap_timer += delta
	
	# 根據狀態決定動畫
	if is_attacking:
		if is_on_ground:
			_play_animation("attack_ground")
		else:
			_play_animation("attack_air")
	elif velocity.y > 0:
		current_speed = FALL_SPEED
		_play_animation("fall")
	elif velocity.y < 0:
		if flap_timer >= FLAP_INTERVAL:
			_play_animation("soar")
			flap_timer = 0.0
	else:
		if is_on_ground:
			if velocity.x != 0:
				_play_animation("walk")
			else:
				if is_sitting:
					if is_calling:
						_play_animation("sit_call")
					else:
						_play_animation("sit_idle")
				else:
					if is_calling:
						_play_animation("idle_call")
					else:
						_play_animation("idle")
		else:
			if abs(velocity.x) > MAX_SPEED * 0.8:
				_play_animation("dash")
			else:
				if is_calling:
					_play_animation("soar_call")
				else:
					_play_animation("fly")

func _play_animation(anim_name: String) -> void:
	if animated_sprite and animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _on_animation_finished() -> void:
	match animated_sprite.animation:
		"attack_air", "attack_ground":
			is_attacking = false
		"takeoff":
			is_on_ground = false
		"land":
			is_on_ground = true
		"hurt":
			if not is_dying:
				is_attacking = false
		"sit_call", "idle_call", "soar_call":
			is_calling = false
		"dash":
			if is_on_ground:
				_play_animation("walk")
			else:
				_play_animation("fly")
		"die":
			queue_free()  # 死亡動畫播放完後刪除節點

func _try_attack() -> void:
	if not is_attacking and not is_dying and not is_transparent:
		is_attacking = true
		# 根據是否在地面選擇攻擊動畫
		if is_on_ground:
			_play_animation("attack_ground")
		else:
			_play_animation("attack_air")
		attack_timer.start()

func _on_attack_timer_timeout() -> void:
	if not is_transparent and player_detected and not is_dying:
		_try_attack()

func _apply_damage() -> void:
	if attack_area and is_attacking:
		var areas = attack_area.get_overlapping_areas()
		for area in areas:
			var body = area.get_parent()
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(damage)
				print("[Bird] 對玩家造成 %d 點傷害" % damage)

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player_detected = true

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		player_detected = false

# 修改 take_damage 函數
func take_damage(amount: int) -> void:
	if is_dying:
		return
		
	health -= amount
	is_attacking = false
	is_sitting = false
	is_calling = false
	
	# 播放受傷動畫
	_play_animation("hurt")
	
	if health <= 0:
		die()

func die() -> void:
	if is_dying:
		return
		
	is_dying = true
	is_attacking = false
	is_sitting = false
	is_calling = false
	
	# 使用 WordSystem 處理掉落
	var word_system = get_tree().get_first_node_in_group("word_system")
	if word_system:
		word_system.handle_enemy_drops("Bird", global_position)
	
	# 發送信號
	defeated.emit()
	
	# 播放死亡動畫
	_play_animation("die")
