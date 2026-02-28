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
    
    -- 重力モードの有効化（正常歩行の遊脚相は重力を利用した振り子運動です）
    sim.setArrayParameter(sim.arrayparam_gravity, {0, 0, -9.81})
    print("Standard Gravity Mode: ON (-9.81, Focus: Right Leg)")
    
    -------------------------------------------------
    -- SWING PHASE TORQUE PARAMETERS (Right Leg)
    -------------------------------------------------
    -- 1. 開始時の物理的なセットアップ（股関節を伸展位＝-15度に強制配置）
    -- ※本来関節モードはFreeですが、開始の一瞬だけ位置を直接書き換えることでToe-off姿勢を作ります
    rHipJointHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip')
    sim.setJointPosition(rHipJointHandle, -15 * math.pi / 180)
    
    -- 2. 初期姿勢（Toe-off）を維持するための保持トルク
    -- 後ろ側（伸展方向）に脚を引っ張り上げておく力。
    -- ⚠️注意：ここで「1.0」や「0.5」など弱すぎる力を設定すると、
    -- 重力（-9.81）に負けてしまい、2秒待つ間に脚が勝手に前へ落ちてしまいます。
    -- 脚が落ちないように支えきれる強さ（今回は3.0程度）が必要です。
    initialHipExtHoldTorque = 3.0 
    
    -- 遊脚期の時間
    swingDuration = 0.5
    
    -- [Hip] 太もも（RThigh）を回転させる（持ち上げる）ためのトルク
    -- X軸周り（Pitch）の直接的な回転力。質量に対して非常に敏感です。
    peakHipFlexTorque = 10.0   -- 屈曲（前振り） ※初期位置が後ろになった分、大きめの前振り力が必要
    peakHipExtTorque  = 6.0   -- 伸展（ブレーキ）
    
    -- [Knee] スネ（RShank）を回転させる（曲げる）ためのトルク
    peakKneeFlexTorque = 4.0  -- 屈曲（曲げる）
    peakKneeExtTorque  = 4.0  -- 伸展（伸ばす）
    
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
    -- APPLY DIRECT SHAPE TORQUES (Feed-forward)
    -------------------------------------------------
    local hipTorqueX = 0
    local kneeTorqueX = 0
    
    if t < patternDelay then
        -- 待機中は、遊脚開始前の「股関節伸展位（脚を後ろに残した状態）」を作るため、
        -- 常に後ろ方向（伸展方向）への一定トルクをかけ続けます。
        hipTorqueX = initialHipExtHoldTorque
    else
        local tRel = t - patternDelay
        
        -- 1. Hipのトルク計算（前半：屈曲、後半：伸展ブレーキ）
        local hipFlexPhase = swingDuration * 0.6
        if tRel <= hipFlexPhase then
            hipTorqueX = -calculateTorqueValue(tRel, hipFlexPhase, peakHipFlexTorque) -- マイナスで前方向回転
        elseif tRel <= swingDuration then
            local tBrake = tRel - hipFlexPhase
            local hipExtPhase = swingDuration - hipFlexPhase
            hipTorqueX = calculateTorqueValue(tBrake, hipExtPhase, peakHipExtTorque)  -- プラスで後ろ方向回転
        end
        
        -- 2. Kneeのトルク計算（前半：屈曲クリアランス、後半：伸展で着地準備）
        local kneeFlexPhase = swingDuration * 0.4
        if tRel <= kneeFlexPhase then
            kneeTorqueX = calculateTorqueValue(tRel, kneeFlexPhase, peakKneeFlexTorque)  -- プラスで膝を曲げる
        elseif tRel <= swingDuration then
            local tExt = tRel - kneeFlexPhase
            local kneeExtPhase = swingDuration - kneeFlexPhase
            kneeTorqueX = -calculateTorqueValue(tExt, kneeExtPhase, peakKneeExtTorque) -- マイナスで膝を伸ばす
        end
    end
    
    -- 太もも全体をPitch軸（X軸）を中心に持ち上げる
    sim.addForceAndTorque(rThighHandle, {0, 0, 0}, {hipTorqueX, 0, 0})
    
    -- スネ部分をPitch軸（X軸）を中心に曲げる
    sim.addForceAndTorque(rShankHandle, {0, 0, 0}, {kneeTorqueX, 0, 0})
    
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
