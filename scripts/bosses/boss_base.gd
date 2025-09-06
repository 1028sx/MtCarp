extends CharacterBody2D

class_name BossBase

# 直接使用 PlayerSystem 單例

#region Boss 相關信號
signal phase_changed(phase: int)
signal boss_defeated
signal attack_started(attack_name: String)
signal health_changed(current: float, max_health: float)
signal interrupted(attack_name: String)
#endregion

#region 導出屬性
@export_group("基本屬性")
@export var boss_name: String = "Boss"
@export var max_health: float = 1000.0
@export var defense: float = 10.0
@export var total_phases: int = 3
@export var enable_retaliation_system: bool = true
@export var retaliation_cooldown_reduction: float = 1.0

@export_group("移動與行為")
@export var move_speed: float = 120.0
@export var acceleration: float = 500.0
@export var deceleration: float = 800.0
@export var phase_transition_time: float = 2.0

@export_group("攻擊屬性")
@export var attack_cooldown: float = 2.0
@export var attack_damage: float = 15.0
@export var touch_damage: float = 10.0
@export var touch_damage_cooldown: float = 1.0
@export var special_attack_cooldown: float = 8.0 
@export var special_attack_damage: float = 30.0
@export var attack_range: float = 150.0

@export_group("掉落物")
@export var guaranteed_drops: Array[String] = []
@export var random_drops: Array[String] = []
@export var drop_chance: float = 0.5

@export_group("中斷設定 (AnimatedSprite2D)")
@export var interruptible_frames: Dictionary = {
	# 範例: "attack_animation_name": Vector2i(start_frame, end_frame)
}
#endregion

#region 節點引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var attack_area = $AttackArea
@onready var detection_area = $DetectionArea
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var special_attack_cooldown_timer = $"SpecialAttackCooldownTimer" if has_node("SpecialAttackCooldownTimer") else null
@onready var health_bar = $"BossHealthBar" if has_node("BossHealthBar") else null
@onready var effect_manager = $EffectManager if has_node("EffectManager") else null
@onready var state_label = $StateLabel if has_node("StateLabel") else null
@onready var touch_damage_area: Area2D = $TouchDamageArea
@onready var touch_damage_cooldown_timer: Timer
#endregion

#region 狀態變量
enum BossState {IDLE, APPEAR, PHASE_TRANSITION, MOVE, ATTACK, SPECIAL_ATTACK, STUNNED, HURT, DEFEATED, MAX_BOSS_STATES}

var current_state: int = BossState.IDLE
var previous_state: int = BossState.IDLE
var current_phase: int = 1
var current_health: float
var current_attack: String = ""
var attack_patterns: Dictionary = {}
var phase_attacks: Dictionary = {}
var vulnerable: bool = true
var target_player: CharacterBody2D = null
var active: bool = true
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var move_direction: Vector2 = Vector2.ZERO
var target_position: Vector2
var available_attacks: Array = []
var current_attack_index: int = 0
var attack_combo_count: int = 0
var max_combo_attacks: int = 3
var transition_timer: float = 0.0
var can_be_interrupted: bool = true
var debug_mode: bool = false
var is_invincible: bool = false

var animation_name_map: Dictionary = {
	"DEFEATED": "defeat"
}
#endregion

#region 生命週期函數
func _ready() -> void:
	_initialize_boss()
	_setup_collisions()
	_connect_signals()
	_setup_attack_patterns()

	# --- 初始化接觸傷害冷卻計時器 ---
	if has_node("TouchDamageCooldownTimer"):
		touch_damage_cooldown_timer = get_node("TouchDamageCooldownTimer")
	else:
		touch_damage_cooldown_timer = Timer.new()
		touch_damage_cooldown_timer.name = "TouchDamageCooldownTimer"
		add_child(touch_damage_cooldown_timer)
	
	touch_damage_cooldown_timer.one_shot = true
	touch_damage_cooldown_timer.wait_time = touch_damage_cooldown
	# ------------------------------------

	self.interrupted.connect(_on_interrupted)

	if PlayerSystem.is_player_available():
		target_player = PlayerSystem.get_player()
	
	if not PlayerSystem.player_registration_changed.is_connected(_on_player_registration_changed):
		PlayerSystem.player_registration_changed.connect(_on_player_registration_changed)

	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
	else:
		push_error("[Boss_ready] CRITICAL ERROR: animated_sprite node is not ready or not found in _ready!")
	
	if state_label:
		state_label.visible = debug_mode

func is_player_valid(p_player: Node) -> bool:
	if not PlayerSystem:
		printerr("[Boss.is_player_valid] PlayerSystem not available!")
		return false
	return p_player != null and is_instance_valid(p_player) and p_player == PlayerSystem.get_player()

func _handle_vision_cone_detection(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if not active: return

	if not is_instance_valid(target_player):
		if PlayerSystem.is_player_available():
			var player_from_global = PlayerSystem.get_player()
			if is_instance_valid(player_from_global):
				target_player = player_from_global
	
	_handle_vision_cone_detection(delta)

	if current_state == BossState.DEFEATED:
		return
		
	if not is_on_floor() and current_state != BossState.APPEAR:
		velocity.y += gravity * delta
	
	match current_state:
		BossState.IDLE:
			_process_idle_state(delta)
		BossState.APPEAR:
			_process_appear_state(delta)
		BossState.PHASE_TRANSITION:
			_process_phase_transition(delta)
		BossState.MOVE:
			_process_move_state(delta)
		BossState.HURT:
			_process_hurt_state(delta)
	
	_update_animation()

	move_and_slide()
	
	# 在所有移動和狀態更新後，再更新中斷狀態，確保我們用的是當前幀的正確動畫狀態
	_update_interruptible_status()
	
	if debug_mode and state_label:
		state_label.text = BossState.keys()[current_state] + " - Phase: " + str(current_phase)
#endregion

#region 虛擬函式 (供子類別覆寫)
# 新增：判斷一個狀態是否為攻擊狀態。子類別應覆寫此函式。
func _is_state_an_attack(state: int) -> bool:
	# 預設情況下，只有 ATTACK 和 SPECIAL_ATTACK 被視為攻擊
	return state == BossState.ATTACK or state == BossState.SPECIAL_ATTACK

# 新增：判斷一個狀態的持續時間是否由子類別手動（例如用Timer）控制。
# 如果是，父類別的 _on_animation_finished 就不應該在動畫結束時自動切換其狀態。
func _is_state_duration_handled_manually(_state: int) -> bool:
	return false # 預設情況下，所有狀態都由動畫長度控制。

#endregion

#region 初始化系統
func _initialize_boss() -> void:
	add_to_group("boss")
	current_health = max_health
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = max_health
		health_bar.visible = true
	
	call_deferred("emit_signal", "health_changed", current_health, max_health)
	call_deferred("emit_signal", "phase_changed", current_phase)

func _setup_collisions() -> void:
	# 使用統一的碰撞形狀管理器初始化 Hitbox 和 TouchDamageArea
	CollisionShapeManager.initialize_shape_sharing(self, hitbox, touch_damage_area)

func _connect_signals() -> void:
	if animated_sprite:
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)

	if not self.health_changed.is_connected(_on_health_changed):
		self.health_changed.connect(_on_health_changed)
	
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

	if touch_damage_area:
		if touch_damage_area.is_connected("body_entered", Callable(self, "_on_touch_damage_area_body_entered")):
			touch_damage_area.body_entered.disconnect(Callable(self, "_on_touch_damage_area_body_entered"))
		
		if touch_damage_area.is_connected("area_entered", Callable(self, "_on_touch_damage_area_area_entered_fixed")):
			touch_damage_area.area_entered.disconnect(Callable(self, "_on_touch_damage_area_area_entered_fixed"))

		if not touch_damage_area.is_connected("area_entered", Callable(self, "_on_touch_damage_area_entered")):
			touch_damage_area.area_entered.connect(Callable(self, "_on_touch_damage_area_entered"))

func _setup_attack_patterns() -> void:
	pass
#endregion

#region 狀態處理函數
func _process_idle_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)
	
	if is_instance_valid(target_player):
		_change_state(BossState.MOVE)

func _process_appear_state(_delta: float) -> void:
	pass

func _process_phase_transition(_delta: float) -> void:
	velocity.x = 0
	transition_timer -= _delta
	
	if transition_timer <= 0:
		_change_state(BossState.IDLE)
		vulnerable = true

func _process_move_state(_delta: float) -> void:
	if not is_instance_valid(target_player):
		_change_state(BossState.IDLE)
		return
	
	var distance_to_player = global_position.distance_to(target_player.global_position)
	var direction_to_player = (target_player.global_position - global_position).normalized()
	
	if distance_to_player <= attack_range:
		if attack_cooldown_timer.is_stopped():
			_select_attack()
		else:
			velocity.x = move_toward(velocity.x, direction_to_player.x * move_speed * 0.5, acceleration * _delta)
	else:
		velocity.x = move_toward(velocity.x, direction_to_player.x * move_speed, acceleration * _delta)
	
	if velocity.x != 0:
		if animated_sprite:
			animated_sprite.flip_h = velocity.x < 0

func _process_attack_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)

func _process_special_attack_state(_delta: float) -> void:
	if special_attack_cooldown_timer and special_attack_cooldown_timer.is_stopped():
		pass
	else:
		_change_state(BossState.IDLE)

func _process_hurt_state(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, deceleration * _delta)
#endregion

#region 攻擊系統
func _select_attack() -> void:
	if available_attacks.is_empty():
		return
	
	var phase_attack_list: Array
	if phase_attacks.has(current_phase):
		phase_attack_list = phase_attacks[current_phase]
	else:
		phase_attack_list = available_attacks
	
	if phase_attack_list.is_empty():
		return
	
	var attack_name = phase_attack_list[randi() % phase_attack_list.size()]
	current_attack = attack_name
	
	if attack_name.begins_with("special_"):
		_change_state(BossState.SPECIAL_ATTACK)
		special_attack_cooldown_timer.start(special_attack_cooldown)
	else:
		_change_state(BossState.ATTACK)
		attack_cooldown_timer.start(attack_cooldown)
	
	attack_started.emit(attack_name)

func _apply_attack_damage(body: Node2D, damage_amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage_amount)
	
	if knockback_force != Vector2.ZERO and body.has_method("apply_knockback"):
		body.apply_knockback(knockback_force)
#endregion

#region 受傷系統
func _update_interruptible_status() -> void:
	if interruptible_frames.is_empty():
		can_be_interrupted = false
		return

	var current_anim = animated_sprite.get_animation()
	var current_frame = animated_sprite.get_frame()

	var should_be_interruptible = false
	if interruptible_frames.has(current_anim):
		var frame_range: Vector2i = interruptible_frames[current_anim]
		if current_frame >= frame_range.x and current_frame <= frame_range.y:
			should_be_interruptible = true
	
	can_be_interrupted = should_be_interruptible

func take_damage(amount: float, _attacker: Node) -> void:
	if not vulnerable or is_invincible:
		return

	current_health = max(0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)
	
	var was_interrupted: bool = can_be_interrupted
	if was_interrupted:
		var attack_name_for_log = current_attack if not current_attack.is_empty() else animated_sprite.get_animation()
		emit_signal("interrupted", attack_name_for_log)
		_change_state(BossState.HURT)
	
	if current_health <= 0:
		_handle_defeat()

func _handle_defeat() -> void:
	current_health = 0
	_change_state(BossState.DEFEATED)
	
	# 清理所有衍生物
	_cleanup_all_spawnables()
	
	boss_defeated.emit()
	
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	
	if attack_area:
		attack_area.set_deferred("monitoring", false)

func _enter_next_phase() -> void:
	current_phase += 1
	if current_phase > total_phases:
		current_phase = total_phases
	
	phase_changed.emit(current_phase)
	
	_change_state(BossState.PHASE_TRANSITION)
	transition_timer = phase_transition_time
	vulnerable = false

func _on_defeated() -> void:
	_drop_items()
	
	queue_free()
	
func _drop_items() -> void:
	for item_name in guaranteed_drops:
		_spawn_item(item_name)
	
	for item_name in random_drops:
		if randf() <= drop_chance:
			_spawn_item(item_name)

func _spawn_item(_item_name: String) -> void:
	pass

func _reduce_all_action_cooldowns(amount: float) -> void:
	var current_time = Time.get_ticks_msec()
	for action in available_attacks:
		var time_since_last_used = (current_time - action.get("last_used_time", 0)) / 1000.0
		if action.get("last_used_time", 0) > 0 and time_since_last_used < action.get("min_interval", 0):
			action["last_used_time"] = action.get("last_used_time", 0) - int(amount * 1000)

func _on_hurt_animation_finished() -> void:
	_change_state(BossState.IDLE)
#endregion

#region 動畫系統
func _update_animation() -> void:
	if not animated_sprite:
		return

	var new_animation = get_current_animation_name()
	if animated_sprite.animation != null:
		pass
	
	if current_state >= 0 and current_state < BossState.size():
		pass

	if animated_sprite.animation != new_animation and new_animation != "":
		animated_sprite.play(new_animation)
	elif animated_sprite.animation == new_animation and not animated_sprite.is_playing() and new_animation != "":
		animated_sprite.play(new_animation)

func get_current_animation_name() -> String:
	var state_key = BossState.keys()[BossState.values().find(current_state)] if BossState.values().has(current_state) else null

	if state_key:
		if animation_name_map.has(state_key):
			return animation_name_map[state_key]
		
		return state_key.to_lower()
	
	return ""

func _change_state(new_state: int) -> void:
	if new_state == current_state and new_state != BossState.HURT: # Allow re-entering HURT
		return

	previous_state = current_state
	current_state = new_state
	
	# --- 自動管理接觸傷害 (修正後) ---
	var is_attack_state = _is_state_an_attack(current_state)
	var is_safe_state = current_state in [
		BossState.HURT, 
		BossState.PHASE_TRANSITION, 
		BossState.DEFEATED, 
		BossState.APPEAR,
		BossState.STUNNED
	]

	if is_attack_state or is_safe_state:
		set_touch_damage_active(false)
	else:
		set_touch_damage_active(true)
	# --------------------------------

	match current_state:
		BossState.PHASE_TRANSITION:
			vulnerable = false
			transition_timer = phase_transition_time
			emit_signal("phase_changed", current_phase)
	
	if animated_sprite:
		_update_animation()

func set_touch_damage_active(is_active: bool) -> void:
	if not is_instance_valid(touch_damage_area):
		# 如果 TouchDamageArea 不存在，靜默忽略（某些 BOSS 可能不需要接觸傷害）
		return
		
	var collision_shape = touch_damage_area.get_node_or_null("CollisionShape2D")
	if is_instance_valid(collision_shape):
		collision_shape.disabled = not is_active
		# CollisionShape2D 還未創建時靜默處理（由 CollisionShapeManager 稍後創建）

#endregion

#region 信號回調
func _on_health_changed(current: float, _max: float):
	if health_bar:
		health_bar.value = current

func _on_animation_finished() -> void:
	var anim_name: String
	if animated_sprite and animated_sprite.animation != null:
		anim_name = String(animated_sprite.animation)
	else:
		anim_name = "null_anim_name_on_finish"

	var current_state_val_on_finish = current_state
	var boss_state_count: int = BossState.size()

	if current_state_val_on_finish >= 0 and current_state_val_on_finish < boss_state_count:
		pass
	

	# 如果當前狀態的持續時間由子類別手動處理，則直接返回，不做任何操作。
	if _is_state_duration_handled_manually(current_state):
		return

	# 如果是攻擊動畫播放完畢，且該動畫不循環，則返回待機
	if _is_state_an_attack(current_state):
		if not animated_sprite.sprite_frames.get_animation_loop(anim_name):
			_change_state(BossState.IDLE)
			return
			
	match current_state:
		BossState.HURT:
			_change_state(BossState.IDLE)
		BossState.DEFEATED:
			# The defeat animation finishing should trigger the final cleanup
			_on_defeated_animation_finished()
		BossState.APPEAR:
			_change_state(BossState.IDLE)
		_:
			pass

func _on_defeated_animation_finished() -> void:
	# This function can be called after the "defeat" animation plays
	# to ensure the boss is properly removed from the game.
	queue_free()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if PlayerSystem.get_player() == body and not is_instance_valid(target_player):
		target_player = body as CharacterBody2D

		var boss_state_count_da_entered: int = BossState.size()
		if current_state >= 0 and current_state < boss_state_count_da_entered:
			pass
		if current_state == BossState.IDLE:
			_change_state(BossState.APPEAR)
	elif PlayerSystem.get_player() == body and is_instance_valid(target_player):
		var boss_state_count_da_entered_elif: int = BossState.size()
		if current_state >= 0 and current_state < boss_state_count_da_entered_elif:
			pass

func _on_detection_area_body_exited(body: Node) -> void:
	if is_player_valid(body):
		target_player = null

func _on_attack_area_body_entered(body: Node2D) -> void:
	if PlayerSystem.get_player() == body:
		var damage = attack_damage
		if current_state == BossState.SPECIAL_ATTACK:
			damage = special_attack_damage
		
		var knockback_dir = (body.global_position - global_position).normalized()
		var knockback_force = knockback_dir * 300
		
		_apply_attack_damage(body, damage, knockback_force)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		var damage_amount = 10.0  # 預設傷害值
		if "damage" in area and area.damage != null:
			damage_amount = area.damage
		take_damage(damage_amount, area.get_owner())

func _on_touch_damage_area_entered(area: Area2D) -> void:
	# 檢查計時器是否存在且有效
	if not is_instance_valid(touch_damage_cooldown_timer):
		printerr("[BossBase] TouchDamageCooldownTimer is not valid!")
		return
		
	# 如果計時器正在運行，則不造成傷害
	if not touch_damage_cooldown_timer.is_stopped():
		return

	# 檢查進入的區域是否為玩家的受擊區
	if area.is_in_group("player_hurtbox"):
		var player_node = area.get_owner()
		if player_node and player_node.has_method("take_damage"):
			# 對玩家造成傷害
			player_node.take_damage(touch_damage)
			# 啟動冷卻計時器
			touch_damage_cooldown_timer.start()

func _on_player_registration_changed(_is_registered: bool) -> void:
	if _is_registered and PlayerSystem.is_player_available():
		target_player = PlayerSystem.get_player()
	else:
		target_player = null

# BOSS死亡時清理所有衍生物（統一方法）
func _cleanup_all_spawnables() -> void:
	var spawnable_group = boss_name.to_lower() + "_spawnables"
	var spawnables = get_tree().get_nodes_in_group(spawnable_group)
	
	for spawnable in spawnables:
		if is_instance_valid(spawnable):
			if spawnable.has_method("cleanup"):
				spawnable.cleanup()
			else:
				spawnable.queue_free()

func _on_interrupted(_attack_name: String) -> void:
	pass
#endregion 
