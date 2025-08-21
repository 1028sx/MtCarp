extends "res://scripts/enemies/base/states/common/EnemyStateBase.gd"

class_name ChickenFallState

const AIR_MANEUVERABILITY_MULTIPLIER = 0.8  # 提升空中機動性以配合更快的移動速度
const PlayerGlobalScript = preload("res://scripts/globals/PlayerGlobal.gd")
const FALL_GRAVITY_SCALE = 0.6
const NORMAL_GRAVITY_SCALE = 1.0

func on_enter() -> void:
	super.on_enter()
	# 減小重力以獲得更長的滯空時間
	owner.gravity_scale = FALL_GRAVITY_SCALE
	owner.animated_sprite.play(owner._get_fly_animation())

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	# 在空中時，依然可以有水平控制，以追向玩家 (已更新為使用 PlayerGlobal)
	if PlayerGlobalScript.is_player_available():
		var player = PlayerGlobalScript.get_player()
		var direction_to_player = owner.global_position.direction_to(player.global_position)
		var target_velocity_x = direction_to_player.x * owner.move_speed * AIR_MANEUVERABILITY_MULTIPLIER
		owner.velocity.x = move_toward(owner.velocity.x, target_velocity_x, owner.acceleration * AIR_MANEUVERABILITY_MULTIPLIER * delta)
		owner._update_sprite_flip()

	# 當回到地面時，結束這個狀態
	if owner.is_on_floor():
		# 根據玩家是否存在來決定下一個狀態 (已更新為使用 PlayerGlobal)
		if PlayerGlobalScript.is_player_available():
			owner.change_state("Chase")
		else:
			owner.change_state("Idle")

func on_exit() -> void:
	super.on_exit()
	# 恢復正常的重力
	owner.gravity_scale = NORMAL_GRAVITY_SCALE
	# 可選：在落地時播放一個落地動畫
	# owner.animated_sprite.play("land") 