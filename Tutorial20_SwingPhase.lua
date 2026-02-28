-- Tutorial 20: Swing Phase by Direct Shape Torques (Right Leg)
-- このファイルはVS Code等で編集し、保存するだけでCoppeliaSim側に即座に反映されます。

function sysCall_init()
    -- *非常に重要*: 力（Force/Torque）を加える対象は「Shape（箱や円柱などの図形）」でなければなりません。
    -- Pelvis (姿勢制御用)
    pelvisHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis')
    
    -- トルクを加える対象の「骨格（Shape）」を取得
    rThighHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh')
    rShankHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh/RKnee/RShank')
    rFootHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh/RKnee/RShank/RAnkle/RFoot')
    
    -- 0. 開始時の物理的なセットアップ（骨盤自体の完全固定）
    -- 遊脚開始を待つ間、重心変化によって骨盤全体（Pelvis）がゆらゆら揺れるのを防ぐため、
    -- 最初の2秒間だけ、骨盤の質量計算を「静的（重さ無限大の固定物）」にして空中に完全固定します。
    sim.setObjectInt32Parameter(pelvisHandle, sim.shapeintparam_static, 1)
    
    -------------------------------------------------
    -- SWING PHASE TORQUE PARAMETERS (Right Leg)
    -------------------------------------------------
    -- 1. 開始時の物理的なセットアップ（股関節を伸展位＝-20度に強力にロック）
    -- 姿勢が崩れないよう、最初の待機時間中は「物理エンジンの純正モーター」をONにし、
    -- さらに最大トルクを極端に大きくして -20度 の位置でキープします。
    rHipJointHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip')
    sim.setObjectInt32Parameter(rHipJointHandle, sim.jointintparam_motor_enabled, 1)
    sim.setObjectInt32Parameter(rHipJointHandle, sim.jointintparam_ctrl_enabled, 1)
    sim.setJointTargetPosition(rHipJointHandle, -20 * math.pi / 180)
    -- 脚全体の重さに負けて揺れないよう、モーターの出す最大力を超強力（1000）にセット
    sim.setJointTargetForce(rHipJointHandle, 1000)
    
    -- 遊脚期の時間
    swingDuration = 0.5
    
    -- [Hip] 太もも（RThigh）を回転させる（持ち上げる）ためのトルク
    -- X軸周り（Pitch）の直接的な回転力。質量に対して非常に敏感です。
    peakHipFlexTorque = 7.0   -- 屈曲（前振り） ※初期位置が後ろになった分、大きめの前振り力が必要
    peakHipExtTorque  = 5.0   -- 伸展（ブレーキ）
    
    -- [Knee] スネ（RShank）を回転させる（曲げる）ためのトルク
    -- 遊脚開始から少し遅らせて膝を曲げ始めることで「股関節から先に動く」自然なスイングになります。
    kneeFlexionDelay = 0.1   -- 遊脚開始から膝を曲げ始めるまでの遅延時間（秒）
    peakKneeFlexTorque = 4.0  -- 屈曲（曲げる）
    peakKneeExtTorque  = 0.1  -- 伸展（伸ばす）
    peakKneeBrakeTorque = 10.0 -- ⭐️追加：遊脚終期の「膝振り切り（衝撃）」を抑えるための強力なブレーキ（屈曲方向の力）
    
    
    -- [Ankle] 足首（RFoot）を中間位で強固に固定する
    -- スクリプトからの力学的なバネ（ビヨンビヨンする）や、毎フレームの上書きではなく、
    -- 物理エンジンの純正モーター機能（位置制御）をONにして完全に0度（中間位）にロックします。
    rAnkleJointHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh/RKnee/RShank/RAnkle')
    
    -- モーターを有効化
    sim.setObjectInt32Parameter(rAnkleJointHandle, sim.jointintparam_motor_enabled, 1)
    -- モーターのコントロールループ（位置制御モード）を有効化
    sim.setObjectInt32Parameter(rAnkleJointHandle, sim.jointintparam_ctrl_enabled, 1)
    -- 目標角度を 0度（中間位） に設定
    sim.setJointTargetPosition(rAnkleJointHandle, 0)
    
    -------------------------------------------------
    -- PELVIS KINEMATICS LIMITS (Tutorial 9 から継続)
    -------------------------------------------------
    limitPitch = 4 * math.pi / 180
    limitRoll  = 4.5 * math.pi / 180
    limitYaw   = 4 * math.pi / 180
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
        -- 待機時間（2秒未満）は、RHipの純正モーターをONにして維持しつつ、
        -- 物理エンジン特有の「重さによるたわみ・揺れ」を完全に防ぐため、
        -- 毎フレーム強制的に角度を上書き（キネマティック固定）します。
        sim.setJointPosition(rHipJointHandle, -20 * math.pi / 180)
    else
        -- 2秒経過した瞬間（1回だけ実行）に、RHipのモーターをOFFにして「完全な脱力（Free）」にします
        -- また、それまで空中固定していた骨盤（Pelvis）の「静的」設定を解除し、自然な動きに戻します。
        if not swingStarted then
            sim.setObjectInt32Parameter(pelvisHandle, sim.shapeintparam_static, 0)
            sim.setObjectInt32Parameter(rHipJointHandle, sim.jointintparam_motor_enabled, 0)
            swingStarted = true
            print("--- Swing Phase Started! (Pelvis & Motor freed, applying Torques) ---")
        end
        
        local tRel = t - patternDelay
        
        -- 1. Hipのトルク計算（前半：屈曲、後半：伸展ブレーキ）
        -- ★絶対座標のX軸回転において、プラス回転（+X）が「前方への振り出し（Hip Flexion）」になります。
        local hipFlexPhase = swingDuration * 0.6
        if tRel <= hipFlexPhase then
            hipTorqueX = calculateTorqueValue(tRel, hipFlexPhase, peakHipFlexTorque) -- プラスで前方向回転
        elseif tRel <= swingDuration then
            local tBrake = tRel - hipFlexPhase
            local hipExtPhase = swingDuration - hipFlexPhase
            hipTorqueX = -calculateTorqueValue(tBrake, hipExtPhase, peakHipExtTorque)  -- マイナスで後ろ方向回転（ブレーキ）
        end
        
        -- 2. Kneeのトルク計算（前半：屈曲クリアランス、中盤：伸展で前へ、終盤：ブレーキで衝撃吸収）
        -- 指定した遅延時間（kneeFlexionDelay）が経過するまでは膝に力を入れません
        if tRel <= kneeFlexionDelay then
            kneeTorqueX = 0
        else
            -- 遅延を引いた、膝が実際に動く実質的な利用可能時間
            local kneeActiveDuration = swingDuration - kneeFlexionDelay
            local tRelKnee = tRel - kneeFlexionDelay
            
            local kneeFlexPhase = kneeActiveDuration * 0.3        -- 最初30%で膝を曲げてクリアランス
            local kneeExtPhase  = kneeActiveDuration * 0.4        -- 次の40%で前にスネを振り出す
            local kneeBrakePhase= kneeActiveDuration * 0.3        -- 最後の30%で強力なブレーキ（屈曲方向）をかけて衝撃吸収
            
            if tRelKnee <= kneeFlexPhase then
                -- 屈曲（持ち上げる）
                kneeTorqueX = -calculateTorqueValue(tRelKnee, kneeFlexPhase, peakKneeFlexTorque)
            elseif tRelKnee <= (kneeFlexPhase + kneeExtPhase) then
                -- 伸展（前に振り出す）
                local tExt = tRelKnee - kneeFlexPhase
                kneeTorqueX = calculateTorqueValue(tExt, kneeExtPhase, peakKneeExtTorque)
            elseif tRelKnee <= kneeActiveDuration then
                -- ⭐️ブレーキ（前に行き過ぎないように後ろに引っ張る＝屈曲方向の強い力で衝撃を殺す）
                local tBrake = tRelKnee - (kneeFlexPhase + kneeExtPhase)
                kneeTorqueX = -calculateTorqueValue(tBrake, kneeBrakePhase, peakKneeBrakeTorque)
            end
        end
        
        -- 遊脚相（2秒以降）のみ、Shapeに対して直接トルクを印加
        -- 太もも全体をPitch軸（X軸）を中心に持ち上げる
        sim.addForceAndTorque(rThighHandle, {0, 0, 0}, {hipTorqueX, 0, 0})
        
        -- スネ部分をPitch軸（X軸）を中心に曲げる
        sim.addForceAndTorque(rShankHandle, {0, 0, 0}, {kneeTorqueX, 0, 0})
    end
    
    -------------------------------------------------
    -- APPLY KINEMATIC LIMITS TO ANKLE (下垂足の完全防止)
    -------------------------------------------------
    -- 物理エンジンの内部モーターを使って0度にロックしているので、Luaからの毎フレームの角度上書きは不要です。
    
    -------------------------------------------------
    -- AUTO-STOP SIMULATION
    -------------------------------------------------
    -- 遊脚相が終わってから1秒経過したら自動的にシミュレーションを終了する
    if t > (patternDelay + swingDuration + 1.0) then
        print("--- Swing Phase Completed. Stopping Simulation ---")
        sim.stopSimulation()
    end
end
