extends Node

# AudioSystem - 統一音頻播放和控制系統
# 職責：音樂播放、音效管理、音量控制

# 音頻設定
var music_volume = 1.0
var sfx_volume = 1.0

# 音頻播放器引用
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# 信號
signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)
signal audio_settings_changed

# 預載常用音效
const GAME_OVER_SOUND = "res://assets/sounds/game_over.wav"

func _init():
	add_to_group("audio_system")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready():
	name = "audio_system"
	_setup_audio_players()
	_load_audio_settings()

func _setup_audio_players():
	# 創建或獲取音頻播放器
	music_player = get_node_or_null("MusicPlayer")
	if not music_player:
		music_player = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer"
		music_player.bus = "Music"
		add_child(music_player)
	
	sfx_player = get_node_or_null("SFXPlayer")
	if not sfx_player:
		sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer"
		sfx_player.bus = "SFX"
		add_child(sfx_player)

# 音樂控制
func start_background_music():
	if music_player and music_player.stream:
		if not music_player.playing:
			music_player.play()

func stop_background_music():
	if music_player and music_player.playing:
		music_player.stop()

func pause_background_music():
	if music_player:
		music_player.stream_paused = true

func resume_background_music():
	if music_player:
		music_player.stream_paused = false

func set_background_music(music_resource: AudioStream):
	if music_player:
		var was_playing = music_player.playing
		music_player.stream = music_resource
		if was_playing:
			music_player.play()

# 音效控制
func play_sound(sound_name: String):
	if not sfx_player:
		return
		
	var sound_path = "res://assets/sounds/" + sound_name + ".wav"
	if ResourceLoader.exists(sound_path):
		var sound = load(sound_path)
		if sound is AudioStream:
			sfx_player.stream = sound
			sfx_player.play()
	else:
		print("Warning: Sound file not found: ", sound_path)

func play_game_over_sound():
	if sfx_player and ResourceLoader.exists(GAME_OVER_SOUND):
		var sound = load(GAME_OVER_SOUND)
		if sound is AudioStream:
			sfx_player.stream = sound
			sfx_player.play()

func play_sound_resource(sound_resource: AudioStream):
	if sfx_player and sound_resource:
		sfx_player.stream = sound_resource
		sfx_player.play()

# 音量控制
func set_music_volume(volume: float):
	music_volume = clamp(volume, 0, 1)
	_apply_music_volume()
	music_volume_changed.emit(music_volume)
	audio_settings_changed.emit()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0, 1)
	_apply_sfx_volume()
	sfx_volume_changed.emit(sfx_volume)
	audio_settings_changed.emit()

func _apply_music_volume():
	if music_player:
		music_player.volume_db = linear_to_db(music_volume) if music_volume > 0 else -80.0

func _apply_sfx_volume():
	if sfx_player:
		sfx_player.volume_db = linear_to_db(sfx_volume) if sfx_volume > 0 else -80.0

# 音頻總線控制
func set_master_volume(volume: float):
	var bus_index = AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamp(volume, 0, 1)))

func set_music_bus_volume(volume: float):
	var bus_index = AudioServer.get_bus_index("Music")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamp(volume, 0, 1)))

func set_sfx_bus_volume(volume: float):
	var bus_index = AudioServer.get_bus_index("SFX")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamp(volume, 0, 1)))

# 設定管理 (僅在當前會話中有效)
func get_audio_settings() -> Dictionary:
	return {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume
	}

func apply_audio_settings(settings: Dictionary):
	if settings.has("music_volume"):
		set_music_volume(settings.music_volume)
	if settings.has("sfx_volume"):
		set_sfx_volume(settings.sfx_volume)

func _load_audio_settings():
	# 每次重新開始都使用默認音頻設定
	_apply_music_volume()
	_apply_sfx_volume()

# 靜音控制
func mute_all():
	set_master_volume(0)

func unmute_all():
	set_master_volume(1.0)

func toggle_music_mute():
	if music_volume > 0:
		set_music_volume(0)
	else:
		set_music_volume(1.0)

func toggle_sfx_mute():
	if sfx_volume > 0:
		set_sfx_volume(0)
	else:
		set_sfx_volume(1.0)

# 查詢方法
func is_music_playing() -> bool:
	return music_player != null and music_player.playing

func is_music_muted() -> bool:
	return music_volume == 0

func is_sfx_muted() -> bool:
	return sfx_volume == 0

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume
