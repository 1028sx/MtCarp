extends "res://scripts/enemies/base/states/common/enemy_state_base.gd"

class_name EnemyIdleState

var idle_timer: float = 0.0

func on_enter() -> void:
	super.on_enter()
	owner.velocity.x = 0
	var idle_animation = owner._get_idle_animation()
	if idle_animation:
		owner.animated_sprite.play(idle_animation)
	
	idle_timer = randf_range(1.0, 3.0)

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	owner.velocity.x = move_toward(owner.velocity.x, 0, owner.deceleration * delta)
	
	owner._update_sprite_flip()
	
	idle_timer -= delta
	if idle_timer <= 0 and owner.states.has("Wander"):
		transition_to("Wander")

func on_player_detected(_body: Node) -> void:
	super.on_player_detected(_body)
	transition_to("Chase") 