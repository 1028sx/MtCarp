class_name PlayerSpecialAttackState
extends "res://scripts/player/player_state.gd"

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
		player.special_attack_area.set_deferred("monitorable", false)
	player.hit_enemies.clear()

func on_animation_finished(anim_name: String) -> void:
	if anim_name == "special_attack":
		animation_finished = true

func on_frame_changed(frame: int) -> void:
	if player.state_machine.current_state != self:
		return
		
	if player.animated_sprite.animation == "special_attack":
		var is_damage_frame := false
		# 只在第 5, 7, 9 幀造成傷害
		if frame in [DAMAGE_START_FRAME, DAMAGE_START_FRAME + 2, DAMAGE_END_FRAME]:
			is_damage_frame = true

		if is_damage_frame:
			# 每次傷害判定前清空命中列表，以實現多段傷害
			player.hit_enemies.clear()
			_apply_special_attack_damage()
		elif frame > DAMAGE_END_FRAME:
			if player.special_attack_area:
				player.special_attack_area.monitoring = false
				player.special_attack_area.set_deferred("monitorable", false)


func _apply_special_attack_damage() -> void:
	if player.state_machine.current_state != self:
		return
		
	if not player.special_attack_area.monitoring:
		player.special_attack_area.monitoring = true
		player.special_attack_area.set_deferred("monitorable", true)
		await player.get_tree().physics_frame

	var areas = player.special_attack_area.get_overlapping_areas()
	for area in areas:
		var body = area.get_parent()
		if body != player and body.is_in_group("enemy") and body.has_method("take_damage") and not player.hit_enemies.has(body):
			player.hit_enemies.append(body)

			var damage = player.base_special_attack_damage
			var knockback_force = Vector2(0, -1) * 300




			if body.has_method("apply_knockback"):
				body.apply_knockback(knockback_force)

			body.take_damage(damage, player)

