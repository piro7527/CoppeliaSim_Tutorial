# CoppeliaSim Tutorial 15
## パラメータスタディ：「立てる/立てない」の境界線を探る

Tutorial 14 では、物理演算とアシスト制御を組み合わせたハイブリッド制御で、安定した立ち上がりを実現しました。
今回は、完成した **`sitToStand_hybridV2.ttt`** を使い、各パラメータ（変数）を意図的に変更することで、**「ロボットが転倒する条件」や「最も効率的な動き」** を探る実験を行います。

このプロセスは、ロボット工学における「感度解析（Sensitivity Analysis）」や、リハビリテーションにおける「能力評価」に相当します。

---

## 🎯 目的
1.  **「最小アシスト力」** を見つける（自身の脚力だけでどこまで頑張れるか？）
2.  **「姿勢（前傾角度）」** と **「必要アシスト力」** のトレードオフを理解する
3.  **「動作速度」** が安定性に与える影響を確認する

---

## 1. 準備

1.  CoppeliaSim で **`sitToStand_hybridV2.ttt`** を開きます（Tutorial 14 の完成版）。
2.  スクリプトエディタで `RFoot` の子スクリプトを開きます。

---

## 2. 基準となるスクリプト (Reference Script)

実験を始める前に、**「スムーズに立てる状態」** のスクリプトを確認・コピーしてください。これが比較の基準（ベースライン）となります。

```lua
sim = require('sim')

function sysCall_init()
    rAnkle = sim.getObject(":/RAnkleJoint")
    rKnee  = sim.getObject(":/RKneeJoint")
    rHip   = sim.getObject(":/RHipJoint")
    
    -- Get Pelvis handle for applying force
    pelvis = sim.getObject(":/Pelvis")

    -- Graph setup
    graphHandle = sim.getObject(":/TorqueGraph")
    if graphHandle ~= -1 then
        torqueStreamKnee = sim.addGraphStream(graphHandle, "Knee Torque (Physics)", "N*m", 0, {1, 0, 0}) -- Red: Knee
        torqueStreamHip  = sim.addGraphStream(graphHandle, "Hip Torque (Physics)",  "N*m", 0, {1, 1, 0}) -- Yellow: Hip
    end
    
    timer = 0

    -- CSV Export
    local specificPath = "/Users/aoyamahiroki/Desktop/torque_data.csv"
    fileHandle = io.open(specificPath, "w")
    if fileHandle then
        fileHandle:write("Time,Knee_Torque,Hip_Torque\n")
    else
        print("Error: Could not open file for writing at " .. specificPath)
    end
end

function sysCall_actuation()
    dt = sim.getSimulationTimeStep()
    timer = timer + dt
    
    -- --- Timing Settings ---
    -- Sequence: Stand -> Sit -> Stand
    local t0 = 1.0  -- Start (Stand -> Crouch)
    local t1 = 2.0  -- Crouch -> Sit (Start Sitting Down)
    local t2 = 4.0  -- Sit Complete (Rest)
    local t3 = 5.5  -- Start Standing (Sit -> Lean)
    local t4 = 7.5  -- Stand Complete (Lean -> Stand)
    
    -- --- Phase Angles ---
    
    -- Standing Position
    local standAnkle = 0
    local standKnee  = 0
    local standHip   = 0

    -- Leaning Position (Crouch / Bow)
    local leanAnkle = 20 * math.pi / 180
    local leanKnee  = -55 * math.pi / 180  -- Deeper Knee Bend
    local leanHip   = 60 * math.pi / 180   -- Moderate Bow (35 deg) for natural motion
    
    -- Deep Lean (for Standing Up)
    local deepLeanAnkle = 25 * math.pi / 180
    local deepLeanKnee  = -100 * math.pi / 180 
    local deepLeanHip   = 85 * math.pi / 180 
    
    -- Sitting Position
    local sitAnkle = 0 * math.pi / 180
    local sitKnee  = -85 * math.pi / 180
    local sitHip   = 105 * math.pi / 180

    -- --- Control Calculation ---
    local targetAnkle = standAnkle
    local targetKnee  = standKnee
    local targetHip   = standHip

    if timer < t0 then
        -- [Phase 0] Stand Still (Start)
        targetAnkle = standAnkle
        targetKnee  = standKnee
        targetHip   = standHip
        
    elseif timer < t1 then
        -- [Phase 1] Stand -> Lean (Forward Weight Shift)
        local duration = t1 - t0
        local ratio = (timer - t0) / duration
        targetAnkle = (1 - ratio) * standAnkle + ratio * leanAnkle
        targetKnee  = (1 - ratio) * standKnee  + ratio * leanKnee
        targetHip   = (1 - ratio) * standHip   + ratio * leanHip
        
    elseif timer < t2 then
        -- [Phase 2] Lean -> Sit (Descending)
        local duration = t2 - t1
        local ratio = (timer - t1) / duration
        targetAnkle = (1 - ratio) * leanAnkle + ratio * sitAnkle
        targetKnee  = (1 - ratio) * leanKnee  + ratio * sitKnee
        targetHip   = (1 - ratio) * leanHip   + ratio * sitHip
        
    elseif timer < t3 then
        -- [Phase 3] Sit Rest
        targetAnkle = sitAnkle
        targetKnee  = sitKnee
        targetHip   = sitHip
        
    elseif timer < t4 then
        -- [Phase 4] Sit -> Stand (Standing Up)
        -- Combine Lean and Extension for smooth motion
        local duration = t4 - t3
        local ratio = (timer - t3) / duration
        
        -- Simplified trajectory: Sit -> DeepLean -> Stand
        if ratio < 0.5 then
            -- First half: Sit -> DeepLean
            local subRatio = ratio * 2
            targetAnkle = (1 - subRatio) * sitAnkle + subRatio * deepLeanAnkle
            targetKnee  = (1 - subRatio) * sitKnee  + subRatio * deepLeanKnee
            targetHip   = (1 - subRatio) * sitHip   + subRatio * deepLeanHip
        else
            -- Second half: DeepLean -> Stand
            local subRatio = (ratio - 0.5) * 2
            targetAnkle = (1 - subRatio) * deepLeanAnkle + subRatio * standAnkle
            targetKnee  = (1 - subRatio) * deepLeanKnee  + subRatio * standKnee
            targetHip   = (1 - subRatio) * deepLeanHip   + subRatio * standHip
        end

    else
        -- [Phase 5] Stand Complete
        targetAnkle = standAnkle
        targetKnee  = standKnee
        targetHip   = standHip
    end
    
    sim.setJointTargetPosition(rAnkle, targetAnkle)
    sim.setJointTargetPosition(rKnee, targetKnee)
    sim.setJointTargetPosition(rHip, targetHip)

    -- === Hybrid Assist Control ===

    -- 0. Initial Cushion (0.5s -> 1.0s)
    -- Apply strong but less than full weight force to allow descent but cushion impact
    if timer > 0.5 and timer < 1.0 then
        local initialCushion = {0, 0, 40} -- Reduced to 40N (Still allows falling, but softer)
        sim.addForceAndTorque(pelvis, initialCushion, {0,0,0})
    end
    
    -- 1. Sitting Cushion (Braking)
    -- Phase 2: Stand -> Sit, apply brake ONLY at the end of descent (last 0.8s)
    if timer >= (t2 - 0.8) and timer <= t2 then
        -- Apply moderate upward force (approx. 30% of body weight, ~200N)
        local cushionForce = {0, 0, 200} 
        sim.addForceAndTorque(pelvis, cushionForce, {0,0,0})
    end

    -- 2. Standing Assist
    -- Phase 4: Sit -> Stand, lift up
    if timer >= t3 and timer <= t4 then
        -- Assist with approx. 25% of body weight to stand easily
        local assistForce = {10, 0, 150} 
        sim.addForceAndTorque(pelvis, assistForce, {0,0,0})
    end
end

function sysCall_sensing()
    if graphHandle ~= -1 then
        local kneeTorque = sim.getJointForce(rKnee)
        local hipTorque  = sim.getJointForce(rHip)
        
        sim.setGraphStreamValue(graphHandle, torqueStreamKnee, kneeTorque)
        sim.setGraphStreamValue(graphHandle, torqueStreamHip, hipTorque)

        -- CSV Write
        if fileHandle then
            fileHandle:write(string.format("%.3f,%.3f,%.3f\n", timer, kneeTorque, hipTorque))
        end
    end
end

function sysCall_cleanup()
    if fileHandle then
        fileHandle:close()
        print("CSV saved to /Users/aoyamahiroki/Desktop/torque_data.csv")
    end
end
```

---

## 3. 実験 A：アシスト力の限界を探る (Force Tuning)

現在の設定では、Z方向（上向き）に **150N** の力を加えています。これは体重（約600N）の約25%です。
この値を徐々に減らしていくと、ある時点で「立ち上がれなくなる」はずです。その **限界値（Threshold）** を探ります。

### 手順
スクリプト内の以下の箇所を変更します。

```lua
-- 2. Standing Assist (Phase 4)
if timer >= t3 and timer <= t4 then
    -- Assist with approx. 25% of body weight to stand easily
    -- default: {10, 0, 150}
    local assistForce = {10, 0, 100} -- 150 -> 100 に変更してみる
    sim.addForceAndTorque(pelvis, assistForce, {0,0,0})
end
```

### 課題
1.  `100` (N) に変更して実行してください。立てますか？
2.  `50` (N) に変更して実行してください。どうなりますか？
3.  **「ギリギリ立てる最小の値（Minimum Force）」** はいくつですか？（例: 80N? 120N?）

> **考察**: アシスト力が不足すると、ロボットはどのような失敗の仕方をしますか？（後ろに倒れる？ そのまま座り込む？）

---

## 4. 実験 B：前傾角度とアシスト力の関係 (Posture vs Force)

人間は立ち上がる時、深くお辞儀（前傾）をすると楽に立てます。逆に、背筋を伸ばしたまま立つのは大変です。
ロボットでも同じことが言えるか確認します。

### 手順
スクリプト上部の `leanHip` （前傾角度）を変更します。

#### パターン1：浅い前傾（Shallow Lean）
お辞儀を浅くします。
```lua
-- Lean position parameters
local leanHip = 90 * math.pi / 180 -- Default was around 120 or 136
```
*   **結果予測**: 重心が足の上に移動しきらないため、より強いアシスト力が必要になるはずです。
*   **実験**: `leanHip = 90度` の時、実験Aで見つけた「最小アシスト力」で立ち上がれますか？ 転倒する場合、アシスト力を `200` や `250` に増やすことで解決できますか？

#### パターン2：深い前傾（Deep Lean）
お辞儀を深くします。
```lua
local leanHip = 140 * math.pi / 180
```
*   **結果予測**: 重心が足の上に乗りやすくなりますが、深く曲げすぎると前方へつんのめるリスクがあります。
*   **実験**: 前傾を深くすれば、アシスト力をさらに減らしても（例: `50` N）立てるようになりますか？

---

## 5. 実験 C：動作速度の影響 (Speed & Dynamics)

ゆっくり立つ場合と、勢いよく立つ場合の違いを見ます。

### 手順
立ち上がり動作にかかる時間（`t4 - t3`）を変更します。

```lua
-- Timing Settings
local t3 = 5.5  -- Start Standing
local t4 = 6.5  -- Stand Complete (Default was 7.5, so 2.0s duration. Change to 1.0s)
```
期間を **2.0秒** から **1.0秒** に短縮して「素早く」立ち上がらせます。

### 課題
1.  動作を速くすると、慣性力（勢い）がつきます。これは立ち上がりを助けますか？ それともバランスを崩す原因になりますか？
2.  速く動く場合、着座時の「衝撃」や、立ち上がり完了時の「揺れ」はどう変化しますか？

---

## 6. まとめ

この実験を通じて、以下の物理的な関係性を感じ取ることが重要です。

| 変数                 | 変更内容            | ロボットの挙動への影響                                             |
| :------------------- | :------------------ | :----------------------------------------------------------------- |
| **Assist Force (Z)** | **下げる**          | 脚への負担増。限界を超えると離殿できずに尻餅をつく。               |
| **Lean Angle (Hip)** | **浅くする (90°)**  | 重心移動が不十分で、後ろに倒れやすくなる。大きなアシスト力が必要。 |
| **Lean Angle (Hip)** | **深くする (140°)** | 少ない力で立てるが、勢い余って前につんのめる（Toppling）リスク増。 |
| **Speed (Duration)** | **速くする**        | 勢い（運動量）を利用できるが、制御が難しくなり振動しやすい。       |

最適なロボット制御とは、これらのパラメータの **「ちょうど良いバランス（Sweet Spot）」** を見つける作業に他なりません。
