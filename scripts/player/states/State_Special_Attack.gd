class_name State_Special_Attack
extends PlayerState

@export var idle_state: PlayerState
@export var fall_state: PlayerState

var animation_finished := false
const DAMAGE_START_FRAME = 5
const DAMAGE_END_FRAME = 9

func enter() -> void:
	animation_finished = false
	player.can_special_attack = false
	player.special_attack_timer = player.special_attack_cooldown
	player.hit_enemies.clear()

	var mouse_pos = player.get_global_mouse_position()
	var direction_to_mouse = (mouse_pos - player.global_position).normalized()
	player.animated_sprite.flip_h = direction_to_mouse.x < 0
	player.animated_sprite.play("special_attack")
	player.animated_sprite.speed_scale = 1.0


func process_physics(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.speed * 0.1)

	player.move_and_slide()

func get_transition() -> PlayerState:
	if animation_finished:
		return fall_state if not player.is_on_floor() else idle_state
	return null

func exit() -> void:
	if player.special_attack_area:
		player.special_attack_area.monitoring = false
	player.hit_enemies.clear()

func on_animation_finished(anim_name: String) -> void:
	if anim_name == "special_attack":
		animation_finished = true

func on_frame_changed(frame: int) -> void:
	if player.animated_sprite.animation == "special_attack":
		if frame >= DAMAGE_START_FRAME and frame <= DAMAGE_END_FRAME:
			_apply_special_attack_damage()
		elif frame > DAMAGE_END_FRAME:
			if player.special_attack_area:
				player.special_attack_area.monitoring = false


func _apply_special_attack_damage() -> void:
	if not player.special_attack_area.monitoring:
		player.special_attack_area.monitoring = true
		await player.get_tree().physics_frame

	var areas = player.special_attack_area.get_overlapping_areas()
	for area in areas:
		var body = area.get_parent()
		if body != player and body.is_in_group("enemy") and body.has_method("take_damage") and not player.hit_enemies.has(body):
			player.hit_enemies.append(body)

			var damage = player.base_special_attack_damage
			var knockback_force = Vector2(0, -1) * 300

			if player.active_effects.has("multi_strike"):
				var frame_damage_bonus = max(0, player.animated_sprite.frame - DAMAGE_START_FRAME) * 5
				damage += frame_damage_bonus
				knockback_force *= 5

			if player.active_effects.has("rage"):
				var rage_bonus = player.rage_stack * player.rage_damage_bonus
				damage *= (1 + rage_bonus)

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

			if body.has_method("apply_knockback"):
				body.apply_knockback(knockback_force)

			body.take_damage(damage)

			if trigger_harvest:
				var heal_amount = player.max_health * 0.05
				player.current_health = min(player.current_health + heal_amount, player.max_health)
				player.health_changed.emit(player.current_health)
				if player.effect_manager:
					player.effect_manager.play_heal_effect() 
