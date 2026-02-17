# CoppeliaSim Tutorial 14
## 物理演算 + アシスト力によるハイブリッド制御 (Hybrid Control)

Tutorial 13では、純粋な物理演算（関節トルクのみ）で立ち上がりを行いました。しかし、重心制御が非常にシビアで、「なんとか立てる」レベルの動作になりがちでした。
今回は、**物理演算を損なわない程度の補助力（Assist Force）** を計算によって加えることで、**よりスムーズで安定した、理想的な立ち上がり動作** を目指します。これはリハビリテーションロボットやパワーアシストスーツの制御に近い考え方です。

---

## 🎯 目的
1.  **「外力（External Force）」** をスクリプトから動的に加える (`sim.addForceAndTorque`)
2.  物理演算の挙動を残しつつ、不足しているトルクを補う
3.  座面からスムーズに離殿（Seat-off）し、ふらつきのない立ち上がりを実現する

---

## 1. シーンの準備

Tutorial 13 で作成した `sitToStand_physics.ttt` をベースにします。

1.  CoppeliaSim で `sitToStand_physics.ttt` を開きます。
2.  **File** > **Save Scene As...** で **`sitToStand_hybrid.ttt`** という名前で別名保存します。
    *   これで元の Tutorial 13 のファイルを上書きせずに進められます。

---

## 2. アシスト力の設計 (Concept)

立ち上がり動作で最も強い力が必要なのは、**「離殿（Seat-off）」から「伸展（Extension）」にかけての瞬間**です。
この瞬間に、お尻（Pelvis）を斜め前上に持ち上げるような力を加えます。

### 必要な力
*   **方向**: 重力に逆らう「上方向(+Z)」と、重心を前に送る「前方向(+X)」の合成ベクトル
*   **大きさ**: 体重（約60kg = 600N）の全てを支えるのではなく、**20〜30%程度**（120N〜180N）を補助します。残りの70%は自身の脚力（関節トルク）で支えます。
*   **タイミング**: 動作中のみ（Phase 1 〜 Phase 2）加えます。
*   **追加補正**: 開始から約0.7秒後に着座衝撃（ドスン）が発生するため、その直前にも上方向の力を加えて衝撃を緩和します。

---

## 3. スクリプトの実装
`RFoot` の子スクリプトを開き、以下のように修正・追記します。
**「直立 → 着座 → 立ち上がり（Stand -> Sit -> Stand）」** の一連の動作を行います。

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
    local leanKnee  = -50 * math.pi / 180  -- Deeper Knee Bend
    local leanHip   = 45 * math.pi / 180   -- Deep Bow (45 deg) as requested
    
    -- Deep Lean (for Standing Up)
    local deepLeanAnkle = 25 * math.pi / 180
    local deepLeanKnee  = -100 * math.pi / 180 
    local deepLeanHip   = 120 * math.pi / 180 
    
    -- Sitting Position
    local sitAnkle = 0 * math.pi / 180
    local sitKnee  = -85 * math.pi / 180 -- User optimized for 0.45m chair
    local sitHip   = 95 * math.pi / 180  -- User optimized for stability

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

## 4. パラメータの調整 (Tuning)

シミュレーションを実行し、挙動を見ながら `force` の値を調整します。

### 調整の指針
1.  **立ち上がれずに座り込んでしまう場合**:
    *   **Z成分（上向き）** を増やします（例: `150` -> `200`）。
    *   過剰すぎると体が宙に浮いてしまうので注意してください。
2.  **後ろに倒れる場合**:
    *   **X成分（前向き）** を増やします（例: `30` -> `50`）。
    *   重心を強制的に前に押し出します。
3.  **前につんのめる場合**:
    *   X成分を減らします。物理演算（Tutorial 13）の「前傾動作」が十分機能している証拠です。

### 推奨値の例（体重60kgモデルの場合）
| 項目        | 値 (N)        | 役割                                                                                                                                           |
| :---------- | :------------ | :--------------------------------------------------------------------------------------------------------------------------------------------- |
| **Force X** | **0 ~ 20**    | **重要**: Tutorial 13で既に立てている場合、この値は **0** にしてください。足しても倒れるだけです。<br>重心移動が足りない場合のみ少し足します。 |
| **Force Z** | **100 ~ 200** | 重力補償。お尻を持ち上げる主役です。                                                                                                           |

### 重要な調整テクニック：動作を自然にする
アシストがあるということは、**「無理な前傾（深いお辞儀）」をしなくても立てる** ということです。
もし「前につんのめる」場合は、アシスト力を減らすのではなく、**前傾角度（leanHip）を浅く** してみてください。

```lua
local leanHip = 120 * math.pi / 180 -- Shallower than Tutorial 13 (136 deg) is OK!
```
これにより、**「極端なお辞儀をせず、スマートにスッと立つ」** という、より自然な人間らしい動作が実現できます。これがハイブリッド制御の真のメリットです。

---

## 5. 結果の比較

Tutorial 13 (Physics only) と比較して：
1.  **動作の滑らかさ**: ガクガクせず、スムーズに立てるようになったか？
2.  **成功率**: 何回やっても安定して立てるか？
3.  **関節トルク**: グラフ（赤線・黄線）のピーク値が下がっているか確認してください。アシスト力が負荷の一部を肩代わりしているため、ロボット自身の負担（必要トルク）は減るはずです。

これが確認できれば、**「人間と機械（アシスト）の協調動作」** のシミュレーション成功です！

---

## 6. サンプルファイルについて
本チュートリアルに関連するファイルの違いは以下の通りです：
*   **`sitToStand_hybrid.ttt`**: 角度調整**未**のもの（スクリプト実装直後の状態）
*   **`sitToStand_hybridV2.ttt`**: 角度調整**済**のもの（パラメータ調整後の最終版）
