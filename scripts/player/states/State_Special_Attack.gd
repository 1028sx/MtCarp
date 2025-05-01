class_name State_Special_Attack
extends PlayerState

@export var idle_state: PlayerState
@export var fall_state: PlayerState

var animation_finished := false
const DAMAGE_START_FRAME = 5
const DAMAGE_END_FRAME = 9

func enter() -> void:
	# print("Entering Special Attack State")
	animation_finished = false
	player.can_special_attack = false # 使用特殊攻擊後進入冷卻
	player.special_attack_timer = player.special_attack_cooldown
	player.hit_enemies.clear() # 清空本次攻擊命中的敵人列表

	# 根據鼠標方向翻轉
	var mouse_pos = player.get_global_mouse_position()
	var direction_to_mouse = (mouse_pos - player.global_position).normalized()
	player.animated_sprite.flip_h = direction_to_mouse.x < 0

	# 播放動畫
	player.animated_sprite.play("special_attack")
	player.animated_sprite.speed_scale = 1.0 # 確保動畫速度正常

	# 可以在此處或 frame_changed 中啟用 Area
	# player.special_attack_area.monitoring = true

func process_physics(delta: float) -> void:
	# 特殊攻擊期間通常不允許大幅移動，只應用重力
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	else:
		# 在地面上可以稍微減速
		player.velocity.x = move_toward(player.velocity.x, 0, player.speed * 0.1) # 例子：減速到10%

	player.move_and_slide()

func get_transition() -> PlayerState:
	# 動畫結束後轉換狀態
	if animation_finished:
		return fall_state if not player.is_on_floor() else idle_state
	return null

func exit() -> void:
	# print("Exiting Special Attack State")
	# 確保退出時關閉監測
	if player.special_attack_area:
		player.special_attack_area.monitoring = false
	player.hit_enemies.clear() # 再次清空以防萬一

# --- Signal Handlers (由 PlayerStateMachine 調用) ---

func on_animation_finished(anim_name: String) -> void:
	if anim_name == "special_attack":
		animation_finished = true

func on_frame_changed(frame: int) -> void:
	if player.animated_sprite.animation == "special_attack":
		# 在特定幀觸發傷害判定
		if frame >= DAMAGE_START_FRAME and frame <= DAMAGE_END_FRAME:
			_apply_special_attack_damage()
		# 可以在傷害幀結束後關閉監測
		elif frame > DAMAGE_END_FRAME:
			if player.special_attack_area:
				player.special_attack_area.monitoring = false

# --- Helper Functions ---

func _apply_special_attack_damage() -> void:
	if not player.special_attack_area:
		printerr("特殊攻擊區域 (SpecialAttackArea) 未設置！")
		return

	# 確保 Area 是 monitoring 狀態
	if not player.special_attack_area.monitoring:
		player.special_attack_area.monitoring = true
		# 等待一物理幀確保碰撞檢測更新
		await player.get_tree().physics_frame

	var areas = player.special_attack_area.get_overlapping_areas()
	for area in areas:
		var body = area.get_parent()
		# 確保是敵人、可以受傷且本次攻擊未命中過
		if body != player and body.is_in_group("enemy") and body.has_method("take_damage") and not player.hit_enemies.has(body):
			player.hit_enemies.append(body)

			# --- 計算傷害 ---
			var damage = player.base_special_attack_damage
			var knockback_force = Vector2(0, -1) * 300 # 基礎向上擊退

			# 檢查多重打擊效果
			if player.active_effects.has("multi_strike"):
				var frame_damage_bonus = max(0, player.animated_sprite.frame - DAMAGE_START_FRAME) * 5
				damage += frame_damage_bonus
				knockback_force *= 5 # 多重打擊增加擊退力
			# else: # 可以保留原有的按幀數固定傷害邏輯，如果需要
			# 	match player.animated_sprite.frame:
			# 		5: damage = player.base_special_attack_damage
			# 		6: damage = player.base_special_attack_damage
			# 		7: damage = player.base_special_attack_damage

			# 檢查狂怒效果
			if player.active_effects.has("rage"):
				var rage_bonus = player.rage_stack * player.rage_damage_bonus
				damage *= (1 + rage_bonus)

			# --- 檢查收割效果 ---
			var trigger_harvest = false
			if player.active_effects.has("harvest"):
				var enemy_health = 0.0
				if body.has_method("get_health"): enemy_health = body.get_health()
				elif body.has_method("get_current_health"): enemy_health = body.get_current_health()
				else:
					enemy_health = body.get("health") if body.get("health") != null else 0.0
					if enemy_health == 0.0: enemy_health = body.get("current_health") if body.get("current_health") != null else 0.0

				if damage >= enemy_health and enemy_health > 0:
					trigger_harvest = true

			# --- 應用擊退和傷害 ---
			if body.has_method("apply_knockback"):
				body.apply_knockback(knockback_force)

			body.take_damage(damage) # 造成傷害

			# --- 應用收割效果 (如果觸發) ---
			if trigger_harvest:
				var heal_amount = player.max_health * 0.05
				player.current_health = min(player.current_health + heal_amount, player.max_health)
				player.health_changed.emit(player.current_health)
				if player.effect_manager:
					player.effect_manager.play_heal_effect() 
