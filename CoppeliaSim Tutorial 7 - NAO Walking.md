# CoppeliaSim Tutorial 7
## NAO ロボットに歩行中の外力を加える

これまでのチュートリアルでは自分でモデルを作成しましたが、今回は **CoppeliaSim に付属している人型ロボット「NAO」** を使います。
NAO には既に歩行スクリプトが組み込まれているため、歩行制御を自分で作る必要はありません。

---

## 🎯 目的
- **Model Browser** から既存モデルを読み込む方法を学ぶ
- 複雑なモデルの **階層構造** を理解する
- 歩行中のロボットに **外力を加える** 実験を行う
- 骨盤（胴体）への外力が歩行にどう影響するか観察する

---

## 🛠 使用環境
- CoppeliaSim（Bullet 物理エンジン）
- **前提**: Tutorial 1〜6 を完了していること

---

## 1. NAO モデルを読み込む

### 1.1 新規シーンを作成
1. **File → New scene**

### 1.2 Model Browser を開く
1. メニューから **View → Model browser** を選択（または左側のパネルが既に表示されている場合はそのまま）
2. Model browser パネルが表示される

### 1.3 NAO を探す
1. Model browser で以下のフォルダを展開：
   ```
   robots → mobile → NAO
   ```
2. **NAO.ttm** をシーンにドラッグ＆ドロップ
3. NAO がシーンに配置される

> 💡 **確認**: Scene hierarchy に `NAO` とその子オブジェクトが大量に追加されていることを確認してください。

---

## 2. NAO の構造を観察する

### 2.1 階層構造を展開
1. Scene hierarchy で `NAO` の **▶** をクリックして展開
2. さらに子オブジェクトも展開していく

### 2.2 主要な部位を確認

NAO は多くのパーツで構成されています。主要な部位：

| 部位名                       | 説明                                      |
| ---------------------------- | ----------------------------------------- |
| `NAO`                        | ルートオブジェクト                        |
| `NAO_Torso` または類似名     | **胴体（骨盤相当）** ← ここに外力を加える |
| `NAO_LHip*`, `NAO_RHip*`     | 股関節                                    |
| `NAO_LKnee*`, `NAO_RKnee*`   | 膝関節                                    |
| `NAO_LAnkle*`, `NAO_RAnkle*` | 足首関節                                  |

> 💡 **ポイント**: 実際の名前はバージョンによって異なる場合があります。胴体にあたる部分を探してください。

### 2.3 胴体を特定する
1. 各オブジェクトをクリックすると、シーン内でハイライトされる
2. **胴体（体の中心部分）** にあたるオブジェクトを見つけてメモしておく
3. 通常は `Torso` や `Body` といった名前が含まれる

---

## 3. 歩行を確認する

### 3.1 シミュレーション実行
1. 🐇 **Real-time mode** をONに
2. ▶️ **Start simulation**
3. NAO が **自動的に歩き始める** はずです
4. しばらく観察してから ⏹️ **Stop simulation**

> ⚠️ **歩かない場合**: NAO のスクリプトが有効か確認してください。Scene hierarchy で NAO の下にあるスクリプトアイコン（📜）が有効になっているか確認。

---

## 4. 胴体に外力スクリプトを追加

### 4.1 胴体オブジェクトを確認
1. セクション 2.3 で特定した胴体オブジェクトを選択
2. そのオブジェクトの **正確な名前** を確認（例: `NAO_Torso`）

### 4.2 スクリプトを追加
1. 胴体オブジェクトを右クリック
2. **Add → Script → Simulation script → Non-threaded → Lua**

### 4.3 スクリプトを編集

以下のコードを入力します。`/NAO_Torso` の部分は、実際の胴体オブジェクト名に合わせて変更してください：

```lua
function sysCall_init()
    -- Find the torso object
    -- Change the name if your NAO has a different torso name
    torsoHandle = sim.getObject('/NAO/torso_respondable')
    
    -- If not found, try alternative names
    if torsoHandle == -1 then
        torsoHandle = sim.getObject('/NAO/NAO_Torso')
    end
    
    forceDelay = 3.0        -- Wait for NAO to start walking
    forceDuration = 0.5     -- Apply force for 0.5 seconds
    forceMagnitude = 20.0   -- Force in Newtons (NAO is heavier than our simple models)
    forceStarted = false
    forceEnded = false
    
    print("=== NAO Walking Force Demo Ready ===")
    print("Force will be applied at t=" .. forceDelay .. " seconds")
end

function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    -- Apply force during the specified period
    if t >= forceDelay and t < forceDelay + forceDuration then
        if not forceStarted then
            forceStarted = true
            print("Force started!")
        end
        
        -- Push sideways (Y direction) to disturb balance
        local force = {0, forceMagnitude, 0}
        local position = {0, 0, 0}  -- Center of torso
        
        sim.addForce(torsoHandle, position, force)
        
    elseif t >= forceDelay + forceDuration and not forceEnded then
        forceEnded = true
        print("Force ended!")
    end
end
```

### 4.4 コードの解説

| 変数/設定                        | 説明                                        |
| -------------------------------- | ------------------------------------------- |
| `forceDelay = 3.0`               | 3秒後に力を加え始める（歩行が安定してから） |
| `forceDuration = 0.5`            | 0.5秒間力を加え続ける                       |
| `forceMagnitude = 20.0`          | 20ニュートン（NAO は重いので大きめ）        |
| `force = {0, forceMagnitude, 0}` | Y方向（横）に押す                           |

---

## 5. シミュレーション実行と観察

### 5.1 実行手順
1. 🐇 **Real-time mode** をONに
2. ▶️ **Start simulation**
3. NAO が歩き始める
4. **3秒後** に横から押される
5. NAO の反応を観察

### 5.2 観察ポイント

- [ ] 押されたとき、ふらつくか？
- [ ] 転倒するか？それとも立て直すか？
- [ ] 歩行パターンは乱れるか？

---

## 6. 実験：パラメータを変えてみる

### 実験1: 力の大きさを変える
```lua
forceMagnitude = 10.0   -- 弱い力（ふらつく程度？）
forceMagnitude = 30.0   -- 強い力（転倒？）
forceMagnitude = 50.0   -- もっと強い力
```

### 実験2: 力の方向を変える
```lua
local force = {forceMagnitude, 0, 0}   -- 前後方向に押す
local force = {0, forceMagnitude, 0}   -- 横方向に押す
local force = {-forceMagnitude, 0, 0}  -- 後ろから押す
```

### 実験3: 力を加えるタイミングを変える
```lua
forceDelay = 1.0   -- 歩き始め直後
forceDelay = 5.0   -- 安定して歩いている最中
```

> 🧪 **考察**: どの条件で最も転倒しやすいですか？歩行のどのフェーズ（片脚支持期 vs 両脚支持期）で押すと不安定になりやすいですか？

---

## 7. トラブルシューティング

| 症状                                 | チェック項目                                       |
| ------------------------------------ | -------------------------------------------------- |
| **NAO が歩かない**                   | NAO のスクリプトが有効になっているか確認           |
| **オブジェクトが見つからないエラー** | 胴体の名前が正しいか確認（Scene hierarchy で確認） |
| **力が効かない**                     | `forceMagnitude` を大きくしてみる（NAO は重い）    |
| **すぐに転倒する**                   | `forceMagnitude` を小さくする                      |

### 胴体オブジェクト名の確認方法
1. Scene hierarchy で NAO を展開
2. 胴体にあたる部分をクリック
3. シーン内でハイライトされることを確認
4. そのオブジェクト名をスクリプト内で使用

---

## 8. シーンを保存

1. **File → Save scene as...**
2. ファイル名: `NAO_force_demo.ttt`

---

## 📐 物理的な補足

### NAO vs 自作モデルの違い

| 項目         | 2リンクアーム（Tutorial 6） | NAO                |
| ------------ | --------------------------- | ------------------ |
| ジョイント数 | 2個                         | 20個以上           |
| 制御         | なし（自由落下）            | 歩行制御スクリプト |
| 質量         | 0.15kg程度                  | 5kg程度            |
| 必要な外力   | 2〜5N                       | 10〜50N            |

### 歩行中の外乱と姿勢制御
- NAO の歩行スクリプトには**バランス制御**が含まれている
- 小さな外乱は自動的に補正される
- 大きな外乱は補正しきれず転倒する
- この「閾値」を探ることが研究的に意味がある

---

## 🚀 次へのステップ

これで「既存モデルを使った外力実験」ができるようになりました！

次のチュートリアルでは：
- **外力の大きさと転倒確率の関係** をデータとして記録
- **関節トルクのログ取得** で定量評価
- **簡易二足立位モデル** を自作して比較

などに挑戦していきます。

---

## 📝 復習問題

1. Model Browser からモデルを読み込む手順は？
2. NAO の胴体オブジェクトを特定する方法は？
3. Tutorial 6 の2リンクアームと比べて、NAO に必要な外力が大きいのはなぜ？
4. 歩行中のどのタイミングで外力を加えると最も不安定になると思いますか？
