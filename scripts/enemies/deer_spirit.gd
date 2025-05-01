extends CharacterBody2D

signal defeated
signal phase_two_attack_completed

#region 導出屬性
@export var spirit_color = "White"  # 精靈顏色
@export var hits_remaining = 3  # 需要被打幾次才會死亡
@export var attack_cooldown = 1.0  # 攻擊冷卻時間
@export var move_speed = 200.0  # 移動速度
@export var jump_force = -450.0  # 跳躍力度
@export var damage = 15  # 傷害值（原本是30的一半）
@export var knockback_resistance = 0.95  # 擊退抗性

# 常量
const BULLET_COUNT = 8  # 彈幕數量（比Boss少一半）
const BULLET_SPEED = 300.0  # 彈幕速度
const BULLET_DAMAGE = 5  # 彈幕傷害（原本是10的一半）
const ATTACK2_DURATION = 2.0  # 彈幕攻擊持續時間
const ATTACK2_RECOVERY = 0.7  # 彈幕攻擊後搖時間
const MELEE_RANGE = 50.0  # 近戰範圍
const RANGED_RANGE = 300.0  # 遠程攻擊範圍
const CHASE_TIME_LIMIT = 3.0  # 追逐時間限制
const SPIRIT_HEALTH = 3  # 精靈需要被打三次才會死亡
const JUMP_COOLDOWN = 2.0  # 跳躍冷卻時間
const MAX_JUMP_ATTEMPTS = 2  # 連續跳躍嘗試次數限制（比Boss少）
const HEIGHT_THRESHOLD = -100.0  # 高度差閾值（比Boss小）

# 新增：顏色設置
const COLOR_SETTINGS = {
	"Red": Color(1.5, 0.3, 0.3, 0.8),    # 鮮紅色
	"Orange": Color(1.5, 0.8, 0.3, 0.8),  # 橙色
	"Yellow": Color(1.5, 1.5, 0.3, 0.8),  # 黃色
	"Green": Color(0.3, 1.5, 0.3, 0.8),   # 綠色
	"Blue": Color(0.3, 0.3, 1.5, 0.8),    # 藍色
	"Purple": Color(1.2, 0.3, 1.2, 0.8),  # 紫色
	"Black": Color(0.2, 0.2, 0.2, 0.8),   # 黑色
	"White": Color(1.2, 1.2, 1.2, 0.8)    # 白色
}
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_area = $AttackArea
@onready var hitbox = $Hitbox
@onready var attack_timer = $AttackTimer
@onready var detection_area = $DetectionArea
#endregion

#region 狀態變量
enum State {IDLE, MOVE, JUMP, ATTACK1, ATTACK2, RANGED, HURT, DIE}
var current_state = State.IDLE
var is_dying = false
var has_jumped = false
var chase_timer = 0.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var target_player = null
var knockback_velocity = Vector2.ZERO
var can_attack = true
var is_performing_ranged = false  # 新增：標記是否正在執行遠程攻擊
var original_alpha = 0.8  # 初始透明度
var current_alpha = 0.8  # 當前透明度
var health_percent = 1.0  # 生命值百分比
var max_hits = 3     # 最大生命值
var last_jump_time = 0.0  # 上次跳躍時間
var jump_attempt_count = 0  # 跳躍嘗試次數
#endregion

#region 初始化
func _ready():
	_initialize_spirit()
	_setup_collisions()
	
	# 連接所有信號
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if attack_timer:
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
		animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	# 設置初始透明度為0並漸入
	modulate.a = 0
	current_alpha = original_alpha
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", current_alpha, 0.5)
	
	# 確保一開始不會攻擊
	if attack_timer:
		attack_timer.one_shot = true
		attack_timer.wait_time = attack_cooldown

func _initialize_spirit():
	add_to_group("enemy")
	add_to_group("deer_spirit")
	if animated_sprite:
		animated_sprite.play("idle")
		_apply_color_effect()

func _setup_collisions():
	# 設置精靈本體的碰撞層
	set_collision_layer_value(1, false)  # 不與地形碰撞
	set_collision_layer_value(2, false)  # 不與玩家碰撞
	set_collision_layer_value(3, false)  # 不作為受傷區域
	set_collision_layer_value(4, false)  # 不作為攻擊區域
	set_collision_layer_value(5, false)  # 不與其他敵人碰撞
	
	# 設置精靈的碰撞檢測
	set_collision_mask_value(1, true)    # 只檢測地形
	set_collision_mask_value(2, false)   # 不檢測玩家
	set_collision_mask_value(3, false)   # 不檢測受傷區域
	set_collision_mask_value(4, false)   # 不檢測攻擊區域
	set_collision_mask_value(5, false)   # 不檢測其他敵人
	
	# 設置精靈的攻擊區域（用於傷害玩家）
	if attack_area:
		attack_area.set_collision_layer_value(4, true)  # 設為攻擊區域
		attack_area.set_collision_mask_value(3, true)   # 檢測受傷區域
	
	# 設置精靈的受傷區域
	if hitbox:
		hitbox.set_collision_layer_value(3, true)   # 設為受傷區域
		hitbox.set_collision_mask_value(4, true)    # 檢測攻擊區域
	
	# 設置精靈的檢測區域
	if detection_area:
		detection_area.set_collision_layer_value(1, false)  # 不設置碰撞層
		detection_area.set_collision_mask_value(2, true)    # 只檢測玩家層

func setup(color: String, init_health: int):
	spirit_color = color
	max_hits = init_health
	hits_remaining = init_health
	if animated_sprite:
		_apply_color_effect()
#endregion

#region 主要邏輯
func _physics_process(delta):
	if is_dying:
		return
		
	_apply_gravity(delta)
	_handle_state(delta)
	_apply_movement()
	
	# 檢查攻擊
	if current_state in [State.ATTACK1, State.ATTACK2]:
		apply_damage()

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

func _handle_state(delta):
	match current_state:
		State.IDLE:
			idle_state()
		State.MOVE:
			move_state(delta)
		State.JUMP:
			jump_state()
		State.ATTACK1:
			attack1_state()
		State.ATTACK2:
			attack2_state()
		State.RANGED:
			ranged_state()
		State.HURT:
			hurt_state()
		State.DIE:
			die_state()

func _apply_movement():
	# 應用擊退力
	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 20)
	
	move_and_slide()
#endregion

#region 狀態處理
func idle_state():
	velocity.x = 0
	if animated_sprite:
		animated_sprite.play("idle")
	
	if target_player:
		change_state(State.MOVE)

func move_state(delta):
	# 如果沒有目標玩家，保持閒置
	if not target_player:
		change_state(State.IDLE)
		return
	
	# 計算與玩家的距離和方向
	var distance = global_position.distance_to(target_player.global_position)
	var direction = (target_player.global_position - global_position).normalized()
	
	# 檢查是否可以直接到達玩家位置
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		target_player.global_position,
		1  # 只檢測地形層
	)
	var result = space_state.intersect_ray(query)
	var can_reach_player = not result
	
	# 優先考慮近戰攻擊
	if distance <= MELEE_RANGE and attack_timer.is_stopped():
		# 在近戰範圍內立即攻擊
		if randf() < 0.7:  # 鹿精靈更偏好攻擊1
			change_state(State.ATTACK1)
		else:
			change_state(State.ATTACK2)
		attack_timer.start()
		return
	
	# 檢查跳躍條件
	var current_time = Time.get_ticks_msec() / 1000.0
	var height_difference = target_player.global_position.y - global_position.y
	
	if is_on_floor() and not has_jumped and attack_timer.is_stopped():
		var can_jump = false
		
		# 檢查跳躍是否能夠到達玩家
		var horizontal_distance = abs(target_player.global_position.x - global_position.x)
		var jump_time = abs(jump_force / gravity)
		var jump_distance = move_speed * jump_time
		
		if height_difference < 0 and horizontal_distance < jump_distance:
			can_jump = true
		
		if can_jump and current_time - last_jump_time >= JUMP_COOLDOWN and jump_attempt_count < MAX_JUMP_ATTEMPTS:
			change_state(State.JUMP)
			last_jump_time = current_time
			jump_attempt_count += 1
			attack_timer.start(attack_cooldown)
			return
		elif jump_attempt_count >= MAX_JUMP_ATTEMPTS:
			# 如果跳躍次數過多，改用遠程攻擊
			if attack_timer.is_stopped():
				change_state(State.RANGED)
				jump_attempt_count = 0
				attack_timer.start(attack_cooldown * 1.5)  # 較長的冷卻時間
				return
	
	# 如果玩家在可接觸範圍內或在下方，重置跳躍計數
	if height_difference >= 0 or can_reach_player:
		jump_attempt_count = 0
	
	# 如果追逐時間過長，使用遠程攻擊
	if chase_timer >= CHASE_TIME_LIMIT and attack_timer.is_stopped():
		chase_timer = 0.0
		change_state(State.RANGED)
		attack_timer.start(attack_cooldown)
		return
	
	# 移動邏輯
	velocity.x = direction.x * move_speed
	chase_timer += delta
	
	# 更新動畫和朝向
	if animated_sprite:
		animated_sprite.flip_h = velocity.x < 0
		if abs(velocity.x) < 0.1:  # 使用閾值判斷是否停止
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		else:
			if animated_sprite.animation != "move":
				animated_sprite.play("move")

func jump_state():
	if is_on_floor() and not has_jumped:
		velocity.y = jump_force * 1.2  # 跳得更高
		has_jumped = true
		if animated_sprite:
			animated_sprite.play("jump")
	
	# 在空中時的處理
	if not is_on_floor():
		# 在空中時保持水平移動，但更不規律
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var direction = (player.global_position - global_position).normalized()
			velocity.x = direction.x * move_speed * (1 + randf_range(-0.3, 0.3))  # 添加隨機性
			if animated_sprite:
				animated_sprite.flip_h = velocity.x < 0
	
	# 落地檢測
	if is_on_floor() and velocity.y >= 0 and has_jumped:
		has_jumped = false
		change_state(State.MOVE)

func attack1_state():
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "attack1":
		animated_sprite.play("attack1")
		if attack_area:
			attack_area.monitoring = true
			can_attack = false
			attack_timer.start()
			apply_damage()  # 立即檢查是否造成傷害

func attack2_state():
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "attack2":
		animated_sprite.play("attack2")
		if attack_area:
			attack_area.monitoring = true
			can_attack = false
			attack_timer.start()
			apply_damage()  # 立即檢查是否造成傷害

func ranged_state():
	if not is_performing_ranged:
		is_performing_ranged = true
		velocity = Vector2.ZERO  # 確保停止移動
		animated_sprite.play("attack2")
		animated_sprite.pause()
		animated_sprite.frame = 6
		
		# 先設置初始狀態
		var original_color = COLOR_SETTINGS[spirit_color]
		animated_sprite.modulate = original_color
		
		# 創建更強的發光動畫
		var glow_tween = create_tween()
		var glow_color = original_color.lightened(2.0)  # 大幅增加發光強度
		
		# 在發射前漸漸變亮
		glow_tween.tween_property(animated_sprite, "modulate", glow_color, 0.5)
		await glow_tween.finished
		
		# 發射彈幕
		for i in range(BULLET_COUNT):
			var angle = (2 * PI * i) / BULLET_COUNT
			var direction = Vector2(cos(angle), sin(angle))
			_spawn_bullet(direction)
			velocity = Vector2.ZERO  # 確保在發射過程中無法移動
		
		# 等待指定時間後恢復
		await get_tree().create_timer(ATTACK2_DURATION).timeout
		animated_sprite.play("idle")
		
		# 後搖時漸漸變暗回原本顏色
		var recovery_tween = create_tween()
		recovery_tween.tween_property(animated_sprite, "modulate", original_color, ATTACK2_RECOVERY)
		
		# 等待後搖時間
		await get_tree().create_timer(ATTACK2_RECOVERY).timeout
		is_performing_ranged = false
		attack_timer.start(attack_cooldown)
		change_state(State.MOVE)

func hurt_state():
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "hurt":
		animated_sprite.play("hurt")

func die_state():
	velocity.x = 0
	if not is_dying and animated_sprite:
		is_dying = true
		animated_sprite.play("die")
		defeated.emit()
		
		# 添加擊殺計數
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager:
			game_manager.enemy_killed()
			
		# 使用 WordSystem 處理掉落
		var word_system = get_tree().get_first_node_in_group("word_system")
		if word_system:
			word_system.handle_enemy_drops("DeerSpirit", global_position)
#endregion

#region 視覺效果
func _apply_color_effect():
	if animated_sprite and COLOR_SETTINGS.has(spirit_color):
		animated_sprite.modulate = COLOR_SETTINGS[spirit_color]
#endregion

#region 戰鬥系統
func take_damage(_damage: int) -> void:  # 接收傷害參數但忽略它
	if is_dying:
		return
		
	hits_remaining -= 1  # 固定只減少 1 點生命值
	health_percent = float(hits_remaining) / max_hits
	
	current_alpha = original_alpha * (0.3 + health_percent * 0.7)
	modulate.a = current_alpha
	
	if hits_remaining <= 0:
		change_state(State.DIE)
	else:
		change_state(State.HURT)

func apply_damage():
	if attack_area and attack_area.monitoring:
		var areas = attack_area.get_overlapping_areas()
		for area in areas:
			var body = area.get_parent()
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(damage)
				
				# 攻擊2會將玩家擊飛
				if animated_sprite.animation == "attack2":
					var knockback = Vector2(0, -800)
					if body.has_method("apply_knockback"):
						body.apply_knockback(knockback)

func _spawn_bullet(direction: Vector2):
	var bullet = preload("res://scenes/enemies/DeerBullet.tscn").instantiate()
	bullet.global_position = global_position
	bullet.setup(direction, BULLET_SPEED, BULLET_DAMAGE, spirit_color)
	get_parent().add_child(bullet)
#endregion

#region 信號處理
func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("player"):
		target_player = body
		if current_state == State.IDLE:
			change_state(State.MOVE)

func _on_detection_area_body_exited(body: Node2D):
	if body.is_in_group("player") and body == target_player:
		target_player = null
		change_state(State.IDLE)

func _on_attack_timer_timeout():
	can_attack = true
	# 如果還在近戰範圍內，立即開始新的攻擊
	if target_player and current_state != State.DIE:
		var distance = global_position.distance_to(target_player.global_position)
		if distance <= MELEE_RANGE:
			if randf() < 0.7:
				change_state(State.ATTACK1)
			else:
				change_state(State.ATTACK2)
			attack_timer.start()

func _on_animated_sprite_animation_finished():
	if not animated_sprite:
		return
	
	match animated_sprite.animation:
		"die":
			queue_free()
		"hurt":
			change_state(State.MOVE)
		"attack1", "attack2":
			if attack_area:
				attack_area.monitoring = false
			change_state(State.MOVE)

func _on_animated_sprite_frame_changed():
	if not animated_sprite:
		return
	
	match animated_sprite.animation:
		"attack1", "attack2":
			if animated_sprite.frame == 3:  # 攻擊判定
				apply_damage()

func change_state(new_state: State):
	if is_dying and new_state != State.DIE:
		return
		
	current_state = new_state
#endregion

#region 死亡處理
func die() -> void:
	if is_dying:
		return
		
	is_dying = true
	defeated.emit()
	
	# 生成漢字掉落
	var item_manager = get_node("/root/ItemManager")
	if item_manager:
		item_manager.spawn_word_drop(self)
	
	# 創建消失動畫
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.3)  # 0.3秒內漸出
	await tween.finished
	queue_free()
#endregion

#region 二階段攻擊
func perform_phase_two_attack():
	# 記住當前位置
	var original_position = global_position
	
	# 移動到指定平台
	if has_node("PlatformPosition"):  # 需要在場景中添加這個標記節點
		var platform_pos = $PlatformPosition.global_position
		var tween = create_tween()
		tween.tween_property(self, "global_position", platform_pos, 0.5)
		await tween.finished
		
		# 執行遠程攻擊
		change_state(State.RANGED)
		await get_tree().create_timer(2.0).timeout
		
		# 返回原位
		tween = create_tween()
		tween.tween_property(self, "global_position", original_position, 0.5)
		await tween.finished
	
	phase_two_attack_completed.emit()
#endregion

#region 加血函數
func heal(amount: int) -> void:
	if is_dying:
		return
		
	# 同時增加當前血量和最大血量
	hits_remaining += amount
	max_hits += amount
	
	# 計算血量百分比
	health_percent = float(hits_remaining) / max_hits
	
	# 更新透明度（0.3 到 1.0 之間）
	current_alpha = original_alpha * (0.3 + health_percent * 0.7)
	modulate.a = current_alpha
#endregion

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(4):  # 檢查是否是攻擊區域
		var parent = area.get_parent()
		if parent.is_in_group("player"):
			if parent.is_attacking or parent.is_special_attacking:
				var received_damage = parent.get_attack_damage()  # 改用不同的變量名
				take_damage(received_damage)
#endregion
