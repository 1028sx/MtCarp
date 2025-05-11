# 敦煌

一款以敦煌為主題的2D動作遊戲，使用 Godot 4.3.stable.official [77dcf97d8] 開發。

## 遊戲特色

- 精美的2D像素風格美術
- 流暢的動作戰鬥系統
- 豐富的敵人種類
- 獨特的敦煌文化元素

## 操作方式

- AD：移動
- 滑鼠左鍵：普通攻擊
- E：特殊攻擊
- Space：跳躍
- Shift：衝刺
- Q：開啟物品欄
- Esc：暫停選單

## 系統需求

- 作業系統：Windows 10/11
- 處理器：1.5 GHz 或更快
- 記憶體：2 GB RAM
- 顯示卡：支援 OpenGL 3.3
- 儲存空間：500 MB 可用空間

## 安裝說明

1. 下載最新版本的遊戲
2. 解壓縮檔案
3. 執行 DunHuang.exe

## 開發工具

* Godot 4.3.stable.official [77dcf97d8]
* Visual Studio Code（程式碼編輯器）
* Git（版本控制）
* **Metroidvania System (by KoBeWi)**：用於地圖設計、導航和物件持久化。(<https://github.com/KoBeWi/Metroidvania-System>) (使用與 Godot 4.3 相容的版本，例如 v1.4)

### 版本控制 (Git)

本專案使用 Git 進行版本控制，並託管於 GitHub。

*   **倉庫地址：** [https://github.com/1028sx/MtCarp](https://github.com/1028sx/MtCarp)
*   **主要分支：** `main`

**將目前內容推送到 GitHub 的步驟：**

1.  **新增所有變更到暫存區：**
    ```bash
    git add .
    ```
    此指令會將您在專案中所做的所有修改（新增、刪除、編輯檔案）準備好進行提交。

2.  **提交變更到本地倉庫：**
    ```bash
    git commit -m "更新專案內容並補充README中的GitHub推送指南"
    ```
    (您可以將引號內的訊息替換成您認為更合適的描述)

3.  **推送到 GitHub 遠端倉庫：**
    ```bash
    git push origin main
    ```
    此指令會將您本地的 `main` 分支上的提交推送到 GitHub 上的 `origin` 遠端倉庫。

**備註：**
*   執行這些指令前，請確保您已在終端機或命令提示字元中，切換到專案的根目錄 (`/c%3A/Users/sx102/Godot_v4.3-stable_win64.exe/project/mt.carp/`)。
*   根據您的描述，Git 遠端倉庫 `origin` 和主要分支 `main` 應該已經正確設定。如果推送時遇到問題，可能需要檢查遠端設定 (`git remote -v`) 或使用 `git push -u origin main` (特別是如果這是此分支的首次推送或需要明確設定上游追蹤)。

## 版本歷史

### v1.0.0（2024-01）
- 初始發布

- 基礎戰鬥系統
- 基礎文字欄系統
- 4種敵人類型

## Boss 系統

遊戲中的 Boss 戰是玩家旅程中的重要里程碑。每個 Boss 都有獨特的機制和戰鬥風格。

### 計劃開發的 Boss
- [待填充]

## 授權協議

本專案採用 MIT 授權協議。詳見 [LICENSE](LICENSE) 檔案。

## 聯絡方式

- GitHub: [@1028sx](https://github.com/1028sx)
- Discord: 613878521898598531

## 致謝

感謝所有在開發過程中提供幫助和建議的朋友。

## 常見問題與解決方案

### UI 顯示問題

#### Boss 血條不顯示

如果 Boss 血條不顯示但 Boss 已正確載入，可能存在以下問題：

1. **節點路徑錯誤**：確保 Boss UI 場景中包含正確的節點層次結構，特別是 `Control_BossHUD` 和 `TextureProgressBar_BossHP` 兩個關鍵節點。

2. **加載順序問題**：確保在初始化 BossUI 時，先將其添加到場景樹，然後再嘗試獲取其子節點。

3. **診斷方法**：
   - 添加更多日誌輸出來識別問題
   - 使用 `_debug_print_scene_tree()` 函數打印完整場景樹
   - 檢查 `boss` 分組中的節點是否正確添加
   - 檢查信號連接是否成功

4. **解決方案**：
   ```gdscript
   # 在 Main.gd 中正確加載 BossUI
   var boss_ui = boss_ui_scene.instantiate()
   add_child(boss_ui)  # 先添加到場景
   await get_tree().process_frame  # 等待一幀確保節點已添加
   
   # 然後檢查節點結構
   var control_hud = boss_ui.get_node_or_null("Control_BossHUD")
   if not control_hud:
       push_error("BossUI 結構錯誤，缺少 Control_BossHUD 節點")
   ```

5. **修復策略**：如檢測到 BossUI 結構有問題，可以嘗試移除並重新創建：
   ```gdscript
   boss_ui.queue_free()
   await get_tree().process_frame
   boss_ui = boss_ui_scene.instantiate()
   add_child(boss_ui)
   ```

#### 其他 UI 不顯示問題

類似的問題可能出現在其他 UI 元素中，一般原則是：

1. 確保節點層次結構正確
2. 確保在訪問節點前已將其添加到場景樹
3. 使用 `get_node_or_null()` 進行防禦性編程
4. 添加足夠的診斷日誌
5. 考慮節點加載的順序和時機

### 信號連接問題

如果遇到信號連接問題，例如 Boss 無法向 UI 發送信號：

1. 檢查信號是否正確定義（名稱拼寫）
2. 確保信號接收方已正確添加到場景樹
3. 檢查接收方是否已添加到正確的分組（例如 "boss_ui" 組）
4. 使用 `call_deferred()` 延遲執行信號連接，確保兩個節點都已就緒

```gdscript
# 在 deer.gd 中確保自己被添加到正確的組
func _ready():
    if not is_in_group("boss"):
        add_to_group("boss")
    # ...其他初始化代碼
```

## 節點結構與常見問題

### 關於自動加載 (Autoload) 的重要提示

在本專案中，`BossUI`必須是`Main`節點的子節點，而不應該被配置為自動加載。如果您的Boss UI不顯示或行為異常，請檢查以下事項：

1. **檢查`project.godot`文件**：確保`BossUI`不在`[autoload]`部分內列出。
   - 錯誤配置示例：
   ```
   [autoload]
   BossUI="*res://scenes/enemies/boss_ui.tscn"
   ```
   - 如發現此設定，請將其移除並重新加載專案

2. **正確的節點層次結構**：
   ```
   Main
   ├── Player
   ├── EnemyManager
   ├── ItemManager
   ├── BossUI  <-- 應該在此層級
   │   └── Control_BossHUD
   │       └── TextureProgressBar_BossHP
   └── ...
   ```

3. **初始化順序**：確保先將`BossUI`添加到場景樹，再嘗試訪問其子節點：
   ```gdscript
   var boss_ui = boss_ui_scene.instantiate()
   add_child(boss_ui)  # 先添加到場景
   await get_tree().process_frame  # 等待處理
   # 然後再存取子節點
   var control_hud = boss_ui.get_node_or_null("Control_BossHUD")
   ```

### 如何診斷和修復UI問題

當遇到UI顯示問題時：

1. **查看控制台日誌**：尋找類似這樣的錯誤：
   ```
   [BossUI] 錯誤：找不到Control_BossHUD節點！
   [BossUI] 錯誤：BossUI是root的子節點，這表示它被設置為autoload！
   ```

2. **執行修復**：
   - 首先檢查`project.godot`中是否有`BossUI`的自動加載配置並移除它
   - 如果運行時遇到問題，代碼已包含自動修復機制，會移除錯誤的實例並創建正確的
   - 重啟遊戲後問題應解決

### 其他常見UI問題

1. **信號連接問題**：確保`Boss`節點已添加到"boss"組，並發送正確的信號：
   ```gdscript
   # 在Boss的_ready()中：
   if not is_in_group("boss"):
       add_to_group("boss")
   ```

2. **父節點錯誤**：所有UI組件都應有正確的父節點關係，避免在場景樹中出現多個實例
