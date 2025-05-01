extends PlayerState

@export var hurt_duration = 0.3 # 受傷狀態持續時間
var hurt_timer = 0.0

func enter() -> void:
	super.enter()
	player.velocity = Vector2.ZERO # 稍微停頓一下
	player.animated_sprite.play("hurt") # 播放受傷動畫 (假設你有這個動畫)
	hurt_timer = hurt_duration
	# 可以選擇在這裡給予短暫無敵，或者在 player.gd 的 take_damage 中處理

func process_physics(delta: float) -> void:
	super.process_physics(delta)

	# 應用重力
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta

	player.move_and_slide()

	# 計時器減少
	hurt_timer -= delta
	if hurt_timer <= 0:
		# 受傷狀態結束，切換回 Idle 或 Fall 狀態
		if player.is_on_floor():
			state_machine._transition_to(state_machine.states.get("idle"))
		else:
			state_machine._transition_to(state_machine.states.get("fall"))

func exit() -> void:
	super.exit()
	# 確保動畫速度恢復正常 (如果 hurt 動畫速度不同)
	# player.animated_sprite.speed_scale = 1.0
