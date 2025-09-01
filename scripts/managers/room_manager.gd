# RoomManager兼容層 - 所有功能由MetSys處理
extends Node

static var instance: Node = null

static func get_instance() -> Node:
	if instance == null:
		push_error("[RoomManager] 錯誤：實例不存在")
	return instance

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if instance == null:
		instance = self
		add_to_group("persistent")
	else:
		call_deferred("queue_free")
		return

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null

func get_current_room() -> String:
	return MetSys.get_current_room_name()

func get_room_type(_room: String) -> String:
	# 所有房間類型現在由MetSys管理
	return "normal"