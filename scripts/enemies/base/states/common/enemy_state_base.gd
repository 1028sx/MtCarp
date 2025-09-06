extends Object
class_name EnemyStateBase

var owner: EnemyAIBase

func initialize(state_owner: EnemyAIBase) -> void:
	self.owner = state_owner

func on_enter() -> void:
	pass

func on_exit() -> void:
	pass

func process_physics(_delta: float) -> void:
	pass
	
func process_frame(_delta: float) -> void:
	pass

func on_animation_finished() -> void:
	pass

func on_player_detected(_body: Node) -> void:
	pass

func on_player_lost(_body: Node) -> void:
	pass

func transition_to(state_name: String) -> void:
	if owner:
		owner.change_state(state_name) 
