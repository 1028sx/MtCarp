extends Node

class_name PlayerStateMachine

@export var initial_state: PlayerState

var current_state: PlayerState
var player: CharacterBody2D
var states: Dictionary = {}


func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if not player:
		push_error("PlayerStateMachine 必須是 Player (CharacterBody2D) 的子節點！")
		return

	for child in get_children():
		if child is PlayerState:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.player = player
		else:
			print("警告：StateMachine 的子節點 '" + child.name + "' 不是 PlayerState，將被忽略。")

	if initial_state:
		if not initial_state is PlayerState:
			push_error("導出的 initial_state 不是有效的 PlayerState 節點！")
			return
			
		initial_state.state_machine = self
		initial_state.player = player
		current_state = initial_state
		current_state.enter.call_deferred()
	else:
		push_error("PlayerStateMachine 未設置初始狀態 (initial_state)！")

func _input(event: InputEvent) -> void:
	if current_state:
		current_state.process_input(event)

func _physics_process(delta: float) -> void:
	if current_state:
		# print("[StateMachine] Current State:", current_state.name)
		# print("[StateMachine] Attempting to call process_physics on state: ", current_state.name) # 已註解
		
		if current_state.has_method("process_physics") or current_state.has_method("custom_update_ground_slam"):
			# 根據狀態名稱決定呼叫哪個方法
			if current_state.name == "GroundSlam": # 假設您的 GroundSlam 節點名稱就是 "GroundSlam"
				# print("[StateMachine] State 'GroundSlam' HAS custom_update_ground_slam method. Calling it.") # 已註解
				current_state.custom_update_ground_slam(delta)
			else:
				# print("[StateMachine] State '", current_state.name, "' HAS process_physics method. Calling it.") # 已註解
				current_state.process_physics(delta)
		else:
			printerr("[StateMachine] ERROR: State '", current_state.name, "' does NOT have a recognized physics update method!")
		
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
	if new_state == current_state and not (new_state is State_Jump):
		return

	if current_state:
		current_state.exit()

	var _old_state_name = str(current_state.name) if current_state else "None"
	current_state = new_state

	current_state.enter()
