extends Node

# 場景管理器的基礎腳本

# 可以在這裡添加轉場效果相關的變量和節點引用
# 例如：@onready var transition_layer = $TransitionLayer # (假設你有一個CanvasLayer用於轉場)

# 當 MetroidvaniaSystem 檢測到房間改變時，會調用此函數
func _on_metsys_room_changed(new_room_path: String):
	print("[SceneManager] 收到房間切換請求: ", new_room_path)
	
	if new_room_path.is_empty():
		printerr("[SceneManager] 收到的房間路徑為空，無法切換！")
		return

	# --- 可選：開始轉場動畫 --- 
	# 例如：淡出
	# if transition_layer:
	# 	 await transition_layer.fade_out()
	# ---------------------------

	# 執行場景切換
	# 確保 new_room_path 是 Godot 可以識別的路徑 (例如 "res://scenes/rooms/Beginning2.tscn")
	var error = get_tree().change_scene_to_file(new_room_path)
	
	if error != OK:
		printerr("[SceneManager] 切換場景 '%s' 失敗，錯誤碼: %d" % [new_room_path, error])
		# 如果切換失敗，可能需要恢復轉場（如果有的話）
		# if transition_layer:
		# 	 transition_layer.fade_in() # 或者其他恢復操作
		return

	# --- 場景切換後 --- 
	# 通常切換後，新場景的 _ready 會被調用
	# 你需要在新場景的 _ready 函數中，根據需要重新放置玩家
	# (例如，根據全局變量判斷玩家是從哪個門進來的)
	
	# --- 可選：結束轉場動畫 --- 
	# 例如：淡入 (可能需要在新場景的 _ready 中觸發)
	# 或者在這裡等待一小段時間再淡入
	# await get_tree().create_timer(0.1).timeout # 給新場景一點加載時間
	# if transition_layer:
	# 	 transition_layer.fade_in()
	# ---------------------------

# 可以在這裡添加其他場景管理相關函數，例如返回主菜單、重新加載當前場景等 