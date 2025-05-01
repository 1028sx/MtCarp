extends CharacterBody2D

signal defeated
signal phase_changed(phase: int)
signal health_changed(new_health: int)
signal boss_appeared

#region 導出屬性
@export_group("Movement")
@export var move_speed = 200.0
@export var jump_force = -450.0

@export_group("Combat")
@export var health = 1000
@export var damage = 30
@export var knockback_resistance = 0.95
@export var attack_range = 100.0  # 攻擊範圍
@export var detection_range = 300.0  # 檢測範圍
@export var attack_cooldown = 1.0  # 攻擊冷卻時間

@export_group("Phase Two")
@export var spirit_spawn_interval = 3.0  # 召喚間隔
@export var max_spirits = 8  # 修改：最大精靈數量從 6 改為 8
@export var phase_two_bullet_count = 32  # 二階段彈幕數量
@export var phase_two_bullet_interval = 0.3  # 二階段彈幕間隔
@export var unification_platforms = []  # 歸一時的指定平台節點路徑
#endregion

#region 常量
const SPIRIT_COLORS = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Black", "White"]
const SPIRIT_HEALTH = 3  # 精靈需要被打三次
const BULLET_COUNT = 16  # 彈幕數量
const BULLET_SPEED = 300.0  # 彈幕速度
const BULLET_DAMAGE = 10  # 彈幕傷害
const ATTACK2_DURATION = 2.0  # 彈幕攻擊持續時間
const ATTACK2_RECOVERY = 0.7  # 彈幕攻擊後搖時間
const MELEE_RANGE = 50.0  # 近戰範圍
const RANGED_RANGE = 300.0  # 遠程攻擊範圍
const CHASE_TIME_LIMIT = 3.0  # 追逐時間限制
const SPIRIT_SPAWN_INTERVAL = 5.0  # 召喚精靈間隔
const PHASE_TWO_ATTACK_INTERVAL = 5.0  # 二階段時精靈輪流攻擊的間隔
const UNIFICATION_DURATION = 2.0  # 歸一動作持續時間
const JUMP_COOLDOWN = 2.0  # 跳躍冷卻時間
const MAX_JUMP_ATTEMPTS = 3  # 連續跳躍嘗試次數限制
const HEIGHT_THRESHOLD = -150.0  # 高度差閾值，超過這個值才考慮跳躍
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackArea
@onready var hitbox = $Hitbox
@onready var attack_timer = $AttackTimer
@onready var effect_manager = $EffectManager  # 新增：特效管理器引用
var spirit_scene = preload("res://scenes/enemies/DeerSpirit.tscn")
#endregion

#region 狀態變量
enum State {IDLE, MOVE, JUMP, ATTACK1, ATTACK2, RANGED, DIE}
enum Phase {ONE, TWO}

var current_state = State.IDLE
var current_phase = Phase.ONE
var is_dying = false
var has_jumped = false  
var is_performing_ranged = false  

var active_spirits = []  # 當前存活的精靈
var available_colors = []  # 可用顏色
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var chase_timer = 0.0  # 追逐計時器
var last_hit_time = 0.0  # 上次命中時間
var spirit_spawn_timer = 0.0  # 精靈召喚計時器
var last_attack_time = 0.0  # 上次攻擊時間
var attack_fail_count = 0  # 攻擊失敗次數
var hit_count = 0  # 新增：受擊次數計數器
var last_spirit_spawn_time = 0.0  # 新增：上次召喚精靈的時間
const SPIRIT_SPAWN_COOLDOWN = 10.0  # 新增：召喚冷卻時間
const HIT_COUNT_THRESHOLD = 10  # 新增：觸發召喚的受擊次數閾值
var is_phase_two = false
var current_spirit_index = 0  # 當前輪到哪個精靈攻擊
var phase_two_attack_timer = 0.0
var is_unification_active = false
var last_jump_time = 0.0  # 上次跳躍時間
var jump_attempt_count = 0  # 跳躍嘗試次數
#endregion

#region 初始化
func _ready():
	_initialize_boss()
	_setup_collisions()
	_setup_timer()
	_setup_platforms()
	
	# 確保信號正確連接
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
		animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	if attack_area:
		attack_area.area_entered.connect(_on_attack_area_area_entered)
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	# 初始化可用顏色
	available_colors = SPIRIT_COLORS.duplicate()
	
	await get_tree().process_frame
	boss_appeared.emit()

func _initialize_boss():
	add_to_group("boss")
	if animated_sprite:
		animated_sprite.play("idle")

func _setup_collisions():
	# Boss本體的碰撞層設置
	set_collision_layer_value(1, false)  # 不與地形碰撞
	set_collision_layer_value(2, false)  # 不與玩家碰撞
	set_collision_layer_value(3, false)  # 不作為受傷區域
	set_collision_layer_value(4, true)   # 設為攻擊區域，可以傷害玩家
	set_collision_layer_value(5, true)   # 與其他敵人碰撞
	
	# Boss的碰撞檢測
	set_collision_mask_value(1, true)    # 檢測地形
	set_collision_mask_value(2, false)   # 不檢測玩家
	set_collision_mask_value(3, true)    # 檢測受傷區域
	set_collision_mask_value(4, false)   # 不檢測攻擊區域
	set_collision_mask_value(5, false)   # 不檢測其他敵人
	
	# 設置Boss的攻擊區域（用於傷害玩家）
	if attack_area:
		attack_area.collision_layer = 0
		attack_area.set_collision_layer_value(4, true)  # 設為攻擊區域
		attack_area.collision_mask = 0
		attack_area.set_collision_mask_value(3, true)   # 檢測受傷區域
		attack_area.monitoring = true
		attack_area.monitorable = true
	
	# 設置Boss的受傷區域（用於接收玩家攻擊）
	if hitbox:
		hitbox.collision_layer = 0
		hitbox.set_collision_layer_value(3, true)   # 設為受傷區域
		hitbox.collision_mask = 0
		hitbox.set_collision_mask_value(4, true)    # 檢測攻擊區域
		hitbox.monitoring = true
		hitbox.monitorable = true

# 新增：設置計時器
func _setup_timer():
	attack_timer = Timer.new()
	attack_timer.one_shot = true
	attack_timer.wait_time = attack_cooldown
	add_child(attack_timer)

# 添加平台設置函數
func _setup_platforms():
	# 清空並重新設置平台路徑
	unification_platforms.clear()
	
	# 添加主平台（給 Boss 自己用）
	unification_platforms.append(NodePath("../OneWayPlatform"))
	
	# 添加給精靈用的平台
	for i in range(8):
		var platform_path = "../OneWayPlatform" + str(i + 1)
		unification_platforms.append(NodePath(platform_path))
#endregion

#region 物理處理
func _physics_process(delta):
	if is_dying:
		return
		
	_apply_gravity(delta)
	_handle_state(delta)
	move_and_slide()
	_check_phase_transition()
	
	# 檢查是否需要召喚精靈（基於時間）
	if Time.get_ticks_msec() / 1000.0 - last_spirit_spawn_time >= SPIRIT_SPAWN_COOLDOWN:
		last_spirit_spawn_time = Time.get_ticks_msec() / 1000.0
		spawn_spirit()
	
	# 二階段時的精靈輪流攻擊邏輯
	if is_phase_two and not is_unification_active:
		phase_two_attack_timer += delta
		if phase_two_attack_timer >= PHASE_TWO_ATTACK_INTERVAL:
			phase_two_attack_timer = 0
			_handle_spirit_rotation()

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

func _handle_state(delta):
	if is_dying:
		return

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
		State.DIE:
			die_state()

func _check_phase_transition():
	if current_phase == Phase.ONE and health <= 500:  # 直接使用固定值
		enter_phase_two()
#endregion

#region 狀態處理
func idle_state():
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "idle":
		animated_sprite.play("idle")
	
	# 檢查玩家位置，決定是否進入其他狀態
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance < 300:  # 如果玩靠近
			if randf() < 0.3:  # 30%機率跳躍攻擊
				change_state(State.JUMP)
			else:  # 70%機率移動
				change_state(State.MOVE)

func move_state(delta):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		change_state(State.IDLE)
		return
	
	# 計算與玩家的距離和方向
	var distance = global_position.distance_to(player.global_position)
	var direction = (player.global_position - global_position).normalized()
	
	# 檢查是否可以直接到達玩家位置
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position,
		1  # 只檢測地形層
	)
	var result = space_state.intersect_ray(query)
	var can_reach_player = not result
	
	# 優先考慮近戰攻擊
	if distance <= MELEE_RANGE and attack_timer.is_stopped():
		if randf() < 0.5:
			change_state(State.ATTACK1)
		else:
			change_state(State.ATTACK2)
		attack_timer.start(attack_cooldown)
		return
	
	# 檢查跳躍條件
	var current_time = Time.get_ticks_msec() / 1000.0
	var height_difference = player.global_position.y - global_position.y
	
	# 修改：跳躍判斷邏輯
	if is_on_floor() and not has_jumped and attack_timer.is_stopped():
		var can_jump = false
		
		# 檢查跳躍是否能夠到達玩家
		var horizontal_distance = abs(player.global_position.x - global_position.x)
		var jump_time = abs(jump_force / gravity)  # 估算跳躍時間
		var jump_distance = move_speed * jump_time  # 估算跳躍過程中能移動的距離
		
		# 如果玩家在上方且水平距離在可達範圍內
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
				attack_timer.start(attack_cooldown * 2)
				return
	
	# 如果玩家在可接觸範圍內或在下方，重置跳躍計數
	if height_difference >= 0 or can_reach_player:
		jump_attempt_count = 0
	
	# 如果無法跳躍到達且追逐時間過長，嘗試其他攻擊手段
	if chase_timer >= CHASE_TIME_LIMIT and attack_timer.is_stopped():
			chase_timer = 0.0
			if randf() < 0.5:  # 50%機率使用遠程攻擊
				change_state(State.RANGED)
				attack_timer.start(attack_cooldown * 0.5)
			else:  # 50%機率召喚精靈
				spawn_spirit()
			return
	
	# 直向玩家移動
	velocity.x = direction.x * move_speed
	chase_timer += delta
	
	# 更新動畫和朝向
	if animated_sprite:
		animated_sprite.flip_h = velocity.x < 0
		
		# 修改：動畫邏輯
		# 只有在完全停止時才播放閒置動畫
		if abs(velocity.x) < 0.1:  # 使用一個小的閾值來判斷是否停止
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		else:  # 只要在移動就播放移動動畫，不管是否在攻擊冷卻中
			if animated_sprite.animation != "move":
				animated_sprite.play("move")

# 新增：遠程攻擊態
func ranged_state():
	velocity.x = 0
	if not is_performing_ranged:
		is_performing_ranged = true
		perform_ranged_attack()

func attack1_state():
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "attack1":
		animated_sprite.play("attack1")
		if attack_area:
			attack_area.monitoring = true  # 開啟攻擊監測
			apply_attack_damage()  # 立即檢查是否有擊中玩家

func attack2_state():
	velocity.x = 0
	if animated_sprite and animated_sprite.animation != "attack2":
		animated_sprite.play("attack2")
		if attack_area:
			attack_area.monitoring = true
			# 檢查是否有玩家在攻擊範圍內
			var areas = attack_area.get_overlapping_areas()
			for area in areas:
				var body = area.get_parent()
				if body.is_in_group("player") and body.has_method("take_damage"):
					body.take_damage(damage)
					# 攻擊二一定會造成擊退
					if body.has_method("apply_knockback"):
						var direction = (body.global_position - global_position).normalized()
						var knockback = Vector2(direction.x * 600, -400)
						body.apply_knockback(knockback)

func die_state():
	velocity.x = 0
	if not is_dying and animated_sprite:
		is_dying = true
		animated_sprite.play("die")
		defeated.emit()

# 修改攻擊判定函數
func apply_attack_damage():
	if not attack_area:
		return
	
	var overlapping_areas = attack_area.get_overlapping_areas()
	for area in overlapping_areas:
		if area.get_collision_layer_value(3):  # 檢查是否是玩家的受傷區域
			var body = area.get_parent()
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(damage)
				
				# 只在攻擊2時添加擊退效果
				if current_state == State.ATTACK2 and body.has_method("apply_knockback"):
					var direction = (body.global_position - global_position).normalized()
					var knockback = Vector2(direction.x * 600, -400)
					body.apply_knockback(knockback)

# 修改動畫幀事件處理
func _on_animated_sprite_frame_changed():
	if not animated_sprite:
		return
	
	match animated_sprite.animation:
		"attack1":
			if animated_sprite.frame == 3:  # 攻擊判定幀
				if attack_area:
					attack_area.monitoring = true
				apply_attack_damage()
			elif animated_sprite.frame == 5:  # 攻擊結束幀
				if attack_area:
					attack_area.monitoring = false
		"attack2":
			if animated_sprite.frame == 3:  # 攻擊判定幀
				if attack_area:
					attack_area.monitoring = true
					# 檢查是否有玩家在攻擊範圍內
					var areas = attack_area.get_overlapping_areas()
					for area in areas:
						var body = area.get_parent()
						if body.is_in_group("player") and body.has_method("take_damage"):
							body.take_damage(damage)
							# 攻擊二一定會造成擊退
							if body.has_method("apply_knockback"):
								var direction = (body.global_position - global_position).normalized()
								var knockback = Vector2(direction.x * 600, -400)
								body.apply_knockback(knockback)
			elif animated_sprite.frame == 5:  # 攻擊結束幀
				if attack_area:
					attack_area.monitoring = false

# 修改動畫結束處理
func _on_animated_sprite_animation_finished():
	if not animated_sprite:
		return
	
	match animated_sprite.animation:
		"attack1", "attack2":
			if attack_area:
				attack_area.monitoring = false  # 關閉攻擊監測
			change_state(State.MOVE)
			attack_timer.start(attack_cooldown)
		"die":
			queue_free()

# 新增：遠程攻擊函數
func perform_ranged_attack():
	# 播放攻擊2動畫
	animated_sprite.play("attack2")
	
	# 播放施法特效
	if effect_manager:
		effect_manager.play_cast_effect()
	
	# 在第6幀時暫停並發射彈幕
	await animated_sprite.frame_changed
	while animated_sprite.frame < 6:
		await animated_sprite.frame_changed
	
	# 到達第6幀時暫停動畫並發射彈幕
	if animated_sprite.frame == 6:
		animated_sprite.pause()
		
		# 播放彈幕特效
		if effect_manager:
			effect_manager.play_bullet_wave_effect()
		
		# 發射彈幕
		for i in range(BULLET_COUNT):
			var angle = (2 * PI * i) / BULLET_COUNT
			var direction = Vector2(cos(angle), sin(angle))
			_spawn_bullet(direction)
		
		# 等待指定時間後恢復動畫
		await get_tree().create_timer(ATTACK2_DURATION).timeout
		animated_sprite.play()

func _spawn_bullet(direction: Vector2):
	var bullet = preload("res://scenes/enemies/DeerBullet.tscn").instantiate()
	bullet.global_position = global_position
	bullet.setup(direction, BULLET_SPEED, BULLET_DAMAGE)
	get_parent().add_child(bullet)

# 修改狀態切換函數
func change_state(new_state: State) -> void:
	if is_dying and new_state != State.DIE:
		return
	
	# 清理前一個狀態
	match current_state:
		State.ATTACK1, State.ATTACK2:
			if attack_area:
				attack_area.monitoring = false
		
		State.RANGED:
			is_performing_ranged = false
	
	current_state = new_state
	
	# 設置新狀態
	match new_state:
		State.IDLE:
			velocity.x = 0
			if animated_sprite:
				animated_sprite.play("idle")
		
		State.MOVE:
			if animated_sprite:
				animated_sprite.play("move")
		
		State.ATTACK1:
			velocity.x = 0
			if animated_sprite:
				animated_sprite.play("attack1")
		
		State.ATTACK2:
			velocity.x = 0
			if animated_sprite:
				animated_sprite.play("attack2")
		
		State.RANGED:
			velocity.x = 0
			ranged_state()
		
		State.DIE:
			velocity.x = 0
			if not is_dying and animated_sprite:
				is_dying = true
				animated_sprite.play("die")
				defeated.emit()
#endregion

#region 第二階段
func enter_phase_two():
	if is_phase_two:
		return
		
	is_phase_two = true
	current_phase = Phase.TWO
	phase_changed.emit(Phase.TWO)
	
	# 先回到初始平台
	var main_platform = get_node("../OneWayPlatform")  # 獲取主平台
	if main_platform:
		# 暫時無敵並禁止移動
		set_collision_mask_value(4, false)  # 關閉攻擊檢測
		set_physics_process(false)  # 禁止物理處理（包括移動）
		velocity = Vector2.ZERO  # 確保停止所有移動
		
		# 播放護盾特效
		if effect_manager:
			effect_manager.play_shield_effect()
		
		# 移動到平台上方
		var target_pos = main_platform.global_position + Vector2(0, -100)  # 在平台上方100像素
		var tween = create_tween()
		tween.tween_property(self, "global_position", target_pos, 1.0)
		await tween.finished
		
		# 執行歸一動作
		await perform_unification()
		
		# 停止護盾特效
		if effect_manager:
			effect_manager.stop_shield_effect()
		
		# 恢復可被攻擊和移動
		set_collision_mask_value(4, true)
		set_physics_process(true)  # 恢復物理處理

func perform_unification():
	is_unification_active = true
	
	# 獲取所有平台位置
	var platforms = []
	for path in unification_platforms:
		var platform = get_node(path)
		if platform:
			platforms.append(platform)
	
	# 將所有精靈移動到平台位置
	for i in range(active_spirits.size()):
		var spirit = active_spirits[i]
		if spirit and i < platforms.size():
			var target_pos = platforms[i].global_position
			
			# 創建移動動畫
			var tween = create_tween()
			tween.tween_property(spirit, "global_position", target_pos, 1.0)
	
	# 等待所有精靈就位
	await get_tree().create_timer(1.0).timeout
	
	# 同時發射三波遠程攻擊
	for i in range(3):
		_perform_phase_two_ranged_attack()
		await get_tree().create_timer(1.0).timeout
	
	is_unification_active = false

func _perform_phase_two_ranged_attack():
	# 第一波（奇數）
	for i in range(phase_two_bullet_count):
		if i % 2 == 0:  # 只發射奇數位置的子彈
			var angle = (2 * PI * i) / phase_two_bullet_count
			var direction = Vector2(cos(angle), sin(angle))
			_spawn_bullet(direction)
	
	# 等待間隔
	await get_tree().create_timer(phase_two_bullet_interval).timeout
	
	# 第二波（數）
	for i in range(phase_two_bullet_count):
		if i % 2 == 1:  # 只發射偶數位置的子彈
			var angle = (2 * PI * i) / phase_two_bullet_count
			var direction = Vector2(cos(angle), sin(angle))
			_spawn_bullet(direction)

func spawn_spirit():
	if effect_manager:
		effect_manager.play_summon_effect()
		await effect_manager.effect_finished
	
	if active_spirits.size() >= max_spirits or available_colors.is_empty():
		return
		
	# 更新最後召喚時間
	last_spirit_spawn_time = Time.get_ticks_msec() / 1000.0
	
	# 隨機選擇一個顏色
	var color_index = randi() % available_colors.size()
	var spirit_color = available_colors[color_index]
	available_colors.remove_at(color_index)
	
	# 獲取對應的平台從1到8）
	var platform_number = active_spirits.size() + 1  # 第一個精靈用1號平台，第二個用2號，以此類推
	var spawn_platform = get_node("../OneWayPlatform" + str(platform_number))
	if not spawn_platform:
		return
	
	var spirit = spirit_scene.instantiate()
	spirit.setup(spirit_color, SPIRIT_HEALTH)
	# 設置精靈在平台上方
	spirit.position = spawn_platform.global_position + Vector2(0, -50)  # 在平台上方50像素處生成
	
	# 設置精靈的二階段位置平台
	var platform_pos = Node2D.new()
	platform_pos.name = "PlatformPosition"
	platform_pos.global_position = spawn_platform.global_position + Vector2(0, -50)
	spirit.add_child(platform_pos)
	
	# 添加場景
	get_parent().call_deferred("add_child", spirit)
	active_spirits.append(spirit)
	
	# 連接信號
	spirit.defeated.connect(_on_spirit_defeated.bind(spirit, spirit_color))

func _on_spirit_defeated(spirit, color):
	active_spirits.erase(spirit)
	available_colors.append(color)  # 將顏色放回可用池

func _handle_spirit_rotation():
	if active_spirits.is_empty():
		return
		
	# 確保索引在有效範圍內
	current_spirit_index = clamp(current_spirit_index, 0, active_spirits.size() - 1)
	
	# 獲取當前輪到的精靈
	var spirit = active_spirits[current_spirit_index]
	if is_instance_valid(spirit):
		# 讓精靈執行二階段攻擊
		spirit.ranged_state()  # 改用已存在的 ranged_state 函數
		# 等待攻擊完成
		await get_tree().create_timer(2.0).timeout  # 給予足夠時間完成攻擊
	
	# 更新索引，確保不超出範圍
	current_spirit_index = (current_spirit_index + 1) % max(1, active_spirits.size())
#endregion

#region 信號處理
func take_damage(amount: int):
	if is_dying:
		return
		
	health -= amount
	health_changed.emit(health)
	
	hit_count += 1
	
	if hit_count >= HIT_COUNT_THRESHOLD:
		hit_count = 0
		spawn_spirit()
	
	if health <= 0:
		die()

func die():
	if is_dying:
		return
		
	is_dying = true
	current_state = State.DIE
	
	# 使用 call_deferred 來延遲停止物理處理
	call_deferred("set_physics_process", false)
	velocity = Vector2.ZERO
	
	# 清理所有精靈
	for spirit in active_spirits:
		if is_instance_valid(spirit):
			spirit.call_deferred("queue_free")
	active_spirits.clear()
	
	# 播放死亡動畫
	if animated_sprite:
		animated_sprite.play("die")
	
	# 添加擊殺計數
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.enemy_killed()
	
	# 發送死亡信號
	defeated.emit()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.get_collision_layer_value(4):  # 檢查是否是攻擊區域
		var parent = area.get_parent()
		if parent.is_in_group("player"):
			var damage_amount = 0
			
			if parent.is_attacking:
				damage_amount = parent.get_attack_damage()
			elif parent.is_special_attacking:
				damage_amount = parent.SPECIAL_ATTACK_DAMAGE
				
			if damage_amount > 0:
				take_damage(damage_amount)

func jump_state():
	if is_on_floor() and not has_jumped:  # 有在地面且還沒跳過時才跳躍
		velocity.y = jump_force
		has_jumped = true  # 標記已經跳躍
		if animated_sprite:
			animated_sprite.play("jump")
	
	# 在空中時的處理
	if not is_on_floor():
		# 在空中時保持水平移動
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var direction = (player.global_position - global_position).normalized()
			velocity.x = direction.x * move_speed
			if animated_sprite:
				animated_sprite.flip_h = velocity.x < 0
	
	# 落地檢測
	if is_on_floor() and velocity.y >= 0 and has_jumped:  # 確保已經跳過且已落地
		has_jumped = false  # 重置跳躍標記
		change_state(State.MOVE)

# 修改：檢查與玩家的碰撞，只造成傷害而不擊飛
func _check_player_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is CharacterBody2D and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(damage)  # 只造成傷害，不添加擊退效果

func _on_attack_area_area_entered(area: Area2D):
	var body = area.get_parent()
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		# 在攻擊二狀態時添加擊退
		if current_state == State.ATTACK2 and body.has_method("apply_knockback"):
			var direction = (body.global_position - global_position).normalized()
			var knockback = Vector2(direction.x * 600, -400)
			body.apply_knockback(knockback)

func _on_attack_area_body_entered(_body: Node2D):
	pass
#endregion 
