extends PlayerState

# Ground Slam State

# class成員變數，將在enter或需要時賦值
var animated_sprite: AnimatedSprite2D
var effect_manager # Node, 具體類型待定. 如果 PlayerState 基類有定義，則無需重複聲明
var ground_slam_area: Area2D

func _ready() -> void:
	# _ready 函數可以保留為空，或者用於做與 player 賦值無關的初始化
	# 不在此處檢查 player 或獲取 player 的子節點
	# 初始的 printerr("State_GroundSlam: Player node was not assigned by the StateMachine.") 是由此處的 if not player 觸發
	# 現已移除，因為 player 的賦值由 PlayerStateMachine._ready() 負責，且在狀態的 enter() 執行前完成
	pass

func enter() -> void:
	# 首先檢查 player 是否已被 StateMachine 正確賦值
	if not player:
		printerr("State_GroundSlam.enter(): Player node is null. Critical error. Cannot enter state.")
		# 緊急出口：嘗試轉換回 idle 狀態，防止遊戲卡死
		if state_machine and state_machine.states.has("idle"):
			state_machine._transition_to(state_machine.states.get("idle"))
		else:
			printerr("State_GroundSlam.enter(): Cannot transition to idle as it's not found in state_machine.states.")
		return

	# 從 player 節點獲取其他必要的元件引用
	# 假設節點路徑是相對於 Player 節點的
	animated_sprite = player.get_node_or_null("AniSprite2D")
	effect_manager = player.get_node_or_null("EffectManager") 
	ground_slam_area = player.get_node_or_null("GroundSlamArea") 

	if not animated_sprite:
		printerr("State_GroundSlam.enter(): AniSprite2D node ('AniSprite2D') not found on Player.")
	if not effect_manager:
		# 這可能不是致命錯誤，取決於 effect_manager 的用途
		print("State_GroundSlam.enter(): EffectManager node ('EffectManager') not found on Player. Effects may not play.")
	if not ground_slam_area:
		printerr("State_GroundSlam.enter(): GroundSlamArea node ('GroundSlamArea') not found on Player. Ground slam impact will not work.")
		# 如果 ground_slam_area 至關重要，可能也需要轉換回 idle

	print("[State_GroundSlam] Entering state...")

	player.velocity.x = 0 # 取消水平動能
	player.velocity.y = player.GROUND_SLAM_SPEED # 開始向下衝刺
	player.set_invincible(0.2) # 假設衝刺期間是短暫無敵的
	
	player.set_can_ground_slam(false) # 使用 setter，確保相關日誌或邏輯被觸發

	if self.animated_sprite: # 使用 self. 避免歧義，雖然在此作用域內不是必須
		# self.animated_sprite.play("ground_slam_fall") # 播放下衝動畫 (動畫名稱待定)
		pass # 暫時不播放動畫，因動畫尚未完成
	
	if self.ground_slam_area:
		self.ground_slam_area.monitoring = false # 確保開始時 impact area 是禁用的
		self.ground_slam_area.monitorable = false 
		# 碰撞層設定建議在 _on_ground_impact 時或 Player 初始化時統一設定

	# print("Entering Ground Slam State") # 已在上面 print

func custom_update_ground_slam(_delta: float) -> void:
	# print("[State_GroundSlam] custom_update_ground_slam running...") # 可以保留用於調試
	
	if not player:
		# 這個檢查理論上不應該再觸發，因為 enter() 裡已經檢查過了
		print("[State_GroundSlam] custom_update_ground_slam: Player node missing!")
		return
	
	player.velocity.y = player.GROUND_SLAM_SPEED
	# var velocity_before_move = player.velocity # 用於調試
	# print("[State_GroundSlam] Velocity before move_and_slide:", velocity_before_move)
	
	player.move_and_slide()
	
	# var position_after_move = player.global_position # 用於調試
	# print("[State_GroundSlam] Position after move_and_slide:", position_after_move)
	# print("[State_GroundSlam] Velocity after move_and_slide:", player.velocity)
	
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
	
	# 確保 ground_slam_area 在使用前已被正確獲取
	if not self.ground_slam_area:
		printerr("State_GroundSlam._on_ground_impact(): ground_slam_area is null. Cannot perform impact logic.")
		return
		
	print("Ground Slam Impact!")

	if self.animated_sprite:
		# self.animated_sprite.play("ground_slam_impact") 
		pass
	if self.effect_manager:
		# self.effect_manager.play_ground_slam_effect(player.global_position)
		pass

	# 碰撞體檢測邏輯
	# 確保 ground_slam_area 的碰撞設定正確，能偵測到敵人
	self.ground_slam_area.set_collision_layer_value(1, false) 
	self.ground_slam_area.set_collision_mask_value(3, true) # 假設敵人在此層 (mask value for layer 3 is 1 << (3-1) = 4)
	
	var hit_enemies = [] 
	var overlapping_bodies = self.ground_slam_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body.is_in_group("enemy") and not hit_enemies.has(body):
			hit_enemies.append(body)
			var enemy = body as Node2D # 假設敵人是 Node2D 或其子類
			
			if not enemy: continue # 如果轉換失敗則跳過

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
	print("[State_GroundSlam] Exiting state...") # 將原來的 print 移到這裡或 enter 開頭更合適
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
