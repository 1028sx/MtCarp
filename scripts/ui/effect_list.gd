extends Control

@onready var effect_container = $VBoxContainer

# 效果圖標預製體
const EFFECT_BUTTON_SCENE = preload("res://scenes/ui/effect_button.tscn")

# 效果圖標和描述的映射
const EFFECT_DATA = {
	"life_steal": {
		"name": "汲取",
		"icon": preload("res://assets/icons/life_steal.png"),
		"description": "最大生命值減少，但每次攻擊恢復生命值"
	},
	"multi_strike": {
		"name": "連擊",
		"icon": preload("res://assets/icons/multi_strike.png"),
		"description": "特殊攻擊的攻擊次數增加，每次傷害遞增"
	},
	"berserker": {
		"name": "嗜血",
		"icon": preload("res://assets/icons/berserker.png"),
		"description": "生命值越低，移動和攻擊速度越快"
	},
	"dash_wave": {
		"name": "波動",
		"icon": preload("res://assets/icons/dash_wave.png"),
		"description": "衝刺攻擊時產生傷害波動，能大幅擊退敵人"
	},
	"jump_impact": {
		"name": "爆震",
		"icon": preload("res://assets/icons/jump_impact.png"),
		"description": "跳躍時產生傷害衝擊波，並且連續跳躍次數增加"
	},
	"swift_dash": {
		"name": "疾風",
		"icon": preload("res://assets/icons/swift_dash.png"),
		"description": "衝刺冷卻時間大幅減少，同時衝刺距離增加"
	},
	"ice_freeze": {
		"name": "冰結",
		"icon": preload("res://assets/icons/ice_freeze.png"),
		"description": "每五秒能使用一次冰結攻擊，對敵人造成冰凍效果"
	},
	"rage": {
		"name": "憤怒",
		"icon": preload("res://assets/icons/rage.png"),
		"description": "每次受傷增加攻擊力，但一段時間沒被攻擊會減少"
	},
	"agile": {
		"name": "靈巧",
		"icon": preload("res://assets/icons/agile.png"),
		"description": "完美迴避時下次攻擊傷害翻倍"
	},
	"focus": {
		"name": "專注",
		"icon": preload("res://assets/icons/focus.png"),
		"description": "連續命中同一敵人時提升傷害"
	},
	"harvest": {
		"name": "收割",
		"icon": preload("res://assets/icons/harvest.png"),
		"description": "以特殊攻擊擊殺敵人回復最大生命值"
	},
	"thorns": {
		"name": "荊棘",
		"icon": preload("res://assets/icons/thorns.png"),
		"description": "攻擊力降低但最大生命值增加，受傷時能反彈傷害"
	},
	"agile_dash": {
		"name": "敏捷",
		"icon": preload("res://assets/icons/agile_dash.png"),
		"description": "衝刺後的三次攻擊速度提升，並具有衝刺攻擊的傷害加成"
	}
}

func _ready() -> void:
	# 設置容器的對齊方式
	effect_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	effect_container.add_theme_constant_override("separation", 5)
	
	# 如果在主選單中，不要設置任何東西
	if get_tree().current_scene.name == "MainMenu":
		hide()
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		return
	
	# 監聽玩家效果變化
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.connect("effect_changed", _on_player_effect_changed)

# 當玩家效果改變時更新顯示
func _on_player_effect_changed(effects: Dictionary) -> void:
	# 如果在主選單中，不要更新
	if get_tree().current_scene.name == "MainMenu":
		return
		
	# 清空現有效果
	for child in effect_container.get_children():
		child.queue_free()
	
	# 添加新效果
	for effect_name in effects:
		if effect_name in EFFECT_DATA:
			var effect_button = EFFECT_BUTTON_SCENE.instantiate()
			effect_container.add_child(effect_button)
			
			# 設置效果按鈕
			effect_button.setup({
				"name": EFFECT_DATA[effect_name].name,
				"description": EFFECT_DATA[effect_name].description,
				"icon": EFFECT_DATA[effect_name].icon
			})

func _input(_event: InputEvent) -> void:
	# 檢查是否在主選單或轉場中
	if get_tree().current_scene.name == "MainMenu" or get_tree().paused:
		return
	
	# 其他輸入處理...
