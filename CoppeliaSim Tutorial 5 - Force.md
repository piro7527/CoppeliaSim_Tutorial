# CoppeliaSim Tutorial 5
## 外力（Force）を加える：押して倒す

Tutorial 4ではモーターで関節を「内部から」動かしましたが、今回は**外部から力を加えて**物体を動かす方法を学びます。
これがGoalで目指す「外力負荷シミュレーション」の基礎になります。

---

## 🎯 目的
- **外力（External Force）** をオブジェクトに適用する方法を理解する
- **Luaスクリプト** を使って力を動的に制御する
- 力の **大きさ・方向・作用点** を変えて挙動の違いを観察する

---

## 🛠 使用環境
- CoppeliaSim（Bullet 物理エンジン）
- **前提**: Tutorial 1〜4 を完了していること

---

## 1. シーンの準備

今回は新しいシンプルなシーンを作ります（振り子より分かりやすいため）。

### 1.1 新規シーンを作成
1. **File → New scene**

### 1.2 床を追加
1. **Add → Primitive shape → Plane**
2. サイズ: X=2, Y=2 に設定
3. ☑️ **Create respondable shape** にチェック（物体が床で止まるため）
4. Scene hierarchy で名前を `Floor` に変更
5. Position を確認: X=0, Y=0, **Z=0** になっていることを確認

> ⚠️ **注意**: 床は **Dynamic にしない**でください（Dynamicにすると床自体が落下します）
> 💡 Plane は厚みがないため、Z=0 のままで問題ありません。

### 1.3 ターゲット（押される物体）を追加
1. **Add → Primitive shape → Cuboid**
2. サイズ: X=0.1, Y=0.1, Z=0.3（縦長の直方体）
3. ☑️ **Create dynamic and respondable shape** にチェック
4. 位置を調整: **X=0, Y=0, Z=0.15**（床の中央に立つように）
5. Scene hierarchy で名前を `Target` に変更

### 1.4 シミュレーションテスト
1. ▶️ **Start simulation**
2. `Target` が床の上に安定して立っていればOK
3. ⏹️ **Stop simulation**

---

## 2. 外力を加えるスクリプトを作成

### 2.1 スクリプトを追加
1. Scene hierarchy で **`Target`** を右クリック
2. **Add → Script → Simulation script → Non-threaded → Lua**

> 💡 **Non-threaded vs Threaded**: Non-threaded はシミュレーションのメインループと同期して実行されます。今回のような単純な力の適用には Non-threaded が適しています。

### 2.2 スクリプトを編集
1. 追加されたスクリプトをダブルクリックして開く
2. 以下のコードに **置き換え** る：

```lua
function sysCall_init()
    -- オブジェクト自身のハンドルを取得
    targetHandle = sim.getObject('.')
    
    -- 力を加えるまでの待機時間（秒）
    forceDelay = 1.0
    
    -- 力を加えたかどうかのフラグ
    forceApplied = false
    
    print("=== Force Demo Ready ===")
end

function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    -- 1秒後に力を加える（1回だけ）
    if t >= forceDelay and not forceApplied then
        -- 力のベクトル [X, Y, Z] （ニュートン）
        local force = {5, 0, 0}  -- X方向に5Nの力
        
        -- 力の作用点（オブジェクト中心からの相対位置）
        local position = {0, 0, 0.1}  -- 上部に力を加える
        
        -- 力を適用
        sim.addForce(targetHandle, position, force)
        
        forceApplied = true
        print(string.format("Force applied at t=%.2f sec: [%.1f, %.1f, %.1f] N", 
              t, force[1], force[2], force[3]))
    end
end
```

### 2.3 コードの解説

| 関数/変数                          | 説明                                           |
| ---------------------------------- | ---------------------------------------------- |
| `sim.getObject('.')`               | 自分自身（Targetオブジェクト）のハンドルを取得 |
| `sim.getSimulationTime()`          | シミュレーション開始からの経過時間（秒）       |
| `sim.addForce(handle, pos, force)` | 指定オブジェクトに力を加える                   |
| `force = {5, 0, 0}`                | X方向に5ニュートンの力                         |
| `position = {0, 0, 0.1}`           | オブジェクト中心より0.1m上に作用点             |

---

## 3. シミュレーション実行

1. ▶️ **Start simulation**
2. 1秒後に `Target` が **パタン！** と倒れるはずです
3. コンソールに `Force applied at t=1.00 sec: [5.0, 0.0, 0.0] N` と表示されます

> 💡 **観察ポイント**: 上部（Z=0.1）に力を加えているので、回転しながら倒れます。これが「モーメント（回転力）」の効果です。

---

## 4. 実験：パラメータを変えてみよう

### 実験1: 力の大きさを変える
```lua
local force = {1, 0, 0}   -- 弱い力（揺れるだけ？）
local force = {10, 0, 0}  -- 強い力（吹っ飛ぶ）
local force = {50, 0, 0}  -- もっと強い力
```

### 実験2: 力の方向を変える
```lua
local force = {0, 5, 0}   -- Y方向（横）に押す
local force = {0, 0, 10}  -- Z方向（上）に持ち上げる
local force = {5, 5, 0}   -- 斜め方向
```

### 実験3: 作用点を変える
```lua
local position = {0, 0, 0}     -- 重心に力を加える（倒れにくい）
local position = {0, 0, 0.15}  -- 最上部（最も倒れやすい）
local position = {0, 0, -0.1}  -- 下部（倒れにくい）
```

> 🧪 **考察**: 同じ大きさの力でも、作用点が高いほど倒れやすいことを確認してください。これは理学療法で「重心より高い位置に外乱を加えると姿勢崩壊しやすい」という臨床知見と一致します。

---

## 5. 応用：継続的に力を加える

1回だけでなく、一定時間力を加え続けるパターンも試してみましょう。

```lua
function sysCall_init()
    targetHandle = sim.getObject('.')
    forceStartTime = 1.0   -- 力を加え始める時間
    forceDuration = 0.5    -- 力を加え続ける時間（0.5秒間）
    print("=== Continuous Force Demo ===")
end

function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    -- 1.0秒〜1.5秒の間、力を加え続ける
    if t >= forceStartTime and t < forceStartTime + forceDuration then
        local force = {3, 0, 0}  -- 弱めの力を継続的に
        local position = {0, 0, 0.1}
        sim.addForce(targetHandle, position, force)
    end
end
```

> 💡 **理学療法との関連**: これは「介助者がゆっくり押す」場合と「瞬間的に外乱が加わる」場合の違いをシミュレートできます。

---

## 6. シーンを保存

1. **File → Save scene as...**
2. ファイル名: `force_demo.ttt`

---

## 🔧 トラブルシューティング

| 症状                       | チェック項目                                                                     |
| -------------------------- | -------------------------------------------------------------------------------- |
| **何も起きない**           | スクリプトが正しく追加されていますか？`sysCall_actuation` は毎フレーム呼ばれます |
| **エラーが出る**           | `sim.addForce` の引数は `(handle, {x,y,z}, {fx,fy,fz})` の順です                 |
| **オブジェクトが動かない** | `Create dynamic` にチェックを入れましたか？静的オブジェクトには力が効きません    |
| **床をすり抜ける**         | `Create respondable` にチェックを入れましたか？                                  |

---

## 📐 物理的な補足

### sim.addForce vs sim.addForceAndTorque
- `sim.addForce`: 特定の位置に力を加える（自動的にトルクも発生）
- `sim.addForceAndTorque`: 力とトルクを個別に指定

### 単位について
- 力: ニュートン (N)
- 位置: メートル (m)
- 質量: キログラム (kg) ← デフォルトでオブジェクトには質量が設定されています

---

## 🚀 次へのステップ

これで「外力を加える」基礎ができました！

次のチュートリアルでは、この技術を発展させて：
- **複数のリンクを持つモデル** に外力を加える
- **転倒を検知するセンサー** を追加する
- **力の大きさをリアルタイムに変化させる** UI を作る

などに挑戦していきます。

---

## 📝 復習問題

1. `sim.addForce` の3つの引数は何ですか？
2. 作用点を重心より上にすると、なぜ倒れやすくなりますか？
3. 力を1回だけ加える場合と、継続的に加える場合で、コードはどう違いますか？
