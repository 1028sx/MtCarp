extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name ArcherChaseState

func process_physics(_delta: float) -> void:
	if not is_instance_valid(owner.player):
		transition_to("Idle")
		return

	# --- 決策變數 ---
	var in_retreat_zone = owner.zone_states.get("in_retreat_zone", false)
	var in_attack_zone = owner.zone_states.get("in_attack_zone", false)
	var can_attack = owner.attack_cooldown_timer.is_stopped()
	var direction := Vector2.ZERO

	# --- 全新決策樹 ---

	# 1. 最高優先級：如果可以攻擊，就立刻攻擊。
	if can_attack and in_attack_zone:
		transition_to("Attack")
		return

	# 2. 如果不能攻擊，再決定如何移動。
	# 2a. 玩家太近，需要後退。
	if in_retreat_zone:
		# 在後退前，先檢查身後有沒有退路。
		var is_cornered = owner._is_wall_or_ledge_behind()
		if is_cornered:
			# 如果被逼到角落，就放棄後退，原地待命。
			transition_to("HoldPosition")
			return
		else:
			# 如果還有空間，才執行後退。
			direction = (owner.global_position - owner.player.global_position).normalized()
			owner.velocity.x = direction.x * owner.move_speed
	
	# 2b. 在理想攻擊位置，但攻擊正在冷卻中。
	elif in_attack_zone:
		# 保持原地不動，等待冷卻結束。
		transition_to("HoldPosition")
		return

	# 2c. 玩家太遠，需要追擊。
	else:
		direction = (owner.player.global_position - owner.global_position).normalized()
		owner.velocity.x = move_toward(owner.velocity.x, direction.x * owner.move_speed, owner.acceleration * _delta)

	# --- 更新動畫與物理狀態 ---
	owner.animated_sprite.play(owner._get_walk_animation())
	owner._update_sprite_flip()
	owner._post_physics_processing(_delta)
