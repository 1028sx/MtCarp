extends Area2D

var damage: float = 0.0

# 玩家攻擊區域腳本
# 作用：為 Area2D 節點添加 damage 屬性，讓攻擊系統能夠儲存和傳遞傷害值
# 必要性：PlayerAttackState 和其他攻擊相關腳本依賴此屬性進行傷害計算
# 不可移除：移除此腳本會導致所有攻擊功能崩潰
