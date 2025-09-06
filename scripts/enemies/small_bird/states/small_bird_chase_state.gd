extends "res://scripts/enemies/base/states/common/enemy_state_base.gd"

class_name SmallBirdChaseState

var chase_update_timer: float = 0.0
var chase_update_interval: float = 0.2  # 每0.2秒更新目標

func on_enter() -> void:
	super.on_enter()
	owner.set_flight_mode(true)
	owner.animated_sprite.play(owner._get_fly_animation())
	
	# 立即獲取追擊目標
	update_chase_target()

func on_exit() -> void:
	# 恢復正常的飛行週期
	owner.start_new_cycle()
	super.on_exit()

func process_physics(delta: float) -> void:
	super.process_physics(delta)
	
	if not is_instance_valid(owner.player):
		transition_to("Patrol")
		return
	
	# 定期更新追擊目標
	chase_update_timer += delta
	if chase_update_timer >= chase_update_interval:
		update_chase_target()
		chase_update_timer = 0.0
	
	# 手動執行飛行（覆蓋基類的自動週期）
	owner.fly_toward_target(delta)
	
	# 檢查攻擊機會
	check_attack_opportunity()

## 更新追擊目標
func update_chase_target() -> void:
	owner.current_target = owner.get_chase_target(owner.player)
	owner.is_flying = true
	# 重置基類的飛行計時器，避免自動選擇新目標
	owner.flight_timer = 0.0

## 檢查攻擊機會
func check_attack_opportunity() -> void:
	var distance_to_player = owner.global_position.distance_to(owner.player.global_position)
	
	# 理想攻擊距離
	if distance_to_player < 150 and distance_to_player > 80:
		if owner.attack_cooldown_timer.is_stopped():
			transition_to("Attack")
	elif distance_to_player < 60:
		# 太近了，稍微後退
		var retreat_direction = (owner.global_position - owner.player.global_position).normalized()
		owner.velocity += retreat_direction * 100

func on_player_lost(_body: Node) -> void:
	super.on_player_lost(_body)
	transition_to("Patrol")