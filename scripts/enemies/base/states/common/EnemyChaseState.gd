class_name EnemyChaseState
extends EnemyStateBase

func on_enter() -> void:
	"""進入追擊狀態。"""
	super.on_enter()
	var walk_animation = owner._get_walk_animation()
	if walk_animation:
		owner.animated_sprite.play(walk_animation)

func process_physics(delta: float) -> void:
	"""處理追擊時的物理。"""
	super.process_physics(delta)

	if not is_instance_valid(owner.player):
		transition_to("Idle")
		return

	var direction_to_player = (owner.player.global_position - owner.global_position).normalized()
	
	owner.velocity.x = move_toward(owner.velocity.x, direction_to_player.x * owner.move_speed, owner.acceleration * delta)
	
	owner._update_sprite_flip()

	owner._post_physics_processing(delta)

	var distance_to_player = owner.global_position.distance_to(owner.player.global_position)
	if distance_to_player <= owner.attack_range:
		if owner.attack_cooldown_timer.is_stopped():
			transition_to("Attack")

func on_player_lost(_body: Node) -> void:
	"""當玩家離開偵測範圍時，返回待機狀態。"""
	super.on_player_lost(_body)
	transition_to("Idle") 