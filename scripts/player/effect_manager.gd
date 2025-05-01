extends Node2D

#region 信號
signal effect_finished
#endregion

#region 節點引用
@onready var double_jump_effect = $DoubleJumpEffect
@onready var dash_effect = $DashEffect
@onready var charge_effect = $ChargeEffect
@onready var charge_complete_effect = $ChargeCompleteEffect
@onready var heal_effect = $HealEffect
#endregion

#region 常量
const EFFECT_COLOR = Color(0.8, 0.6, 0.2, 0.8)
const EFFECT_Z_INDEX = 1
const CHARGE_INTERVAL = 2.0
const INITIAL_DELAY = 0.5
const CHARGE_COMPLETE_SCALE = 2.0
#endregion

#region 變量
var charge_timer := 0.0
var initial_delay_timer := 0.0
var is_charging := false
var current_charge_multiplier := 1.0
#endregion

#region 生命週期函數
func _ready() -> void:
	_initialize_effects()

func _process(delta: float) -> void:
	if is_charging:
		if initial_delay_timer < INITIAL_DELAY:
			initial_delay_timer += delta
			return
			
		charge_timer += delta
		if charge_timer >= CHARGE_INTERVAL:
			charge_timer = 0.0
			var player = get_parent()
			if player and player.charge_damage_multiplier < (1.0 + player.max_charge_bonus):
				play_charge_effect()
#endregion

#region 初始化
func _initialize_effects() -> void:
	_setup_effect(double_jump_effect)
	_setup_effect(dash_effect)
	_setup_effect(charge_effect)
	_setup_effect(charge_complete_effect)
	_setup_effect(heal_effect)
	_connect_signals()

func _setup_effect(effect: AnimatedSprite2D) -> void:
	if effect:
		effect.visible = false
		if effect != charge_effect and effect != heal_effect:
			effect.modulate = EFFECT_COLOR
		effect.z_index = EFFECT_Z_INDEX

func _connect_signals() -> void:
	if double_jump_effect and not double_jump_effect.animation_finished.is_connected(_on_animation_finished):
		double_jump_effect.animation_finished.connect(_on_animation_finished)
	
	if dash_effect and not dash_effect.animation_finished.is_connected(_on_animation_finished):
		dash_effect.animation_finished.connect(_on_animation_finished)
		
	if charge_effect and not charge_effect.animation_finished.is_connected(_on_animation_finished):
		charge_effect.animation_finished.connect(_on_animation_finished)
		
	if charge_complete_effect and not charge_complete_effect.animation_finished.is_connected(_on_animation_finished):
		charge_complete_effect.animation_finished.connect(_on_animation_finished)
		
	if heal_effect and not heal_effect.animation_finished.is_connected(_on_animation_finished):
		heal_effect.animation_finished.connect(_on_animation_finished)
#endregion

#region 特效播放
func play_double_jump(flip_h: bool = false) -> void:
	if not double_jump_effect:
		return
	
	var effect_instance = _create_effect_instance(double_jump_effect)
	_setup_effect_instance(effect_instance, flip_h)
	
	var effect_position = global_position
	effect_position.y += 80
	effect_instance.global_position = effect_position
	
	var player = get_parent()
	if player and player.has_jump_impact:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		
		var start_scale = Vector2(0.5, 0.5)
		var max_scale = Vector2(1.5, 1.5)
		var max_distance = 60.0
		
		effect_instance.scale = start_scale
		
		tween.tween_property(effect_instance, "scale", max_scale, 0.8)
		tween.tween_property(effect_instance, "global_position:y", effect_position.y + max_distance, 1.5)
	else:
		effect_instance.scale = Vector2(1.0, 1.0)
	
	_play_effect_animation(effect_instance, "smoke")

func play_dash(flip_h: bool = false) -> void:
	if not dash_effect:
		return
	
	var effect_instance = _create_effect_instance(dash_effect)
	_setup_effect_instance(effect_instance, flip_h)
	
	var effect_position = global_position
	effect_position.x += -30
	effect_position.y += 80
	effect_instance.global_position = effect_position
	
	_play_effect_animation(effect_instance, "dash")

func play_charge_effect(charge_multiplier: float = 1.0) -> void:
	if not charge_effect:
		return
	
	var effect_instance = _create_effect_instance(charge_effect)
	_setup_effect_instance(effect_instance, false)
	
	effect_instance.global_position = global_position
	var scale_multiplier = 1.0
	if charge_multiplier >= 3.0:
		scale_multiplier = 1.5  # 3倍時使用更大的特效
	effect_instance.scale = Vector2.ONE * scale_multiplier
	
	_play_effect_animation(effect_instance, "default")

func play_charge_complete_effect() -> void:
	if not charge_complete_effect:
		return
	
	var effect_instance = _create_effect_instance(charge_complete_effect)
	_setup_effect_instance(effect_instance, false)
	
	effect_instance.global_position = global_position
	effect_instance.scale = Vector2.ONE * CHARGE_COMPLETE_SCALE
	effect_instance.modulate = Color.WHITE  # 重置為原始顏色
	
	_play_effect_animation(effect_instance, "default")

func play_heal_effect() -> void:
	if not heal_effect:
		return
		
	var effect_instance = _create_effect_instance(heal_effect)
	if not effect_instance:
		return
		
	_setup_effect_instance(effect_instance, false)
	
	# 設置特效位置（在玩家中心位置）
	var effect_position = global_position
	effect_instance.global_position = effect_position
	
	# 確保特效可見性和 Z 索引
	effect_instance.visible = true
	effect_instance.z_index = EFFECT_Z_INDEX
	
	# 播放動畫
	if effect_instance.sprite_frames and effect_instance.sprite_frames.has_animation("HealEffect"):
		_play_effect_animation(effect_instance, "HealEffect")
#endregion

#region 輔助函數
func _create_effect_instance(effect: AnimatedSprite2D) -> AnimatedSprite2D:
	var instance = effect.duplicate()
	get_parent().add_child(instance)
	return instance

func _setup_effect_instance(instance: AnimatedSprite2D, flip_h: bool) -> void:
	# 基本設置
	instance.visible = true
	instance.z_index = EFFECT_Z_INDEX
	instance.flip_h = flip_h
	
	# 只對跳躍和衝刺特效進行調整
	if instance.sprite_frames == double_jump_effect.sprite_frames or instance.sprite_frames == dash_effect.sprite_frames:
		instance.modulate = EFFECT_COLOR

func _play_effect_animation(instance: AnimatedSprite2D, anim_name: String) -> void:
	if instance.sprite_frames and instance.sprite_frames.has_animation(anim_name):
		instance.speed_scale = 1.0
		instance.play(anim_name)
		instance.animation_finished.connect(
			func(): _cleanup_effect_instance(instance)
		)

func _cleanup_effect_instance(effect_instance: AnimatedSprite2D) -> void:
	effect_instance.queue_free()
	effect_finished.emit()
#endregion

#region 狀態控制
func stop_charge_effect() -> void:
	is_charging = false
	charge_timer = 0.0
	initial_delay_timer = 0.0
	current_charge_multiplier = 1.0
	
	if charge_effect:
		charge_effect.stop()
		charge_effect.visible = false
	if charge_complete_effect:
		charge_complete_effect.stop()
		charge_complete_effect.visible = false

func _on_animation_finished() -> void:
	if double_jump_effect:
		double_jump_effect.stop()
		double_jump_effect.visible = false
	if dash_effect:
		dash_effect.stop()
		dash_effect.visible = false
	if charge_effect:
		charge_effect.stop()
		charge_effect.visible = false
	if charge_complete_effect:
		charge_complete_effect.stop()
		charge_complete_effect.visible = false
	if heal_effect:
		heal_effect.stop()
		heal_effect.visible = false
#endregion
