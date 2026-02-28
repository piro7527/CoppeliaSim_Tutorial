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

`Pelvis` にアタッチされているスクリプトを開き、**完全に以下のコードに書き換え** ます。
このコードでは、`sim.addForceAndTorque` という絶対確実な命令を使って、太もも（RThigh）やスネ（RShank）の図形自体に直接「回転させる力」を加えます。
また、遊脚が始まる前の待機状態（初期姿勢）として、正常歩行のToe-off（離地）時のような「股関節の伸展位（脚が後ろに残った状態）」を作り出す力を加え続けます。

```lua
function sysCall_init()
    -- *非常に重要*: 力（Force/Torque）を加える対象は「Shape（箱や円柱などの図形）」でなければなりません。
    -- Pelvis (姿勢制御用)
    pelvisHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis')
    
    -- トルクを加える対象の「骨格（Shape）」を取得
    rThighHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh')
    rShankHandle = sim.getObject('/Trunk/PelvisJoint/Pelvis/RHip/RThigh/RKnee/RShank')
    
    -- 無重力モードの有効化
    sim.setArrayParameter(sim.arrayparam_gravity, {0, 0, 0})
    print("Zero Gravity Mode: ON (Focus: Right Leg)")
    
    -------------------------------------------------
    -- SWING PHASE TORQUE PARAMETERS (Right Leg)
    -------------------------------------------------
    -- 初期姿勢（Toe-off）を維持するための保持トルク
    -- 後ろ側（伸展方向）に脚を引っ張り上げておく力
    initialHipExtHoldTorque = 1.0 
    
    -- 遊脚期の時間
    swingDuration = 0.5
    
    -- [Hip] 太もも（RThigh）を回転させる（持ち上げる）ためのトルク
    -- X軸周り（Pitch）の直接的な回転力。質量に対して非常に敏感です。
    peakHipFlexTorque = 2.0   -- 屈曲（前振り） ※初期位置が後ろになった分、大きめの前振り力が必要かも
    peakHipExtTorque  = 1.0   -- 伸展（ブレーキ）
    
    -- [Knee] スネ（RShank）を回転させる（曲げる）ためのトルク
    peakKneeFlexTorque = 0.5  -- 屈曲（曲げる）
    peakKneeExtTorque  = 0.5  -- 伸展（伸ばす）
    
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
    
    -- Shapeに対して直接トルクを印加
    -- {0, 0, 0} は力のベクトル（今回は純粋な回転力なのでゼロ）
    -- {torqueX, torqueY, torqueZ} は回転させるトルクベクトル
    -- 太もも全体をPitch軸（X軸）を中心に持ち上げる
    sim.addForceAndTorque(rThighHandle, {0, 0, 0}, {hipTorqueX, 0, 0})
    
    -- スネ部分をPitch軸（X軸）を中心に曲げる
    sim.addForceAndTorque(rShankHandle, {0, 0, 0}, {kneeTorqueX, 0, 0})
   -- 外部ファイル側で必要な変数を定義、操作を記述...
end
```

---

## 3. コードの重要なポイント

### 遊脚開始姿勢（Toe-off）の再現
正常歩行の遊脚相は、脚が直下（0度）にある状態から始まるわけではなく、**支持脚期を終えて脚が体幹より後方に取り残された状態（股関節伸展位）**から猛烈な前振り上げが始まります。
今回のスクリプトでは、最初の `patternDelay` の2秒間、`initialHipExtHoldTorque` という「脚を後ろに引っ張り上げておく力」をかけ続けることで、この「溜め」の姿勢を再現しました。
ここから一気に前方向（マイナス方向）の大きなトルク `peakHipFlexTorque` が発揮されることで、勢いのあるスイングが生み出されます。

### 関節モーターからの脱却（`addForceAndTorque` の利用）
これまでの手法は「関節に備わっているモーター」をハックして力制御を試みていましたが、環境によって動作が不安定でした。
そこで、Tutorial 9で骨盤（Pelvis）に介助力を加えたのと同じ `sim.addForceAndTorque` という**絶対に動作する物理エンジン直結の命令**を採用しました。

今回は、骨盤を「引っ張る（Force）」のではなく、太もも（RThigh）やスネ（RShank）の図形自体を「**直接ネジ回しのように回転させる（Torque）**」ことで、筋肉が関節を跨いで骨を引っ張る挙動をより忠実に再現しています。

---

## 💡 おまけ：スクリプトの外部ファイル化（エディタ連携）
CoppeliaSim 内蔵のエディタに毎回コピー＆ペーストするのが面倒な場合、スクリプトを外部のテキストファイル（例: `swing_script.lua`）としてデスクトップ等に保存し、CoppeliaSim 側からはそのファイルを**読み込むだけ**にする方法があります。

Pelvis にアタッチされているスクリプトを、たったの1行（あるいは数行）で以下のように書き換えます。

```lua
-- CoppeliaSimのスクリプトエディタにはこれだけ記載する
-- ※パスはご自身の環境に合わせて変更してください
dofile('/Users/aoyamahiroki/Desktop/CoppeliaSim_Tutorial/swing_script.lua')
```

こうすることで、今後は VS Code などの使い慣れたエディタで `swing_script.lua` を編集・保存するだけで、自動的に次回シミュレーション時に変更が即座に反映されるようになります。より複雑なコードを書く際に非常に便利です。
これまでの手法は「関節に備わっているモーター」をハックして力制御を試みていましたが、環境によって動作が不安定でした。
そこで、Tutorial 9で骨盤（Pelvis）に介助力を加えたのと同じ `sim.addForceAndTorque` という**絶対に動作する物理エンジン直結の命令**を採用しました。

今回は、骨盤を「引っ張る（Force）」のではなく、太もも（RThigh）やスネ（RShank）の図形自体を「**直接ネジ回しのように回転させる（Torque）**」ことで、筋肉が関節を跨いで骨を引っ張る挙動をより忠実に再現しています。
正常歩行の遊脚相（Swing Phase）は、単に「前に振り上げる」だけではなく、以下のような複雑な筋活動（トルク）の推移があります。このスクリプトではそれを簡略化したフェーズに分けて表現しました。

- **Hip（股関節）**:
  1. **初期〜中期（Flexion Phase）**: 腸腰筋などが強く働き、脚を前にスイングさせます（正のトルク）。
  2. **終期（Extension Brake）**: このままでは足が前に飛びすぎてしまうため、ハムストリングス等が働いて強力なブレーキ（負のトルク）をかけ、着地に備えます。
- **Knee（膝関節）**:
  1. **初期（Flexion Phase）**: 足先が地面に引っかからないよう、膝を素早く曲げます（正のトルク）。
  2. **中期〜終期（Extension Phase）**: 振り出した勢いで膝が伸びていきますが、大腿四頭筋等も働き、着地（ヒールストライク）できるまっすぐな状態に向けて伸展トルク（負のトルク）を加えます。

---

## 4. シミュレーション実験と調整

1. ▶️ **Start simulation** を実行します。
2. 2.0秒後、**右脚**がひとりでに前方にスイングし、途中で膝が伸びて着地姿勢に入るのを確認します。

### 🚨 【重要】脚がピクリとも動かない場合のトラブルシューティング
コンソールにエラーが出ていないのに脚が動かない場合、以下の原因が考えられます。最新バージョンのCoppeliaSimでは設定方法が少し異なります。

**原因1: 関節の Control Mode の選択が適切でない（最新版の仕様）**
最新版の CoppeliaSim では `Custom` モードは「ユーザーがコールバック関数（C++等）で完全に自作する専用」になり、通常のスクリプトからの `Target Velocity` 等の命令を受け付けない場合があります。
1. `RHip` と `RKnee` の Dynamic properties dialog を開きます。
2. Control mode を `Custom` から **`Force/torque mode`**（または `Velocity mode`）に変更してください。
3. もし上記のモードが無い場合は、**`Spring-damper mode` に戻し、Spring(K)とDamping(C)をともに完全な `0` に設定**してください。これで「スクリプトからのトルク指示」だけを受け付ける状態になります。

**原因2: 与えているトルクが（脚の重さに対して）小さすぎる**
脚のパーツ（Thigh, Shank, Foot）の質量（Mass）や慣性モーメントが大きすぎると、`25.0` 程度のトルクではピクリとも動きません。
- スクリプト内の `peakHipFlexTorque` と `peakKneeFlexTorque` を、思い切って **`200.0`** や **`500.0`** など極端に大きな値に変更して、少しでも動くかテストしてください。動いた場合は、そこから徐々に人間らしい値に下げていきます。

**原因3: 当たり判定（干渉）で引っかかっている**
脚を前に振ろうとした瞬間、太もも（RThigh）が骨盤（Pelvis）にぶつかって（めり込んで）ロックされている可能性があります。
- チュートリアル8で行ったように、オブジェクトの `Respondable` 設定を見直すか、Pelvisの形状を調整して干渉を避けてください。
- あるいは無重力モードでも足の裏がすでに床（Floor）に接触・摩擦を起こしている可能性があります。Pelvis本体のZ位置（高さ）を少しだけ上に持ち上げてください。

### 🚨 動きの調整（質量感に合わせたチューニング）
トルク制御はモデルの脚の重さ（質量パラメータ）に非常に敏感です。脚がうまく振れない、もしくは振り上がりすぎる場合は、スクリプトの以下の数値を調整して「一番自然な一歩」になるようにチューニングしてください。

- **脚が弱々しく上がらない・足先が引っかかる**： `peakHipFlexTorque` や `peakKneeFlexTorque` の値を `30.0` や `20.0` などに大きくする。
- **脚が勢いよく上がりすぎてひっくり返る・前に飛び出すぎる**： 振り出しの力（`peakHipFlexTorque`）を小さくするか、後半のブレーキ力（`peakHipExtTorque`）の値を大きくして減速させる。
- **膝の曲がる方向が逆（前方に折れる）場合**： `applyDirectTorque` に渡すトルクの符号を `-` に反転させる必要があります。

この段階で「ほどよく自然な右脚の遊脚」が完成すれば、次のチュートリアルで「この自然な運動に対する介助（外的アシスト）の影響」を、関節角度のズレとして正確に評価することが可能になります。

---

## まとめ

この Tutorial では、関節の角度を強制的に追従させるのではなく、**「筋肉が力を出す」ことを模擬したトルクの直接印加** を行いました。
目標角度という「絶対的な壁」がなくなったことで、この上に Tutorial 9 でやったような「外部からの介助力（`sim.addForce`）」を加えれば、**「介助によって関節の軌道（曲がり方）がどう改善したか」** を角度グラフ等から正しく評価できるようになります。

---

<a id="data-export"></a>
## 5. シミュレーションデータのCSV自動出力

本チュートリアルの外部スクリプト（`Tutorial20_SwingPhase.lua`）には、シミュレーション中の姿勢や関節の動きを自動的に記録する機能が備わっています。

シミュレーションが終了すると、デスクトップの `CoppeliaSim_Tutorial` フォルダ内に **`Tutorial20_SwingData.csv`** というファイルが自動生成されます。このCSVファイルには、0.05秒間隔で以下のデータが記録されています。

### 📊 記録されるデータ項目（カラム）

1. **`Time`** [s] : シミュレーションの経過時間
2. **`Pelvis_Pitch_deg`** [°] : 骨盤の前後傾
3. **`Pelvis_Roll_deg`** [°] : 骨盤の側方傾斜
4. **`Pelvis_Yaw_deg`** [°] : 骨盤の回旋
5. **`RHip_deg`** [°] : 股関節の角度（プラスが屈曲、マイナスが伸展）
6. **`RKnee_deg`** [°] : 膝関節の角度（マイナスが屈曲、プラスが伸展）
7. **`RFoot_Y_m`** [m] : 足部のY軸方向の位置（進行方向における絶対座標。前方に振り出された距離の確認に使えます）

ExcelやGoogleスプレッドシートでこのデータを開き、折れ線グラフを作成することで、「トルクに対する各関節の角度変化の遅れ」や「衝撃吸収（ブレーキ）の効果」などを視覚的に分析することができます。
