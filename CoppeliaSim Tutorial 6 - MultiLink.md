# CoppeliaSim Tutorial 6
## 複数リンクモデルへの外力適用：2リンクアーム

Tutorial 5では単一の物体に外力を加えましたが、今回は**複数のパーツがジョイントで連結されたモデル**に外力を加える方法を学びます。
これは人体の関節運動や、歩行器使用時の外乱応答など、より実践的なシミュレーションの基礎になります。

---

## 🎯 目的
- **複数リンク（マルチボディ）モデル** を作成する方法を理解する
- 特定のリンクに**選択的に外力を加える**
- 力が**関節を通じて伝播する**様子を観察する
- 臨床的な外乱シミュレーションの基礎を習得する

---

## 🛠 使用環境
- CoppeliaSim（Bullet 物理エンジン）
- **前提**: Tutorial 1〜5 を完了していること

---

## 1. シーンの準備

今回作成するのは「床に固定された2リンクアーム」です。

```
[固定台] --- (肩関節) --- [上腕] --- (肘関節) --- [前腕]
```

### 1.1 新規シーンを作成
1. **File → New scene**

### 1.2 床について
新規シーンには既に `Floor` が存在します。以下のどちらかを選んでください：

**オプションA: 既存のFloorをそのまま使う**（推奨）
- デフォルトの `Floor` はすでに静的で衝突判定もあるので、そのまま使えます
- 何もせず次のステップへ進んでOK

**オプションB: 新しい床を作り直す場合**
1. Scene hierarchy で既存の `Floor` を右クリック → **Delete**
2. **Add → Primitive shape → Plane**
3. サイズ: X=2, Y=2
4. ☐ **Dynamic and respondable** は **チェックしない**
5. 名前を `Floor` に変更
6. Position: X=0, Y=0, Z=0

---

## 2. 固定台（BaseBlock）を作成

アームの土台となる部分を作ります。これは**静的オブジェクト**（動かない）です。

### 2.1 形状を追加
1. **Add → Primitive shape → Cuboid**
2. サイズ: X=0.15, Y=0.15, Z=0.3
3. ☐ **Dynamic and respondable** は **チェックしない**
4. 名前を `BaseBlock` に変更
5. Position: X=0, Y=0, Z=0.15
6. Orientation: Alpha=0, Beta=0, Gamma=0

### 2.2 色を変更
1. **Adjust color** → グレー（例: 0.5, 0.5, 0.5）

---

## 3. 設定一覧（クイックリファレンス）

以下の表に従って各オブジェクトを作成してください：

| オブジェクト  | サイズ         | Position (X, Y, Z) | Orientation (α, β, γ) | Dynamic      | 質量   |
| ------------- | -------------- | ------------------ | --------------------- | ------------ | ------ |
| BaseBlock     | 0.15×0.15×0.3  | 0, 0, 0.15         | 0, 0, 0               | ☐ NO         | -      |
| ShoulderJoint | -              | 0, 0, 0.30         | **90**, 0, 0          | Dynamic/Free | -      |
| UpperArm      | 0.05×0.05×0.2  | 0, 0, 0.20         | **90**, 0, 0          | ☑ YES        | 0.1kg  |
| ElbowJoint    | -              | 0, 0, 0.10         | **90**, 0, 0          | Dynamic/Free | -      |
| ForeArm       | 0.04×0.04×0.15 | 0, 0, 0.025        | **90**, 0, 0          | ☑ YES        | 0.05kg |

> 💡 **ポイント**: すべてのジョイントとアームは **Alpha=90** で統一。アームは垂直方向に垂れ下がります。

---

## 4. 上腕（UpperArm）を作成

### 4.1 形状を追加
1. **Add → Primitive shape → Cuboid**
2. サイズ: X=0.05, Y=0.05, Z=0.2
3. ☑️ **Create dynamic and respondable shape** にチェック
4. 名前を `UpperArm` に変更
5. Position: **X=0, Y=0, Z=0.20**
6. Orientation: **Alpha=90, Beta=0, Gamma=0**

### 4.2 質量を設定
1. **Dynamic properties dialog** → **Mass** を **0.1** kg に設定

### 4.3 色を変更
1. **Adjust color** → 青色（例: 0.2, 0.4, 0.8）

---

## 5. 肩関節（ShoulderJoint）を作成

### 5.1 ジョイントを追加
1. **Add → Joint → Revolute**
2. 名前を `ShoulderJoint` に変更
3. Position: **X=0, Y=0, Z=0.30**（BaseBlockの上端）
4. Orientation: **Alpha=90, Beta=0, Gamma=0**
   > 💡 Alpha=90 でY軸まわりに回転。アームが重力で垂れ下がります。

### 5.2 ジョイントのモードを設定
1. **Mode**: **Dynamic mode**
2. **Dynamic properties dialog** → **Control mode**: **Free**

### 5.3 階層を構築
```
BaseBlock
└── ShoulderJoint
    └── UpperArm
```

---

## 6. 前腕（ForeArm）を作成

### 6.1 形状を追加
1. **Add → Primitive shape → Cuboid**
2. サイズ: X=0.04, Y=0.04, Z=0.15
3. ☑️ **Create dynamic and respondable shape** にチェック
4. 名前を `ForeArm` に変更
5. Position: **X=0, Y=0, Z=0.025**
6. Orientation: **Alpha=90, Beta=0, Gamma=0**

### 6.2 質量を設定
1. **Mass** を **0.05** kg に設定

### 6.3 色を変更
1. **Adjust color** → 赤色（例: 0.8, 0.2, 0.2）

---

## 7. 肘関節（ElbowJoint）を作成

### 7.1 ジョイントを追加
1. **Add → Joint → Revolute**
2. 名前を `ElbowJoint` に変更
3. Position: **X=0, Y=0, Z=0.10**（UpperArmの下端）
4. Orientation: **Alpha=90, Beta=0, Gamma=0**

### 7.2 ジョイントのモードを設定
1. **Mode**: **Dynamic mode**
2. **Control mode**: **Free**

### 7.3 最終的な階層構造
```
Floor
BaseBlock
└── ShoulderJoint
    └── UpperArm
        └── ElbowJoint
            └── ForeArm
```

---

## 8. シミュレーションテスト

### 8.1 重力テスト
1. ▶️ **Start simulation**
2. アームが重力で垂れ下がり、揺れながら静止するはずです
3. ⏹️ **Stop simulation**

> 💡 **うまくいかない場合**:
> - ジョイントが正しい位置にあるか確認
> - 階層構造が正しいか確認
> - Dynamicプロパティが有効か確認

---

## 8. 外力を加えるスクリプト

前腕（ForeArm）に外力を加えて、アーム全体の応答を観察します。

### 8.1 スクリプトを追加
1. Scene hierarchy で **`ForeArm`** を右クリック
2. **Add → Script → Simulation script → Non-threaded → Lua**

### 8.2 スクリプトを編集

```lua
function sysCall_init()
    -- Get object handles
    foreArmHandle = sim.getObject('..')  -- Parent object (ForeArm)
    
    -- Configuration
    forceDelay = 1.5        -- When to apply force
    forceApplied = false
    
    -- Force parameters
    forceMagnitude = 2.0    -- Newton (smaller force for lighter arm)
    
    print("=== 2-Link Arm Force Demo Ready ===")
    print("Force will be applied to ForeArm at t=" .. forceDelay .. "s")
end

function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    if t >= forceDelay and not forceApplied then
        -- Apply force to the tip of ForeArm
        -- Force direction: X+ (horizontal push)
        local force = {forceMagnitude, 0, 0}
        
        -- Position: tip of ForeArm (relative to center)
        -- ForeArm length is 0.15m, so tip is at z=+0.075
        local position = {0, 0, 0.075}
        
        sim.addForce(foreArmHandle, position, force)
        
        forceApplied = true
        print(string.format("Force [%.1f, 0, 0] N applied to ForeArm tip at t=%.2f s", 
              forceMagnitude, t))
    end
end
```

### 8.3 コードの解説

| 変数/関数                  | 説明                                      |
| -------------------------- | ----------------------------------------- |
| `foreArmHandle`            | ForeArmオブジェクトのハンドル             |
| `forceMagnitude = 2.0`     | 2ニュートンの力（軽いアームなので小さめ） |
| `position = {0, 0, 0.075}` | ForeArmの先端に力を加える                 |

---

## 9. シミュレーション実行と観察

### 9.1 実行手順
1. 🐇 **Real-time mode** をONに
2. ▶️ **Start simulation**
3. 1.5秒後に前腕の先端に力が加わります
4. **観察ポイント**:
   - 前腕だけでなく、**上腕も連動して動く**
   - **両方のジョイント（肩と肘）が回転する**
   - 揺れながら徐々に減衰していく

> 🧪 **観察**: これが「多リンク系の力の伝播」です。末端に力を加えると、ジョイントを通じて全体に影響が波及します。

---

## 10. 実験：異なるリンクに力を加える

### 実験1: 上腕に力を加える

UpperArmにもスクリプトを追加して、上腕に力を加えてみましょう。

1. `UpperArm` に新しいスクリプトを追加
2. 以下のコードを使用：

```lua
function sysCall_init()
    upperArmHandle = sim.getObject('..')
    forceDelay = 1.5
    forceApplied = false
    print("=== UpperArm Force Script Ready ===")
end

function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    if t >= forceDelay and not forceApplied then
        -- Apply force to UpperArm center
        local force = {3, 0, 0}  -- Stronger force for heavier arm
        local position = {0, 0, 0}  -- Center of UpperArm
        
        sim.addForce(upperArmHandle, position, force)
        
        forceApplied = true
        print("Force applied to UpperArm at t=" .. t)
    end
end
```

> 💡 **比較ポイント**: 上腕に力を加えた場合と、前腕に力を加えた場合で、動きがどう違うか観察してください。

### 実験2: 複数のリンクに同時に力を加える
両方のスクリプトを有効にして実行すると、複数の力が同時に作用する様子を観察できます。

---

## 11. 応用：継続的な力を加える

Tutorial 5で学んだ継続的な力を、このマルチリンクモデルにも適用できます。

ForeArmのスクリプトを以下に置き換えてみましょう：

```lua
function sysCall_init()
    foreArmHandle = sim.getObject('..')
    
    -- Continuous force parameters
    startTime = 1.0
    duration = 2.0
    
    print("=== Continuous Force Demo ===")
    print("Force will be applied from t=" .. startTime .. "s for " .. duration .. "s")
end

function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    -- Apply continuous force during the specified time window
    if t >= startTime and t < startTime + duration then
        -- Gentle continuous push
        local force = {0.5, 0, 0}  -- Small force applied every frame
        local position = {0, 0, 0.075}  -- Tip of ForeArm
        
        sim.addForce(foreArmHandle, position, force)
    end
end
```

> 💡 **理学療法との関連**: これは「介助者が一定の力で押し続ける」状況をシミュレートしています。たとえば、立位で肩を一定時間押され続けた場合の姿勢応答などに応用できます。

---

## 12. シーンを保存

1. **File → Save scene as...**
2. ファイル名: `two_link_arm.ttt`

---

## 🔧 トラブルシューティング

| 症状                       | チェック項目                                               |
| -------------------------- | ---------------------------------------------------------- |
| **アームが落下してしまう** | BaseBlockは `Dynamic` を無効にしていますか？               |
| **ジョイントが動かない**   | ジョイントの Mode が `Dynamic` になっていますか？          |
| **階層が正しくない**       | Scene hierarchy で親子関係を確認してください               |
| **力が効かない**           | オブジェクトの `Dynamic` が有効か確認してください          |
| **動きが激しすぎる**       | 質量(Mass)を増やすか、力(forceMagnitude)を減らしてください |
| **すぐに止まってしまう**   | ジョイントの **Damping** が大きすぎる可能性があります      |

---

## 📐 物理的な補足

### 多リンク系の特徴

| 概念                 | 説明                                     | 臨床例                   |
| -------------------- | ---------------------------------------- | ------------------------ |
| **連鎖反応**         | 1箇所に力を加えると、全リンクに影響      | 転倒時の連鎖的な関節運動 |
| **モーメントアーム** | 作用点が回転軸から遠いほど、大きな回転力 | リーチ動作時の肩への負荷 |
| **慣性モーメント**   | 末端ほど振り回されやすい                 | 歩行時の下肢スイング     |

### 位置計算のコツ

各リンクの配置位置を計算するには：
- 各リンクの**中心位置**を考える
- ジョイントは**リンクの接続点（境界）**に配置

```
例: BaseBlock(高さ0.3, 中心Z=0.15) 
    → 上端 Z=0.3
    → ShoulderJoint Z=0.3
    → UpperArm(高さ0.2) 中心 Z=0.4 (0.3 + 0.2/2)
    → 上端 Z=0.5
    → ElbowJoint Z=0.5
    → ForeArm(高さ0.15) 中心 Z=0.575 (0.5 + 0.15/2)
```

---

## 🚀 次へのステップ

これで「複数リンクモデルへの外力適用」の基礎ができました！

次のチュートリアルでは：
- **転倒を検知するセンサー** を追加する
- **力の大きさをリアルタイムに変化させる** UI を作る
- より複雑な**人体モデル**へと発展させる

などに挑戦していきます。

---

## 📝 復習問題

1. 多リンクモデルで、末端に力を加えると、他のリンクはどうなりますか？
2. ジョイントの位置を決めるときに注意すべきことは何ですか？
3. BaseBlockを `Dynamic` にするとどうなりますか？なぜそうなりますか？
4. 上腕に力を加えた場合と、前腕に力を加えた場合で、動きはどう違いますか？
