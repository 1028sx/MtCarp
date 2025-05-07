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

## 授權協議

本專案採用 MIT 授權協議。詳見 [LICENSE](LICENSE) 檔案。

## 聯絡方式

- GitHub: [@1028sx](https://github.com/1028sx)
- Discord: 613878521898598531

## 致謝

感謝所有在開發過程中提供幫助和建議的朋友。
