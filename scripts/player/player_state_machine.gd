extends Node

class_name PlayerStateMachine

@export var initial_state: PlayerState

var current_state: PlayerState
var player: CharacterBody2D
var states: Dictionary = {}


func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if not player:
		return

	for child in get_children():
		if child is PlayerState:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.player = player

	if initial_state:
		if not initial_state is PlayerState:
			return
			
		initial_state.state_machine = self
		initial_state.player = player
		current_state = initial_state
		current_state.enter.call_deferred()
	else:
		pass 

func _input(event: InputEvent) -> void:
	if current_state:
		current_state.process_input(event)

func _physics_process(delta: float) -> void:
	if current_state:
		if current_state.has_method("process_physics") or current_state.has_method("custom_update_ground_slam"):
			if current_state.name == "GroundSlam":
				current_state.custom_update_ground_slam(delta)
			else:
				current_state.process_physics(delta)

		var next_state = current_state.get_transition()
		if next_state:
			_transition_to(next_state)

func _process(delta: float) -> void:
	if current_state:
		current_state.process_frame(delta)

func _transition_to(new_state: PlayerState) -> void:
	var _current_state_str = str(current_state.name) if current_state else "None"
	if not new_state:
		return
	if new_state == current_state and not (new_state is state_jump):
		return

	if current_state:
		current_state.exit()

	var _old_state_name = str(current_state.name) if current_state else "None"
	current_state = new_state

	current_state.enter()
