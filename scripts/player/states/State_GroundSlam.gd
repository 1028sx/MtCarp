extends PlayerState

var animated_sprite: AnimatedSprite2D
var effect_manager
var ground_slam_area: Area2D

func _ready() -> void:
	pass

func enter() -> void:
	if not player:
		printerr("State_GroundSlam.enter(): Player node is null. Critical error. Cannot enter state.")
		if state_machine and state_machine.states.has("idle"):
			state_machine._transition_to(state_machine.states.get("idle"))
		else:
			printerr("State_GroundSlam.enter(): Cannot transition to idle as it's not found in state_machine.states.")
		return

	animated_sprite = player.get_node_or_null("AniSprite2D")
	effect_manager = player.get_node_or_null("EffectManager") 
	ground_slam_area = player.get_node_or_null("GroundSlamArea") 

	if not animated_sprite:
		printerr("State_GroundSlam.enter(): AniSprite2D node ('AniSprite2D') not found on Player.")
	if not effect_manager:
		print("State_GroundSlam.enter(): EffectManager node ('EffectManager') not found on Player. Effects may not play.")
	if not ground_slam_area:
		printerr("State_GroundSlam.enter(): GroundSlamArea node ('GroundSlamArea') not found on Player. Ground slam impact will not work.")

	print("[State_GroundSlam] Entering state...")

	player.velocity.x = 0
	player.velocity.y = player.GROUND_SLAM_SPEED
	player.set_invincible(0.2)
	
	player.set_can_ground_slam(false)

	if self.animated_sprite:
		pass
	
	if self.ground_slam_area:
		self.ground_slam_area.monitoring = false
		self.ground_slam_area.monitorable = false 


func custom_update_ground_slam(_delta: float) -> void:
	
	if not player:
		print("[State_GroundSlam] custom_update_ground_slam: Player node missing!")
		return
	
	player.velocity.y = player.GROUND_SLAM_SPEED

	
	player.move_and_slide()
	
	if player.is_on_floor():
		print("[State_GroundSlam] Player is on floor.") 
		_on_ground_impact()
		
		if state_machine and state_machine.states.has("idle"):
			state_machine._transition_to(state_machine.states.get("idle"))
		else:
			if state_machine and state_machine.states.has("fall"):
				state_machine._transition_to(state_machine.states.get("fall"))
			else:
				printerr("State_GroundSlam: Cannot transition! Neither 'idle' nor 'fall' state found in StateMachine.")


func _on_ground_impact() -> void:
	if not player:
		return
	
	if not self.ground_slam_area:
		printerr("State_GroundSlam._on_ground_impact(): ground_slam_area is null. Cannot perform impact logic.")
		return
		
	print("Ground Slam Impact!")

	if self.animated_sprite:
		pass
	if self.effect_manager:
		pass

	self.ground_slam_area.set_collision_layer_value(1, false) 
	self.ground_slam_area.set_collision_mask_value(3, true)
	
	var hit_enemies = [] 
	var overlapping_bodies = self.ground_slam_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body.is_in_group("enemy") and not hit_enemies.has(body):
			hit_enemies.append(body)
			var enemy = body as Node2D
			
			if not enemy: continue

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

	player.set_invincible(0) 

func exit() -> void:
	print("[State_GroundSlam] Exiting state...")
	if player:
		if not player.is_on_floor():
			player.velocity.y = 0 
		player.set_invincible(0) 
	# if self.ground_slam_area: # monitoring 通常在 enter/exit 或需要時設定
	# 	self.ground_slam_area.monitoring = false
	# print("Exiting Ground Slam State") # 重複

# 可以添加 on_animation_finished 等回呼函數來處理動畫相關邏輯
# func on_animation_finished(anim_name: StringName) -> void:
# 	if anim_name == "ground_slam_impact":
# 		# 衝擊動畫播放完畢後，可能需要轉換到 Idle 或其他狀態
#		 if get_parent().states.has("idle"):
#			 get_parent()._transition_to(get_parent().states.get("idle"))
#		 pass
