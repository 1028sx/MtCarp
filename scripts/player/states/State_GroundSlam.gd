extends PlayerState

var animated_sprite: AnimatedSprite2D
var effect_manager
var ground_slam_area: Area2D
var impact_executed: bool = false

func _ready() -> void:
	pass

func enter() -> void:
	if not player:
		if state_machine and state_machine.states.has("idle"):
			state_machine._transition_to(state_machine.states.get("idle"))
		return

	animated_sprite = player.get_node_or_null("AniSprite2D")
	effect_manager = player.get_node_or_null("EffectManager") 
	ground_slam_area = player.get_node_or_null("GroundSlamArea") 

	if not animated_sprite or not ground_slam_area:
		return
		
	impact_executed = false
	player.set_can_ground_slam(false)
	
	ground_slam_area.monitoring = true
	ground_slam_area.monitorable = true
	
	if player.has_method("set_invincible"):
		player.set_invincible(1.0)
	
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("groundslam"):
		animated_sprite.play("groundslam")
	
	player.velocity.y = 800
	player.velocity.x *= 0.5

func exit() -> void:
	if player and player.is_on_floor() and not impact_executed:
		_ground_slam_impact()
	
	if ground_slam_area:
		ground_slam_area.monitoring = false
		ground_slam_area.monitorable = false
	
	if player and player.has_method("set_invincible"):
		player.set_invincible(0.5)

func custom_update_ground_slam(delta: float) -> void:
	process_physics(delta)

func process_physics(delta: float) -> void:
	player.velocity.x *= 0.98
	player.velocity.y = min(player.velocity.y + player.gravity * delta, 800)
	player.move_and_slide()
	
	if player.is_on_floor() and not impact_executed:
		_ground_slam_impact()
		await get_tree().create_timer(0.3).timeout
		
		if state_machine and state_machine.states.has("idle"):
			state_machine._transition_to(state_machine.states.get("idle"))

func _ground_slam_impact() -> void:
	if impact_executed or not ground_slam_area:
		return
		
	impact_executed = true
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var overlapping_areas = ground_slam_area.get_overlapping_areas()
	var overlapping_bodies = ground_slam_area.get_overlapping_bodies()
	
	var hit_enemies = []
	
	for area in overlapping_areas:
		var parent = area.get_parent()
		if parent and (parent.is_in_group("enemy") or parent.is_in_group("boss")):
			if parent in hit_enemies:
				continue
				
			if parent.has_method("take_damage"):
				parent.take_damage(30)
				hit_enemies.append(parent)
	
	for body in overlapping_bodies:
		if body and (body.is_in_group("enemy") or body.is_in_group("boss")):
			if body in hit_enemies:
				continue
				
			if body.has_method("take_damage"):
				body.take_damage(30)
				hit_enemies.append(body)
	
	if effect_manager and effect_manager.has_method("play_impact_effect"):
		effect_manager.play_impact_effect(Vector2(0, 32))

func _apply_damage_to_enemy(enemy: Node) -> void:
	if not enemy: return
	
	var damage = player.base_attack_damage * player.GROUND_SLAM_DAMAGE_MULTIPLIER
	
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", damage, player)
			
	var direction_to_enemy = player.global_position.direction_to(enemy.global_position)
	var knockback_vector = Vector2(direction_to_enemy.x, -abs(direction_to_enemy.y * 0.3) - 0.7).normalized()
	
	var distance_to_enemy = player.global_position.distance_to(enemy.global_position)
	var max_effective_range = 200.0 
	var distance_factor = clamp(1.0 - (distance_to_enemy / max_effective_range), 0.2, 1.0)
	
	var actual_knockback_force = player.GROUND_SLAM_KNOCKBACK_FORCE * distance_factor
	
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", knockback_vector * actual_knockback_force)

# 可以添加 on_animation_finished 等回呼函數來處理動畫相關邏輯
# func on_animation_finished(anim_name: StringName) -> void:
# 	if anim_name == "ground_slam_impact":
# 		# 衝擊動畫播放完畢後，可能需要轉換到 Idle 或其他狀態
#		 if get_parent().states.has("idle"):
#			 get_parent()._transition_to(get_parent().states.get("idle"))
#		 pass
