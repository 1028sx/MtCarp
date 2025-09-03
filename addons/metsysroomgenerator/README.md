# MetSys Room Generator 2.0

## ⚠️ 當前狀態：開發暫停

**部分功能可用 - 房間生成功能暫時停用**

## 🎯 工具概述

MetSys Room Generator 是一個為 Godot 4.3 設計的編輯器插件，專為 MetSys 框架開發。目前插件的配置和分析功能完全可用，但由於技術問題，核心房間生成功能暫時不可用。

### ✨ 主要功能

- 🔍 **自動顏色檢測** - 掃描 MapData.txt 並自動識別所有顏色區域
- 🎨 **可視化配置** - 直觀的 UI 配置每個顏色區域的名稱、資料夾和前綴
- 🏠 **智能編號** - 自動分配連續房間編號，避免衝突
- 🎯 **TileSet 整合** - 支持自定義 TileSet 和瓦片選擇
- 🏗️ **房間模板** - 可自定義房間模板和包含的節點
- 📊 **實時預覽** - 生成前完整預覽將要創建的房間
- ⚙️ **本地化配置** - 所有配置保存在工具目錄，不影響專案結構

> **注意**：目前由於 Godot 4.3 插件環境的 GDScript 載入問題，房間生成功能暫時停用。配置和預覽功能完全可用。技術問題詳情請查看 `TECHNICAL_ISSUES.md`。

## 🚀 安裝步驟

### 1. 複製工具
將整個 `MetSysRoomGenerator` 資料夾複製到目標專案的 `addons/` 目錄：
```
your_project/
└── addons/
    └── MetSysRoomGenerator/
        ├── plugin.cfg
        ├── plugin.gd
        ├── dock_ui.gd
        └── ...其他文件
```

### 2. 啟用插件
1. 在 Godot 編輯器中打開專案
2. 進入 **專案 > 專案設定 > 插件**
3. 找到 "MetSys Room Generator" 並啟用
4. 工具面板將出現在左側停靠區域

## 📖 使用指南

### 步驟 1: 配置 MapData 路徑
1. 在 "📁 MapData 配置" 區域輸入 MapData.txt 的路徑
2. 默認路徑: `res://scenes/rooms/MapData.txt`
3. 點擊 "🔍 掃描顏色" 按鈕

### 步驟 2: 配置區域設定
掃描完成後，"🎨 區域配置" 區域將顯示所有檢測到的顏色：
- **區域名稱**: 如 "Beginning", "Jungle"
- **資料夾名稱**: 如 "beginning", "jungle"  
- **房間前綴**: 如 "Beginning", "Jungle"

每個顏色都會顯示：
- 顏色預覽方塊
- 房間數量 (如 "x5" 表示 5 個房間)
- 自動建議的名稱（可編輯）

### 步驟 3: 設定 TileSet（可選）
1. 在 "🎯 TileSet 配置" 區域選擇 TileSet 資源
2. 選擇要使用的瓦片 ID
3. 如果不設定，將使用基本方塊房模式

### 步驟 4: 設定房間模板（可選）
1. 在 "🏠 房間模板" 區域選擇房間模板場景
2. 模板場景應包含您希望每個房間都有的基礎節點

### 步驟 5: 生成房間
1. 點擊 "👁️ 預覽" 查看將要生成的房間清單
2. 確認無誤後，點擊 "🏗️ 生成房間"
3. 觀察進度和日誌輸出

## 🎨 顏色代碼對應

工具已預設以下顏色映射：

| 顏色代碼 | 區域名稱 | 資料夾 | 前綴 | 預覽顏色 |
|----------|----------|--------|------|----------|
| `24d6da,,,,` | Beginning | beginning | Beginning | 青藍色 |
| `4be021,,,,` | Jungle | jungle | Jungle | 綠色 |
| `e4b015,,,,` | Fortress | fortress | Fortress | 金黃色 |
| `e04a21,,,,` | Village | village | Village | 紅色 |
| `8b15e4,,,,` | Mountain | mountain | Mountain | 紫色 |

## 🔧 配置文件

工具會自動創建配置文件：
- `config.json` - 用戶當前配置
- `examples/default_config.json` - 默認配置範例

### 配置文件結構
```json
{
  "mapdata_path": "res://scenes/rooms/MapData.txt",
  "color_mappings": {
    "24d6da,,,,": {
      "area_name": "Beginning",
      "folder": "beginning", 
      "prefix": "Beginning"
    }
  },
  "tileset_path": "",
  "selected_tiles": [0, 1, 2, 3],
  "room_template": "",
  "included_nodes": ["RoomInstance", "DeathZone"],
  "generation_settings": {
    "create_spawn_points": true,
    "create_room_boundaries": true,
    "tile_size": 32
  }
}
```

## 📁 生成結果

生成的房間文件將保存在對應資料夾：
```
scenes/rooms/
├── beginning/
│   ├── Beginning1.tscn (已存在)
│   ├── Beginning2.tscn (已存在) 
│   ├── Beginning4.tscn (新生成)
│   └── Beginning5.tscn (新生成)
├── jungle/
│   ├── Jungle1.tscn (新生成)
│   └── Jungle2.tscn (新生成)
└── ...其他區域
```

## 🔄 與現有工具的遷移

如果您之前使用舊版房間生成工具，可以：
1. 備份現有的房間文件
2. 安裝新插件
3. 使用相同的 MapData.txt
4. 工具會自動跳過已存在的房間，只生成新房間

## 🛠️ 自定義和擴展

### 添加新顏色區域
1. 在 MapData.txt 中使用新的顏色代碼
2. 工具會自動檢測並允許您配置

### 自定義 TileSet
1. 創建您的 TileSet 資源
2. 在工具中選擇該 TileSet
3. 選擇要使用的瓦片 ID

### 房間模板
1. 創建一個包含基礎節點的場景（如 RoomInstance、DeathZone）
2. 將其另存為 .tscn 文件
3. 在工具中選擇該模板

## 💡 最佳實踐

1. **生成前備份** - 始終備份現有的房間文件
2. **測試小範圍** - 先在小範圍測試工具效果
3. **檢查結果** - 生成後檢查房間文件是否符合預期
4. **使用版本控制** - 使用 Git 追蹤變更
5. **保持配置** - 工具會記住您的設定，無需重複配置

## 🚨 注意事項

- 該工具會直接創建和修改文件，請務必備份
- 所有配置文件都保存在工具目錄內，不會污染專案結構
- 工具專為 MetSys 框架設計，需要正確的 MapData.txt 格式
- 建議在 Godot 4.3 或更高版本中使用

## 📞 技術支持

如需技術支持：
1. 檢查日誌區域的錯誤信息
2. 確保 MapData.txt 格式正確
3. 確認 Godot 版本兼容性
4. 檢查文件路徑和權限

---

**MetSys Room Generator 2.0** - 讓房間生成變得簡單而強大！