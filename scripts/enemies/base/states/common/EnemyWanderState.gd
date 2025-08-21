extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name EnemyWanderState

var wander_timer: float = 0.0
var wander_direction: float = 0.0

func on_enter() -> void:
	super.on_enter()
	_start_new_wander()
	var walk_animation = owner._get_walk_animation()
	if walk_animation:
		owner.animated_sprite.play(walk_animation)

func on_exit() -> void:
	owner.velocity.x = 0
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	wander_timer -= delta
	
	if wander_timer <= 0:
		transition_to("Idle")
		return
		
	owner.velocity.x = wander_direction * owner.move_speed
	
	owner._post_physics_processing(delta)
	
	owner._update_sprite_flip()


func _start_new_wander() -> void:
	wander_timer = randf_range(owner.wander_time_min, owner.wander_time_max)
	wander_direction = 1.0 if randf() > 0.5 else -1.0


func on_player_detected(_body: Node) -> void:
	super.on_player_detected(_body)
	transition_to("Chase") 
