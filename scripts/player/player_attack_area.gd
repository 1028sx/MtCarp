extends Area2D

var damage: float = 0.0  # 儲存這次攻擊的傷害值

# 你可以選擇性地添加一個方法來獲取攻擊數據，如果 Boss.gd 要使用 get_attack_data()
# func get_attack_data() -> Dictionary:
#     return {"damage": damage, "knockback_scalar": 100.0} # 假設也傳遞一些擊退信息
