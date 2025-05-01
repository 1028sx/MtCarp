# scripts/player/PlayerState.gd
class_name PlayerState
extends Node

# 讓狀態可以訪問玩家節點及其屬性
var player: CharacterBody2D
# 讓狀態可以訪問狀態機本身 (用於觸發狀態轉換)
var state_machine # PlayerStateMachine (避免循環引用，使用類型提示)

# 狀態名稱 (可選，用於調試)
var state_name := "PlayerState"


# --- 虛擬函數 (Virtual Functions) ---
# 子類別應該覆寫這些函數來實現具體狀態的邏輯

# 進入此狀態時調用一次
func enter() -> void:
	pass

# 離開此狀態時調用一次
func exit() -> void:
	pass

# 每幀處理輸入事件
# @warning_ignore("unused_parameter") # 忽略未使用的 event 參數警告
func process_input(_event: InputEvent) -> void:
	pass

# 每物理幀處理邏輯 (移動、重力等)
# @warning_ignore("unused_parameter") # 忽略未使用的 delta 參數警告
func process_physics(_delta: float) -> void:
	pass

# 每幀處理邏輯 (非物理，例如計時器)
# @warning_ignore("unused_parameter") # 忽略未使用的 delta 參數警告
func process_frame(_delta: float) -> void:
	pass

# 檢查是否需要轉換到其他狀態，如果需要，返回新的狀態實例
# 如果不需要轉換，返回 null
func get_transition() -> PlayerState:
	return null
