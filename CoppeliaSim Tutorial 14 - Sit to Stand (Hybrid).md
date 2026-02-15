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

---

## 3. スクリプトの実装

`RFoot` の子スクリプトを開き、以下のように修正・追記します。
`sysCall_init` で `Pelvis` オブジェクトを取得し、`sysCall_sensing`（または `actuation`）で力を加えます。

### 3-1. オブジェクトの取得
`sim.getObject` で `Pelvis` ハンドルを取得します。

```lua
function sysCall_init()
    -- ... (既存のコード) ...
    rHip   = sim.getObject(":/RHipJoint")
    
    -- 【追加】力を加える対象（骨盤）を取得
    pelvis = sim.getObject(":/Pelvis")
    
    -- ... (グラフ・CSV設定など) ...
end
```

### 3-2. アシスト力の実装

`sysCall_sensing` 内ではなく、**`sysCall_actuation` の最後** に実装するのが最も効果的です。

```lua
function sysCall_actuation()
    -- ... (既存の角度計算・関節制御など) ...
    -- sim.setJointTargetPosition(...) のあと
    
    -- === Assist Force Control (Tutorial 14) ===
    
    -- 力を加えるタイミング: Phase 1 (前傾) 〜 Phase 2 (伸展)
    if timer >= t0 and timer <= t2 then
        
        -- アシスト力のベクトル (World座標系)
        -- X方向: 前に押し出す力 (例: 30N)
        -- Z方向: 上に持ち上げる力 (例: 150N, 体重の約25%)
        local force = {30, 0, 150} 
        
        -- トルクは加えない (回転は関節に任せる)
        local torque = {0, 0, 0}
        
        -- 力を適用 (重心位置に作用)
        sim.addForceAndTorque(pelvis, force, torque)
        
        -- ※ デバッグ用: 力を加えている間、コンソールに表示
        -- print(string.format("Assisting... Time: %.2f", timer))
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
local leanHip = 120 * math.pi / 180 -- Tutorial 13 (136度) より浅くてOK！
```
これにより、**「極端なお辞儀をせず、スマートにスッと立つ」** という、より自然な人間らしい動作が実現できます。これがハイブリッド制御の真のメリットです。

---

## 5. 結果の比較

Tutorial 13 (Physics only) と比較して：
1.  **動作の滑らかさ**: ガクガクせず、スムーズに立てるようになったか？
2.  **成功率**: 何回やっても安定して立てるか？
3.  **関節トルク**: グラフ（赤線・黄線）のピーク値が下がっているか確認してください。アシスト力が負荷の一部を肩代わりしているため、ロボット自身の負担（必要トルク）は減るはずです。


これが必要ですが、**「人間と機械（アシスト）の協調動作」** のシミュレーション成功です！

---

## 6. 着座動作の実装 (Stand-to-Sit)

立ち上がりだけでなく、**「座る動作」** もスムーズに行います。
何も制御しないと、重力に負けて「ドスン」と椅子に落ちてしまいます。これもアシスト力（ブレーキ）で解決します。

### 6-1. スクリプトの全容（Stand-to-Sit 追加版）
以下のスクリプトに置き換えてください。`Phase 3` 以降に「座る動作」を追加しています。

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
    
    -- --- Timing Settings (seconds) ---
    local t0 = 1.0  -- Start (Sit -> Lean)
    local t1 = 2.0  -- Lean -> Stand
    local t2 = 4.0  -- Stand Complete
    local t3 = 6.0  -- Start Sitting Down (Stand -> Lean)
    local t4 = 8.0  -- Sit Complete (Lean -> Sit)

    -- --- Phase Angles ---
    
    -- Initial Position (Sitting)
    local sitAnkle = 0 * math.pi / 180
    local sitKnee  = -90 * math.pi / 180
    local sitHip   = 90 * math.pi / 180
    
    -- Leaning Position
    local leanAnkle = 25 * math.pi / 180  -- 浅めの足首 (Assisted)
    local leanKnee  = -100 * math.pi / 180 
    local leanHip   = 120 * math.pi / 180 -- 浅めの前傾 (Assisted)
    
    -- Standing Position
    local standAnkle = 0
    local standKnee  = 0
    local standHip   = 0

    -- --- Control Calculation ---
    local targetAnkle = sitAnkle
    local targetKnee  = sitKnee
    local targetHip   = sitHip

    if timer < t0 then
        -- [Phase 0] Stabilization
        targetAnkle = sitAnkle
        targetKnee  = sitKnee
        targetHip   = sitHip
        
    elseif timer < t1 then
        -- [Phase 1] Sit -> Lean
        local duration = t1 - t0
        local ratio = (timer - t0) / duration
        targetAnkle = (1 - ratio) * sitAnkle + ratio * leanAnkle
        targetKnee  = (1 - ratio) * sitKnee  + ratio * leanKnee
        targetHip   = (1 - ratio) * sitHip   + ratio * leanHip
        
    elseif timer < t2 then
        -- [Phase 2] Lean -> Stand
        local duration = t2 - t1
        local ratio = (timer - t1) / duration
        targetAnkle = (1 - ratio) * leanAnkle + ratio * standAnkle
        targetKnee  = (1 - ratio) * leanKnee  + ratio * standKnee
        targetHip   = (1 - ratio) * leanHip   + ratio * standHip
        
    elseif timer < t3 then
        -- [Phase 3] Standing Maintain
        targetAnkle = standAnkle
        targetKnee  = standKnee
        targetHip   = standHip

    elseif timer < t4 then
        -- [Phase 4] Stand -> Sit (Reverse)
        -- ゆっくりと元の座り姿勢に戻ります
        local duration = t4 - t3
        local ratio = (timer - t3) / duration
        
        -- 逆再生: Stand -> Lean -> Sit (途中省略で直接Sitへ戻る簡易版)
        targetAnkle = (1 - ratio) * standAnkle + ratio * sitAnkle
        targetKnee  = (1 - ratio) * standKnee  + ratio * sitKnee
        targetHip   = (1 - ratio) * standHip   + ratio * sitHip
        
    else
        -- [Phase 5] Sit Complete
        targetAnkle = sitAnkle
        targetKnee  = sitKnee
        targetHip   = sitHip
    end
    
    sim.setJointTargetPosition(rAnkle, targetAnkle)
    sim.setJointTargetPosition(rKnee, targetKnee)
    sim.setJointTargetPosition(rHip, targetHip)

    -- === Hybrid Assist Control ===
    
    -- 1. Standing Assist (立ち上がり補助)
    if timer >= t0 and timer <= t2 then
        -- 上方向への持ち上げ
        local force = {10, 0, 150} 
        sim.addForceAndTorque(pelvis, force, {0,0,0})
    end

    -- 2. Sitting Cushion (着座ブレーキ)
    -- ここが「ドスン」を防ぐ重要ポイントです
    if timer >= t3 and timer <= t4 then
        
        -- 重力（下向き）に逆らう強い上向きの力（ブレーキ）を加えます
        -- 体重の約60-80%程度 (350N - 450N)
        -- これが無いと自由落下に近い状態で椅子に衝突します
        local cushionForce = {0, 0, 350} 
        
        sim.addForceAndTorque(pelvis, cushionForce, {0,0,0})
    end
end

function sysCall_sensing()
    if graphHandle ~= -1 then
        local kneeTorque = sim.getJointForce(rKnee)
        local hipTorque  = sim.getJointForce(rHip)
        
        sim.setGraphStreamValue(graphHandle, torqueStreamKnee, kneeTorque)
        sim.setGraphStreamValue(graphHandle, torqueStreamHip, hipTorque)

        if fileHandle then
            fileHandle:write(string.format("%.3f,%.3f,%.3f\n", timer, kneeTorque, hipTorque))
        end
    end
end

function sysCall_cleanup()
    if fileHandle then
        fileHandle:close()
        print("CSV saved.")
    end
end
```
