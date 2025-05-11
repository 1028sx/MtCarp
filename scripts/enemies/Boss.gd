extends CharacterBody2D

class_name Boss

# Boss 相關信號
signal phase_changed(phase: int)
signal boss_defeated
signal attack_started(attack_name: String)
signal health_changed(current: float, max_health: float)

#region 導出屬性
@export_group("基本屬性")
@export var boss_name: String = "Boss"
@export var max_health: float = 1000.0
@export var defense: float = 10.0
@export var total_phases: int = 3
@export var knockback_resistance: float = 0.9

@export_group("移動與行為")
@export var move_speed: float = 120.0
@export var acceleration: float = 500.0
@export var deceleration: float = 800.0
@export var phase_transition_time: float = 2.0

@export_group("攻擊屬性")
@export var attack_cooldown: float = 2.0
@export var attack_damage: float = 15.0
@export var special_attack_cooldown: float = 8.0 
@export var special_attack_damage: float = 30.0
@export var attack_range: float = 150.0

@export_group("掉落物")
@export var guaranteed_drops: Array[String] = []
@export var random_drops: Array[String] = []
@export var drop_chance: float = 0.5
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var attack_area = $AttackArea
@onready var detection_area = $DetectionArea
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var special_attack_cooldown_timer = $SpecialAttackCooldownTimer
@onready var health_bar = $BossHealthBar
@onready var effect_manager = $EffectManager
@onready var audio_player = $AudioPlayer
@onready var state_label = $StateLabel # 用於調試
#endregion

#region 狀態變量
enum BossState {IDLE, APPEAR, PHASE_TRANSITION, MOVE, ATTACK, SPECIAL_ATTACK, STUNNED, HURT, DEFEATED}

var current_state: int = BossState.IDLE
var previous_state: int = BossState.IDLE
var current_phase: int = 1
var current_health: float
var current_attack: String = ""
var attack_patterns: Dictionary = {}
var phase_attacks: Dictionary = {}
var vulnerable: bool = true
var target_player: CharacterBody2D = null

# 移動相關
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var move_direction: Vector2 = Vector2.ZERO
var target_position: Vector2
var knockback_velocity: Vector2 = Vector2.ZERO

# 攻擊模式
var available_attacks: Array = []
var current_attack_index: int = 0
var attack_combo_count: int = 0
var max_combo_attacks: int = 3

# 相位轉換
var transition_timer: float = 0.0
var can_be_interrupted: bool = true

# 調試用
var debug_mode: bool = false
#endregion

#region 生命週期函數
func _ready() -> void:
	_initialize_boss()
	_setup_collisions()
	_connect_signals()
	_setup_attack_patterns()
	
	if debug_mode and state_label:
		state_label.visible = true
	else:
		state_label.visible = false

func _physics_process(delta: float) -> void:
	if current_state == BossState.DEFEATED:
		return
		
	# 應用重力
	if not is_on_floor() and current_state != BossState.APPEAR:
		velocity.y += gravity * delta
	
	# 處理擊退力
	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 2000 * knockback_resistance)
	else:
		# 根據當前狀態執行相應的邏輯
		match current_state:
			BossState.IDLE:
				_process_idle_state(delta)
			BossState.APPEAR:
				_process_appear_state(delta)
			BossState.PHASE_TRANSITION:
				_process_phase_transition(delta)
			BossState.MOVE:
				_process_move_state(delta)
			BossState.ATTACK:
				_process_attack_state(delta)
			BossState.SPECIAL_ATTACK:
				_process_special_attack_state(delta)
			BossState.STUNNED:
				_process_stunned_state(delta)
			BossState.HURT:
				_process_hurt_state(delta)
	
	# 更新動畫
	_update_animation()
	
	# 更新調試標籤
	if debug_mode and state_label:
		state_label.text = BossState.keys()[current_state] + " - Phase: " + str(current_phase)
	
	# 執行移動
	move_and_slide()
#endregion

#region 初始化系統
func _initialize_boss() -> void:
	add_to_group("boss")
	current_health = max_health
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = max_health
		health_bar.visible = true
	
	# 確保 UI 系統能收到初始信號
	call_deferred("emit_signal", "health_changed", current_health, max_health)
	call_deferred("emit_signal", "phase_changed", current_phase)

func _setup_collisions() -> void:
	# 設置 Boss 本體的碰撞層
	set_collision_layer_value(1, false)  # 不與地形碰撞
	set_collision_layer_value(2, false)  # 不與玩家碰撞
	set_collision_layer_value(3, false)  # 不作為受傷區域
	set_collision_layer_value(4, false)  # 不作為攻擊區域
	set_collision_layer_value(5, true)   # 設為敵人專用層
	
	# 設置 Boss 的碰撞檢測
	set_collision_mask_value(1, true)    # 檢測地形
	set_collision_mask_value(2, false)   # 不檢測玩家
	set_collision_mask_value(3, false)   # 不檢測受傷區域
	set_collision_mask_value(4, false)   # 不檢測攻擊區域
	set_collision_mask_value(5, false)   # 不檢測其他敵人
	
	# 設置 Boss 的受傷區域
	if hitbox:
		hitbox.set_collision_layer_value(3, true)   # 設為受傷區域
		hitbox.set_collision_mask_value(4, true)    # 檢測攻擊區域
	
	# 設置 Boss 的檢測區域
	if detection_area:
		detection_area.collision_layer = 0  # 不設置任何碰撞層
		detection_area.set_collision_mask_value(2, true)  # 只檢測玩家層
	
	# 設置 Boss 的攻擊區域
	if attack_area:
		attack_area.collision_layer = 0  # 不設置任何碰撞層
		attack_area.set_collision_mask_value(2, true)  # 檢測玩家層
		attack_area.set_collision_mask_value(1, true)  # 檢測地形層
		attack_area.monitoring = false  # 默認不啟用監視

func _connect_signals() -> void:
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
	
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if attack_area:
		if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
			attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	if hitbox:
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)

func _setup_attack_patterns() -> void:
	# 這個函數需要被子類覆寫，定義 Boss 特定的攻擊模式
	pass
#endregion

#region 狀態處理函數
func _process_idle_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)
	
	if is_instance_valid(target_player):
		_change_state(BossState.MOVE)

func _process_appear_state(_delta: float) -> void:
	# Boss 登場動畫，由子類實現特定效果
	pass

func _process_phase_transition(_delta: float) -> void:
	velocity.x = 0
	transition_timer -= _delta
	
	if transition_timer <= 0:
		# 相位轉換結束，進入移動狀態
		_change_state(BossState.MOVE)
		vulnerable = true

func _process_move_state(_delta: float) -> void:
	if not is_instance_valid(target_player):
		_change_state(BossState.IDLE)
		return
	
	# 計算到玩家的距離和方向
	var distance_to_player = global_position.distance_to(target_player.global_position)
	var direction_to_player = (target_player.global_position - global_position).normalized()
	
	# 根據階段和距離決定行為
	if distance_to_player <= attack_range:
		# 在攻擊範圍內
		if attack_cooldown_timer.is_stopped():
			_select_attack()
		else:
			# 調整位置，保持與玩家的距離
			velocity.x = move_toward(velocity.x, direction_to_player.x * move_speed * 0.5, acceleration * _delta)
	else:
		# 向玩家移動
		velocity.x = move_toward(velocity.x, direction_to_player.x * move_speed, acceleration * _delta)
	
	# 更新朝向
	if velocity.x != 0:
		if animated_sprite:
			animated_sprite.flip_h = velocity.x < 0

func _process_attack_state(_delta: float) -> void:
	# 基本攻擊狀態，動畫和具體攻擊邏輯由子類實現
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)

func _process_special_attack_state(_delta: float) -> void:
	# 特殊攻擊狀態，動畫和具體攻擊邏輯由子類實現
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)

func _process_stunned_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)

func _process_hurt_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)
#endregion

#region 攻擊系統
func _select_attack() -> void:
	if available_attacks.is_empty():
		return
	
	# 根據當前階段選擇可用的攻擊
	var phase_attack_list = phase_attacks.get(current_phase, available_attacks)
	
	if phase_attack_list.is_empty():
		return
	
	# 選擇攻擊
	var attack_name = phase_attack_list[randi() % phase_attack_list.size()]
	current_attack = attack_name
	
	# 根據攻擊名稱確定狀態
	if attack_name.begins_with("special_"):
		_change_state(BossState.SPECIAL_ATTACK)
		special_attack_cooldown_timer.start(special_attack_cooldown)
	else:
		_change_state(BossState.ATTACK)
		attack_cooldown_timer.start(attack_cooldown)
	
	# 發出攻擊開始信號
	attack_started.emit(attack_name)

func _apply_attack_damage(body: Node2D, damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage_amount, self)
	
	if knockback_force != Vector2.ZERO and body.has_method("apply_knockback"):
		body.apply_knockback(knockback_force)
#endregion

#region 受傷系統
func take_damage(damage_amount: float, attacker: Node = null) -> void:
	if current_state == BossState.DEFEATED or current_state == BossState.APPEAR or not vulnerable:
		return
	
	# 計算實際傷害
	var actual_damage = max(1, damage_amount - defense)
	current_health -= actual_damage
	
	# 更新血條
	if health_bar:
		health_bar.value = current_health
	
	# 發出血量變化信號
	print("[Boss] 發送 health_changed 信號：", current_health, "/", max_health)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		_handle_defeat()
	elif current_health <= max_health / total_phases * (total_phases - current_phase):
		# 進入下一階段
		_enter_next_phase()
	elif can_be_interrupted:
		# 普通受傷
		_change_state(BossState.HURT)
		
		# 如果有攻擊者，計算擊退方向
		if attacker != null and attacker is Node2D:
			var knockback_dir = (global_position - attacker.global_position).normalized()
			knockback_velocity = knockback_dir * 300 * (1.0 - knockback_resistance)

func _handle_defeat() -> void:
	current_health = 0
	current_state = BossState.DEFEATED
	print("[Boss] 發送 boss_defeated 信號")
	boss_defeated.emit()
	
	if animated_sprite:
		animated_sprite.play("defeat")
	
	# 停用碰撞和區域
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	
	if attack_area:
		attack_area.set_deferred("monitoring", false)
	
	# 在動畫結束後會觸發 _on_animation_finished，然後調用 _on_defeated

func _enter_next_phase() -> void:
	current_phase += 1
	if current_phase > total_phases:
		current_phase = total_phases
	
	print("[Boss] 發送 phase_changed 信號：階段", current_phase)
	phase_changed.emit(current_phase)
	
	# 進入相位轉換狀態
	_change_state(BossState.PHASE_TRANSITION)
	transition_timer = phase_transition_time
	vulnerable = false

func _on_defeated() -> void:
	# 掉落物品
	_drop_items()
	
	# 延遲一段時間後移除 Boss
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func(): queue_free())
	
	# 可能需要觸發其他事件，如解鎖門、觸發對話等
	# 這部分通常由場景或關卡管理器處理

func _drop_items() -> void:
	# 掉落保證物品
	for item_name in guaranteed_drops:
		_spawn_item(item_name)
	
	# 掉落隨機物品
	for item_name in random_drops:
		if randf() <= drop_chance:
			_spawn_item(item_name)

func _spawn_item(item_name: String) -> void:
	# 這個函數需要由特定的掉落物系統實現
	# 通常會載入物品場景並生成實例
	pass
#endregion

#region 動畫系統
func _update_animation() -> void:
	if not animated_sprite:
		return
	
	match current_state:
		BossState.IDLE:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		BossState.APPEAR:
			if animated_sprite.animation != "appear":
				animated_sprite.play("appear")
		BossState.PHASE_TRANSITION:
			if animated_sprite.animation != "phase_transition":
				animated_sprite.play("phase_transition")
		BossState.MOVE:
			if abs(velocity.x) > 10:
				if animated_sprite.animation != "move":
					animated_sprite.play("move")
			else:
				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")
		BossState.ATTACK:
			if animated_sprite.animation != current_attack:
				animated_sprite.play(current_attack)
		BossState.SPECIAL_ATTACK:
			if animated_sprite.animation != current_attack:
				animated_sprite.play(current_attack)
		BossState.STUNNED:
			if animated_sprite.animation != "stunned":
				animated_sprite.play("stunned")
		BossState.HURT:
			if animated_sprite.animation != "hurt":
				animated_sprite.play("hurt")
		BossState.DEFEATED:
			if animated_sprite.animation != "defeat":
				animated_sprite.play("defeat")

func _change_state(new_state: int) -> void:
	previous_state = current_state
	current_state = new_state
	
	match new_state:
		BossState.ATTACK, BossState.SPECIAL_ATTACK:
			can_be_interrupted = false
		BossState.HURT, BossState.STUNNED:
			can_be_interrupted = true
		BossState.MOVE, BossState.IDLE:
			can_be_interrupted = true
		BossState.PHASE_TRANSITION:
			can_be_interrupted = false
#endregion

#region 信號回調
func _on_animation_finished() -> void:
	match current_state:
		BossState.APPEAR:
			_change_state(BossState.IDLE)
		BossState.ATTACK, BossState.SPECIAL_ATTACK:
			attack_area.monitoring = false
			_change_state(BossState.MOVE)
		BossState.HURT:
			_change_state(BossState.MOVE)
		BossState.STUNNED:
			_change_state(BossState.MOVE)
		BossState.DEFEATED:
			_on_defeated()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not target_player:
		target_player = body
		if current_state == BossState.IDLE:
			_change_state(BossState.APPEAR)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var damage = attack_damage
		if current_state == BossState.SPECIAL_ATTACK:
			damage = special_attack_damage
		
		# 計算擊退方向
		var knockback_dir = (body.global_position - global_position).normalized()
		var knockback_force = knockback_dir * 300
		
		_apply_attack_damage(body, damage, knockback_force)

func _on_hitbox_area_entered(area: Area2D) -> void:
	# Boss 被攻擊的邏輯在 take_damage 函數中處理
	pass
#endregion 