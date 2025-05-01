extends Node2D

signal effect_finished

@onready var cast_effect = $CastEffect  # GPUParticles2D
@onready var bullet_wave_effect = $BulletWaveEffect  # AnimatedSprite2D
@onready var summon_effect = $SummonEffect  # AnimatedSprite2D
@onready var shield_effect = $ShieldEffect  # AnimatedSprite2D

func _ready():
	_initialize_effects()

func _initialize_effects():
	_setup_bullet_wave_effect()
	_setup_summon_effect()
	_setup_cast_effect()
	_setup_shield_effect()

func _setup_bullet_wave_effect():
	if bullet_wave_effect:
		bullet_wave_effect.visible = false
		if not bullet_wave_effect.animation_finished.is_connected(_on_bullet_wave_finished):
			bullet_wave_effect.animation_finished.connect(_on_bullet_wave_finished)
		bullet_wave_effect.frame = 0
		bullet_wave_effect.speed_scale = 1.0
		bullet_wave_effect.modulate.a = 0.8
		bullet_wave_effect.z_index = -1

func _setup_summon_effect():
	if summon_effect:
		summon_effect.visible = false
		summon_effect.animation_finished.connect(_on_summon_finished)
		summon_effect.frame = 0
		summon_effect.speed_scale = 1.0
		summon_effect.modulate.a = 0.8
		summon_effect.z_index = -1

func _setup_cast_effect():
	if cast_effect:
		cast_effect.emitting = false
		cast_effect.one_shot = false
		cast_effect.explosiveness = 0.2
		cast_effect.randomness = 0.5
		cast_effect.z_index = 1

func _setup_shield_effect():
	if shield_effect:
		shield_effect.visible = false
		shield_effect.z_index = 2

func play_cast_effect():
	if cast_effect:
		cast_effect.restart()
		cast_effect.emitting = true
		await get_tree().create_timer(1.0).timeout
		cast_effect.emitting = false
		effect_finished.emit()

func play_bullet_wave_effect():
	if bullet_wave_effect:
		bullet_wave_effect.show()
		bullet_wave_effect.frame = 0
		
		var anim_name = "default"
		if bullet_wave_effect.sprite_frames and bullet_wave_effect.sprite_frames.has_animation(anim_name):
			bullet_wave_effect.play(anim_name)
		else:
			effect_finished.emit()

func _on_bullet_wave_finished():
	if bullet_wave_effect:
		bullet_wave_effect.stop()
		bullet_wave_effect.hide()
		effect_finished.emit()

func play_summon_effect():
	if summon_effect:
		summon_effect.show()
		summon_effect.frame = 0
		summon_effect.play("default", 1.0)

func _on_summon_finished():
	if summon_effect:
		summon_effect.stop()
		summon_effect.hide()
		effect_finished.emit()

func play_shield_effect():
	if shield_effect:
		shield_effect.visible = true
		shield_effect.play("default")

func stop_shield_effect():
	if shield_effect:
		shield_effect.stop()
		shield_effect.visible = false 
