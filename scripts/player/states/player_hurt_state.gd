class_name PlayerHurtState
extends "res://scripts/player/player_state.gd"

@export var hurt_duration = 0.3
var hurt_timer = 0.0

func enter() -> void:
	super.enter()
	player.velocity = Vector2.ZERO
	player.animated_sprite.play("hurt")
	hurt_timer = hurt_duration

func process_physics(delta: float) -> void:
	super.process_physics(delta)

	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta

	player.move_and_slide()

	hurt_timer -= delta
	if hurt_timer <= 0:
		if player.is_on_floor():
			state_machine._transition_to(state_machine.states.get("idle"))
		else:
			state_machine._transition_to(state_machine.states.get("fall"))

func exit() -> void:
	super.exit()
