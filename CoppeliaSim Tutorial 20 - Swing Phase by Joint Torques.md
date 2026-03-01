# CoppeliaSim Tutorial 20
## 介助力適用前の関節トルクによる遊脚再現（フィードフォワードトルク制御）

Tutorial 9 では、**外部から骨盤を引っ張る力（介助力）** によって脚を揺らしました。しかし、人間の実際の歩行では、脚は筋肉が発生させる**関節トルク（内力）** によって振られます。

今後の評価として「外部から介助力を与えた際に、関節角度（軌道）がどう変化するか」をシミュレーションしたい場合、関節に対して「目標角度（Position Control）」を指定してしまうと、関節がその目標角度に固執してしまい、介助の恩恵を角度の変化として評価できなくなります。

そこでこのチュートリアルでは、「目標角度へ向かうバネ（Spring-Damper）」の仕組みを捨て、**時系列で変化する「純粋な力（トルク）」を関節に直接与える（フィードフォワードトルク制御）** ことで、外力の影響を素直に受ける柔らかな遊脚軌道を再現します。

---

## 🎯 目的
- 外部からのアシストではなく、自身の関節トルク（内力）で脚を振る方法を学ぶ。
- 「目標角度への追従」ではなく、「純粋なトルクの印加」を行うための特殊な設定手法を理解する。
- 介助力の効果（軌道変化など）を後から評価するための、柔軟なベースライン歩行モデルを作成する。

---

## 🛠 使用環境
- **重要**: Tutorial 9 を完了した `SimpleBiped_SwingAssist.ttt` をベースにします。
- **手順**:
  1. `SimpleBiped_SwingAssist.ttt` を開く
  2. メニューの **File > Save scene as...** から `SimpleBiped_DirectTorqueSwing.ttt` などの別名で保存します。

---

## 1. 準備：対象を右脚に変更し、モーターを完全にOFFにする

CoppeliaSimのバージョンや物理エンジンによっては、スクリプトからモーターをハックして力制御する手法（`Target Velocity` 操作）がうまく動かない場合があります。
そのためここでは、**関節のモーター機能を完全に無効化（プラプラの状態）**にし、骨（図形）に対して直接「外部からの回転力（トルク）」を加えることで、筋肉の働きを代用する最も確実な手法に切り替えます。

1. **`RHip`**, **`RKnee`** の2つの関節をダブルクリックし **Show dynamic properties dialog** を開きます。
2. **Control mode** を `Spring-damper mode` から **`Free`**（または `Custom` などのモーターが一切関与しないモード）に変更します。設定欄の中に **Motor enabled** というチェックボックスがあれば、**必ずチェックを外して**ください。
3. これにより、右脚は重力に従ってプラプラと揺れるだけの単なる「振り子」になります。

---

## 2. スクリプトの書き換え（直接トルクの印加）

スクリプトファイル（`Tutorial20_SwingPhase.lua`）を外部エディタで編集し、`Pelvis` にアタッチされているスクリプトエディタには以下の1行だけを記載します。

```lua
-- CoppeliaSimのスクリプトエディタにはこれだけ記載する
-- ※パスはご自身の環境に合わせて変更してください
dofile('/Users/aoyamahiroki/Desktop/CoppeliaSim_Tutorial/Tutorial20_SwingPhase.lua')
```

外部スクリプト（`Tutorial20_SwingPhase.lua`）の全内容は以下の通りです。

```lua
-- Tutorial 20: Swing Phase by Direct Shape Torques (Right Leg)
-- このファイルはVS Code等で編集し、保存するだけでCoppeliaSim側に即座に反映されます。

function sysCall_init()
    -- *非常に重要*: 力（Force/Torque）を加える対象は「Shape（箱や円柱などの図形）」でなければなりません。
    -- Pelvis (姿勢制御用)
    pelvisHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis')
    
    -- トルクを加える対象の「骨格（Shape）」を取得
    rThighHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh')
    rShankHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh/RKnee/RShank')
    rFootHandle  = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh/RKnee/RShank/RAnkle/RFoot')
    
    -- 0. 開始時の物理的なセットアップ（骨盤自体の完全固定）
    -- 遊脚開始を待つ間、重心変化によって骨盤全体（Pelvis）がゆらゆら揺れるのを防ぐため、
    -- 最初の2秒間だけ、骨盤の質量計算を「静的（重さ無限大の固定物）」にして空中に完全固定します。
    sim.setObjectInt32Parameter(pelvisHandle, sim.shapeintparam_static, 1)
    
    -- データ出力用の関節ハンドル取得（Knee）
    rKneeJointHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh/RKnee')
    
    -- CSV出力用のファイルセットアップ
    csvFilePath = "/Users/aoyamahiroki/Desktop/CoppeliaSim_Tutorial/Tutorial20_SwingData.csv"
    csvFile = io.open(csvFilePath, "w")
    if csvFile then
        csvFile:write("Time,Pelvis_Pitch_deg,Pelvis_Roll_deg,Pelvis_Yaw_deg,RHip_deg,RKnee_deg,RFoot_Y_m\n")
        print("Data Export Started: Tutorial20_SwingData.csv")
    else
        print("Error: Could not open CSV file for writing.")
    end
    
    -------------------------------------------------
    -- SWING PHASE TORQUE PARAMETERS (Right Leg)
    -------------------------------------------------
    -- 1. 開始時の物理的なセットアップ（股関節を伸展位＝-15度に強力にロック）
    -- 姿勢が崩れないよう、最初の待機時間中は「物理エンジンの純正モーター」をONにし、
    -- さらに最大トルクを極端に大きくして -15度 の位置でキープします。
    rHipJointHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip')
    sim.setObjectInt32Parameter(rHipJointHandle, sim.jointintparam_motor_enabled, 1)
    sim.setObjectInt32Parameter(rHipJointHandle, sim.jointintparam_ctrl_enabled, 1)
    sim.setJointTargetPosition(rHipJointHandle, -15 * math.pi / 180)
    sim.setJointTargetForce(rHipJointHandle, 1000)

    -- 遊脚期の時間（秒）
    swingDuration = 0.54
    
    -- [Hip] 太もも（RThigh）を回転させる（持ち上げる）ためのトルク
    -- 遊脚相全体（swingDuration）のうち、前方向に振り上げ続ける時間の割合（0.0 〜 1.0）
    -- この割合を増やすと、前振りの時間が長くなり、ブレーキ（伸展）の時間が短くなります。
    hipFlexPhaseRatio = 0.6

    -- X軸周り（Pitch）の直接的な回転力。質量に対して非常に敏感です。
    peakHipFlexTorque = 5.0   -- 屈曲（前振り）
    peakHipExtTorque  = 2.0   -- 伸展ブレーキ（ハムストリングス相当）
    
    -- [Knee] スネ（RShank）を回転させる（曲げる）ためのトルク
    -- 遊脚開始から少し遅らせて膝を曲げ始めることで「股関節から先に動く」自然なスイングになります。
    kneeFlexionDelay   = 0.1   -- 遊脚開始から膝を曲げ始めるまでの遅延時間（秒）
    peakKneeFlexTorque = 4.0   -- 屈曲（曲げる）
    peakKneeExtTorque  = 1.0   -- 伸展（伸ばす）
    peakKneeBrakeTorque= 1.0   -- 終盤ブレーキ（衝撃吸収）
    
    -- [Ankle] 足首（RFoot）を中間位で強固に固定する
    -- 物理エンジンの純正モーター機能（位置制御）をONにして完全に0度（中間位）にロックします。
    rAnkleJointHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh/RKnee/RShank/RAnkle')
    sim.setObjectInt32Parameter(rAnkleJointHandle, sim.jointintparam_motor_enabled, 1)
    sim.setObjectInt32Parameter(rAnkleJointHandle, sim.jointintparam_ctrl_enabled, 1)
    sim.setJointTargetPosition(rAnkleJointHandle, 0)
    
    -------------------------------------------------
    -- PELVIS KINEMATICS LIMITS (Tutorial 9 から継続)
    -------------------------------------------------
    limitPitch = 4   * math.pi / 180
    limitRoll  = 4.5 * math.pi / 180
    limitYaw   = 4   * math.pi / 180
    Kp_ang = 0.5
    Kd_ang = 0.5
    
    patternDelay = 2.0
    swingStarted = false
    
    print("=== Swing Phase by Direct Shape Torques (Right Leg) ===")
end

-- 簡易的なトルク波形生成関数（半波長サイン波）
function calculateTorqueValue(tRel, duration, peakValue)
    if tRel >= 0 and tRel <= duration then
        return peakValue * math.sin((math.pi / duration) * tRel)
    else
        return 0
    end
end

function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    -------------------------------------------------
    -- DATA EXPORT (CSV出力: 遊脚相の間のみ記録)
    -------------------------------------------------
    if csvFile and t >= patternDelay and t <= (patternDelay + swingDuration) then
        local pEuler = sim.getObjectOrientation(pelvisHandle, -1)
        local hipAng  = sim.getJointPosition(rHipJointHandle)
        local kneeAng = sim.getJointPosition(rKneeJointHandle)
        local footPos = sim.getObjectPosition(rFootHandle, -1)
        local tRel = t - patternDelay
        csvFile:write(string.format("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n", 
            tRel,
            math.deg(pEuler[1]), math.deg(pEuler[2]), math.deg(pEuler[3]),
            math.deg(hipAng), math.deg(kneeAng), footPos[2]
        ))
    end
    
    -------------------------------------------------
    -- APPLY KINEMATIC LIMITS (骨盤姿勢の安定化)
    -------------------------------------------------
    local euler = sim.getObjectOrientation(pelvisHandle, -1)
    local linVel, angVel = sim.getObjectVelocity(pelvisHandle)
    local torqueX = 0; local torqueY = 0; local torqueZ = 0
    
    if euler[1] > limitPitch then torqueX = -Kp_ang * (euler[1] - limitPitch)
    elseif euler[1] < -limitPitch then torqueX = -Kp_ang * (euler[1] + limitPitch) end
    torqueX = torqueX - Kd_ang * angVel[1]
    
    if euler[2] > limitRoll then torqueY = -Kp_ang * (euler[2] - limitRoll)
    elseif euler[2] < -limitRoll then torqueY = -Kp_ang * (euler[2] + limitRoll) end
    torqueY = torqueY - Kd_ang * angVel[2]
    
    if euler[3] > limitYaw then torqueZ = -Kp_ang * (euler[3] - limitYaw)
    elseif euler[3] < -limitYaw then torqueZ = -Kp_ang * (euler[3] + limitYaw) end
    torqueZ = torqueZ - Kd_ang * angVel[3]
    
    sim.addForceAndTorque(pelvisHandle, {0, 0, 0}, {torqueX, torqueY, torqueZ})
    
    -------------------------------------------------
    -- APPLY DIRECT SHAPE TORQUES OR JOINT HOLD
    -------------------------------------------------
    if t < patternDelay then
        -- 待機時間中は、毎フレーム強制的に角度を上書きして揺れを防ぐ
        sim.setJointPosition(rHipJointHandle, -15 * math.pi / 180)
    else
        -- 2秒経過した瞬間（1回だけ実行）にモーター・静的固定を解除
        if not swingStarted then
            sim.setObjectInt32Parameter(pelvisHandle, sim.shapeintparam_static, 0)
            sim.setObjectInt32Parameter(rHipJointHandle, sim.jointintparam_motor_enabled, 0)
            swingStarted = true
            print("--- Swing Phase Started! (Pelvis & Motor freed, applying Torques) ---")
        end
        
        local tRel = t - patternDelay
        local hipTorqueX   = 0
        local kneeTorqueX  = 0
        
        -- 1. Hipのトルク計算（前半60%: 屈曲 → 後半40%: 伸展ブレーキ）
        -- ★絶対座標のX軸回転において、プラス回転（+X）が「前方への振り出し（Hip Flexion）」になります。
        local hipFlexPhase  = swingDuration * hipFlexPhaseRatio   -- 前半60%: 屈曲（前振り）
        local hipBrakePhase = swingDuration - hipFlexPhase        -- 後半40%: 伸展ブレーキ
        if tRel <= hipFlexPhase then
            hipTorqueX = calculateTorqueValue(tRel, hipFlexPhase, peakHipFlexTorque)  -- プラスで前方向回転
        else
            -- 振り出し後、ハムストリングスのように逆方向（伸展＝後ろ向き）にブレーキをかけて
            -- 着地直前のオーバースイングを防ぎ、ヒールストライクに備えた姿勢を整えます。
            local tBrake = tRel - hipFlexPhase
            hipTorqueX = -calculateTorqueValue(tBrake, hipBrakePhase, peakHipExtTorque)  -- マイナスで伸展方向
        end
        
        -- 2. Kneeのトルク計算（前半30%: 屈曲クリアランス → 中盤40%: 伸展 → 終盤30%: ブレーキ）
        if tRel <= kneeFlexionDelay then
            kneeTorqueX = 0
        else
            local kneeActiveDuration = swingDuration - kneeFlexionDelay
            local tRelKnee = tRel - kneeFlexionDelay
            
            local kneeFlexPhase  = kneeActiveDuration * 0.3  -- 最初30%で膝を曲げてクリアランス
            local kneeExtPhase   = kneeActiveDuration * 0.4  -- 次の40%で前にスネを振り出す
            local kneeBrakePhase = kneeActiveDuration * 0.3  -- 最後30%で屈曲ブレーキ（衝撃吸収）
            
            if tRelKnee <= kneeFlexPhase then
                kneeTorqueX = -calculateTorqueValue(tRelKnee, kneeFlexPhase, peakKneeFlexTorque)
            elseif tRelKnee <= (kneeFlexPhase + kneeExtPhase) then
                local tExt = tRelKnee - kneeFlexPhase
                kneeTorqueX = calculateTorqueValue(tExt, kneeExtPhase, peakKneeExtTorque)
            elseif tRelKnee <= kneeActiveDuration then
                local tBrake = tRelKnee - (kneeFlexPhase + kneeExtPhase)
                kneeTorqueX = -calculateTorqueValue(tBrake, kneeBrakePhase, peakKneeBrakeTorque)
            end
        end
        
        -- Shapeに対して直接トルクを印加
        sim.addForceAndTorque(rThighHandle, {0, 0, 0}, {hipTorqueX,  0, 0})
        sim.addForceAndTorque(rShankHandle, {0, 0, 0}, {kneeTorqueX, 0, 0})
    end
    
    -------------------------------------------------
    -- AUTO-STOP SIMULATION
    -------------------------------------------------
    if t > (patternDelay + swingDuration + 1.0) then
        print("--- Swing Phase Completed. Stopping Simulation ---")
        sim.stopSimulation()
    end
end

function sysCall_cleanup()
    if csvFile then
        csvFile:close()
        print("Data Export Finished: Saved to " .. csvFilePath)
    end
end
```

---

## 3. コードの重要なポイント

### 待機時間中の骨盤・股関節固定
遊脚開始前の2秒間は、骨盤（Pelvis）を `shapeintparam_static = 1` で物理エンジン的に完全固定し、同時に股関節（RHip）の純正モーターを位置制御（-15°）で強力にロックします。
これにより、重力による揺れや崩れを防いだ状態で **Toe-off（離地）時の股関節伸展姿勢** を安定して再現します。2秒経過した瞬間にこれらをすべて解除し、トルク制御に切り替えます。

### 関節モーターからの脱却（`addForceAndTorque` の利用）
これまでの手法は「関節に備わっているモーター」をハックして力制御を試みていましたが、環境によって動作が不安定でした。
そこで、Tutorial 9で骨盤（Pelvis）に介助力を加えたのと同じ `sim.addForceAndTorque` という**絶対に動作する物理エンジン直結の命令**を採用しました。

太もも（RThigh）やスネ（RShank）の図形自体を「**直接ネジ回しのように回転させる（Torque）**」ことで、筋肉が関節を跨いで骨を引っ張る挙動をより忠実に再現しています。

### トルクフェーズの構成（筋電図を模した3段階制御）
正常歩行の遊脚相（Swing Phase）では、以下のような複雑な筋活動の推移があります。

- **Hip（股関節）**:
  1. **前半60%（Flexion Phase）**: 腸腰筋などが強く働き、脚を前にスイングさせます（`+X` 方向のトルク）。
  2. **後半40%（Extension Brake）**: ハムストリングスが前方へのオーバースイングを防ぐために制動します（`-X` 方向のトルク）。ヒールストライクに備えた着地姿勢を整えます。
- **Knee（膝関節）**:
  1. **初期30%（Flexion Phase）**: 足先が地面に引っかからないよう、膝を素早く曲げます（クリアランス確保）。
  2. **中盤40%（Extension Phase）**: 大腿四頭筋等も働き、着地（ヒールストライク）に向け膝を伸ばします。
  3. **終盤30%（Brake Phase）**: 着地の衝撃を吸収するため、再び屈曲方向のブレーキをかけます。
- **Ankle（足首）**: 物理エンジンの位置制御モーターで0度（中間位）に完全固定し、下垂足を防ぎます。

### 足首固定（下垂足の完全防止）
足首（RAnkle）はスクリプトからの力学的なバネ制御ではなく、物理エンジンの純正モーター位置制御によって0°に固定します。これによりスイング中の下垂足（foot drop）を確実に防ぎます。

---

## 4. シミュレーション実験と調整

1. ▶️ **Start simulation** を実行します。
2. 2.0秒後、**右脚**がひとりでに前方にスイングし、途中で膝が伸びて着地姿勢に入るのを確認します。
3. 約3.54秒（`patternDelay + swingDuration + 1.0`）でシミュレーションが自動停止します。

### 🚨 【重要】脚がピクリとも動かない場合のトラブルシューティング
コンソールにエラーが出ていないのに脚が動かない場合、以下の原因が考えられます。

**原因1: 関節の Control Mode の選択が適切でない（最新版の仕様）**
最新版の CoppeliaSim では `Custom` モードは「ユーザーがコールバック関数（C++等）で完全に自作する専用」になり、通常のスクリプトからの命令を受け付けない場合があります。
1. `RHip` と `RKnee` の Dynamic properties dialog を開きます。
2. Control mode を `Custom` から **`Force/torque mode`**（または `Velocity mode`）に変更してください。
3. もし上記のモードが無い場合は、**`Spring-damper mode` に戻し、Spring(K)とDamping(C)をともに完全な `0` に設定**してください。

**原因2: 与えているトルクが（脚の重さに対して）小さすぎる**
脚のパーツの質量が大きすぎると、現在のトルク値ではピクリとも動きません。
- スクリプト内の `peakHipFlexTorque` と `peakKneeFlexTorque` を、思い切って **`200.0`** や **`500.0`** など極端に大きな値に変更して動作確認し、動いた場合は徐々に現実的な値に下げてください。

**原因3: 当たり判定（干渉）で引っかかっている**
太もも（RThigh）が骨盤（Pelvis）にぶつかってロックされている可能性があります。
- オブジェクトの `Respondable` 設定を見直すか、Pelvisの高さ（Z位置）を少し上に調整してください。

### 🚨 動きの調整（質量感に合わせたチューニング）

| 症状                     | 調整パラメータ                                                     |
| ------------------------ | ------------------------------------------------------------------ |
| 脚が弱々しく上がらない   | `peakHipFlexTorque` / `peakKneeFlexTorque` を大きくする            |
| 脚が前に飛び出しすぎる   | `peakHipFlexTorque` を小さくするか `peakHipExtTorque` を大きくする |
| 膝が前方向に折れる       | トルクの符号（`-` / `+`）を反転させる                              |
| 着地時に膝が曲がりすぎる | `peakKneeBrakeTorque` を大きくする                                 |
| 骨盤が揺れる             | `Kp_ang` / `Kd_ang` を増やす                                       |

---

## まとめ

この Tutorial では、関節の角度を強制的に追従させるのではなく、**「筋肉が力を出す」ことを模擬したトルクの直接印加** を行いました。
目標角度という「絶対的な壁」がなくなったことで、この上に Tutorial 9 でやったような「外部からの介助力（`sim.addForce`）」を加えれば、**「介助によって関節の軌道（曲がり方）がどう改善したか」** を角度グラフ等から正しく評価できるようになります。

---

<a id="data-export"></a>
## 5. シミュレーションデータのCSV自動出力

本チュートリアルの外部スクリプト（`Tutorial20_SwingPhase.lua`）には、シミュレーション中の姿勢や関節の動きを自動的に記録する機能が備わっています。

シミュレーションが終了すると、デスクトップの `CoppeliaSim_Tutorial` フォルダ内に **`Tutorial20_SwingData.csv`** というファイルが自動生成されます。

### 📊 記録されるデータ項目（カラム）

| #   | カラム名           | 単位 | 内容                                        |
| --- | ------------------ | ---- | ------------------------------------------- |
| 1   | `Time`             | s    | 遊脚開始（t=0）からの相対時間               |
| 2   | `Pelvis_Pitch_deg` | °    | 骨盤の前後傾                                |
| 3   | `Pelvis_Roll_deg`  | °    | 骨盤の側方傾斜                              |
| 4   | `Pelvis_Yaw_deg`   | °    | 骨盤の回旋                                  |
| 5   | `RHip_deg`         | °    | 股関節角度（プラスが屈曲、マイナスが伸展）  |
| 6   | `RKnee_deg`        | °    | 膝関節角度（マイナスが屈曲、プラスが伸展）  |
| 7   | `RFoot_Y_m`        | m    | 足部のY軸絶対座標（進行方向の前進距離確認） |

ExcelやGoogleスプレッドシートでこのデータを開き、折れ線グラフを作成することで、「トルクに対する各関節の角度変化の遅れ」や「衝撃吸収（ブレーキ）の効果」などを視覚的に分析することができます。
