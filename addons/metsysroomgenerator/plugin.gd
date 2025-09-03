@tool
extends EditorPlugin

## MetSys Room Generator Plugin
## 
## 高級房間生成工具，支持自動顏色檢測、TileSet自定義、房間模板等功能
## 專為 MetSys 框架設計，可獨立於專案使用

const DockUI = preload("res://addons/metsysroomgenerator/dock_ui.gd")
var dock_instance

func _enter_tree():
	# 創建停靠面板
	dock_instance = DockUI.new()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock_instance)
	print("[MetSys Room Generator] 插件已啟用")

func _exit_tree():
	# 清理資源
	if dock_instance:
		remove_control_from_docks(dock_instance)
		dock_instance.queue_free()
		dock_instance = null
	print("[MetSys Room Generator] 插件已停用")

func get_plugin_name() -> String:
	return "MetSys Room Generator"
