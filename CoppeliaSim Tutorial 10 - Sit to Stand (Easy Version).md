# CoppeliaSim Tutorial 10 (改)
## 立ち上がり介助実験：直立モデルからのアプローチ

「座った状態」から作ると関節の軸や可動範囲の設定が難しいため、今回は**「立った状態（直立）」** でモデルを作成し、そこから「座る→立つ」動きを実現します。
この方法なら、**「角度0度 ＝ 直立」** という非常に直感的な設定になります。

---

## 1. シーンの準備
1. **File** > **New Scene** で新しいシーンを作成します。
2. **Floor**（床）があることを確認します（なければ作成）。

### 椅子（Chair）の作成
座るための椅子を用意します。
1. **Add** > **Primitive shape** > **Cuboid**
2. サイズ: **X=0.4, Y=0.4, Z=0.05**
3. 位置: **X=-0.25, Y=0, Z=0.375** （足元に空間を空けるため、少し後ろ（Xマイナス方向）に配置します）
4. 名前: `ChairSeat`
5. **Dynamic**: **OFF** (Static)
6. **Respondable**: **ON**

---

## 2. 人体モデルの作成（直立姿勢）

今回は関節角度 **0度** で **直立** している状態を作ります。

### 2.1 骨盤（Pelvis）
1. **Add** > **Primitive shape** > **Cuboid**
2. サイズ: **X=0.15, Y=0.25, Z=0.15**
3. 質量: **2.0 kg**
4. 位置: **X=0, Y=0, Z=0.90** （立ったときの骨盤の高さ）
5. 名前: `Pelvis`
6. **Dynamic** & **Respondable**

### 2.2 右脚（Standing）

#### 右股関節（RHipJoint）
1. **Add** > **Joint** > **Revolute**
2. 名前: `RHipJoint`
3. 位置: **X=0, Y=-0.08, Z=0.825** （骨盤の下）
4. **Orientation**: **Alpha=-90, Beta=0, Gamma=0** （軸は左向き）
5. **Mode**: **Dynamic mode** (Control loop enabled, Motor enabled)
    - **Control Mode**: **Position** (重要)
    - **Position is cyclic**: **OFF**（無限回転させない）
    - **Max Torque**: **500** (重要)
    - **Pos. min [deg]**: **-180**
    - **Pos. range [deg]**: **360**
6. 親: `Pelvis`

#### 右大腿（RThigh）
1. **Add** > **Primitive shape** > **Cylinder**
2. サイズ: **半径 0.04, 長さ 0.35**
3. 質量: **1.5 kg**
4. 名前: `RThigh`
5. 位置: **X=0, Y=-0.08, Z=0.65** （股関節の真下）
6. **Orientation**: **Alpha=0, Beta=0, Gamma=0** （垂直）
7. 親: `RHipJoint`

#### 右膝関節（RKneeJoint）
1. **Add** > **Joint** > **Revolute**
2. 名前: `RKneeJoint`
3. 位置: **X=0, Y=-0.08, Z=0.475** （大腿の下端）
4. **Orientation**: **Alpha=-90, Beta=0, Gamma=0**
    - ※ 軸設定は股関節と同じ
5. 設定:
    - **Mode**: **Dynamic mode**
    - **Control Mode**: **Position**
    - **Position is cyclic**: **OFF**
    - **Max Torque**: **500** (体重を支えるため強めに)
    - **Pos. min [deg]**: **-180**
    - **Pos. range [deg]**: **360**
6. 親: `RThigh`

#### 右下腿（RShank）
1. **Add** > **Primitive shape** > **Cylinder**
2. サイズ: **半径 0.035, 長さ 0.40**
3. 質量: **1.0 kg**
4. 名前: `RShank`
5. 位置: **X=0, Y=-0.08, Z=0.275**
6. **Orientation**: **Alpha=0, Beta=0, Gamma=0** （垂直）
7. 親: `RKneeJoint`

#### 右足首（RAnkleJoint）
1. **Add** > **Joint** > **Revolute**
2. 名前: `RAnkleJoint`
3. 位置: **X=0, Y=-0.08, Z=0.075**
4. **Orientation**: **Alpha=-90, Beta=0, Gamma=0**
5. 設定: **Dynamic mode**
    - **Control Mode**: **Position**
    - **Position is cyclic**: **OFF**
    - **Max Torque**: **500**
    - **Pos. min [deg]**: **-180**
    - **Pos. range [deg]**: **360**
6. 親: `RShank`

#### 右足部（RFoot）
1. **Add** > **Primitive shape** > **Cuboid**
2. サイズ: **X=0.20, Y=0.08, Z=0.05** （少し長めに）
3. 質量: **0.4 kg**
4. 名前: `RFoot`
5. 位置: **X=0.05, Y=-0.08, Z=0.025** （足先が出るように少し前へ）
6. **Orientation**: **Alpha=0, Beta=0, Gamma=0**
7. 親: `RAnkleJoint`

### 2.3 左脚の作成（コピー）
1. Hierarchyで `RHipJoint` 〜 `RFoot` を選択しコピー＆ペースト。
2. 名前を `L...` に変更。
3. `LHipJoint` を `Pelvis` の子にする。
4. Y座標を反転（0.08）。

---

### 2.4 関節設定の最終確認（重要）
スクリプトで制御する前に、全てのジョイント（`RHipJoint`, `RKneeJoint`, ... `LAnkleJoint`）が正しく設定されているか確認します。これらが間違っていると、スクリプトを実行しても動きません。

| 項目                      | 設定値       | 備考                                                                  |
| :------------------------ | :----------- | :-------------------------------------------------------------------- |
| **Control Mode**          | **Position** | Dynamic Properties 内。これ以外だと動きません。                       |
| **Position is cyclic**    | **OFF**      | Scene Object Properties 内。チェックを外す。                          |
| **Pos. min [deg]**        | **-180**     | 同上。可動域の下限。                                                  |
| **Pos. range [deg]**      | **360**      | 同上。可動域の範囲。                                                  |
| **Max. velocity [deg/s]** | **90**       | Dynamic Properties 内。ゆっくり動かすため下げる（デフォルト360→90）。 |

---

## 3. スクリプトの作成（座る → 立つ）

`Pelvis` に以下のスクリプトを追加してください。

```lua
sim = require('sim')

function sysCall_init()
    -- Get object handles (Modern API)
    -- ":/" means search for the object by alias anywhere in the scene
    rHip = sim.getObject(":/RHipJoint")
    lHip = sim.getObject(":/LHipJoint")
    rKnee = sim.getObject(":/RKneeJoint")
    lKnee = sim.getObject(":/LKneeJoint")
    rAnkle = sim.getObject(":/RAnkleJoint")
    lAnkle = sim.getObject(":/LAnkleJoint")
    
    timer = 0
end

function sysCall_actuation()
    dt = sim.getSimulationTimeStep()
    timer = timer + dt
    
    local targetHip = 0
    local targetKnee = 0
    local targetAnkle = 0
    
    -- PHASE 1: Sit Down (0s - 2s)
    -- 直立(0度)の状態から、膝を90度に曲げて座ります
    if timer < 2.0 then
        -- 座る動作
        targetHip = -50 * math.pi / 180   -- 股関節（前傾を浅くする：バランス維持）
        targetKnee = 90 * math.pi / 180   -- 膝を曲げる
        targetAnkle = 20 * math.pi / 180  -- 足首を曲げる（背屈：膝を前に出す）
        
    -- PHASE 2: Stand Up (2s - 5s)
    -- 全てを0度（直立）に戻します
    elseif timer < 5.0 then
        -- 立ち上がり動作
        targetHip = 0     -- 直立（伸展）
        targetKnee = 0    -- 直立（伸展）
        targetAnkle = 0   -- 直立
        
    else
        -- キープ
        targetHip = 0
        targetKnee = 0
        targetAnkle = 0
    end
    
    sim.setJointTargetPosition(rHip, targetHip)
    sim.setJointTargetPosition(lHip, targetHip)
    sim.setJointTargetPosition(rKnee, targetKnee)
    sim.setJointTargetPosition(lKnee, targetKnee)
    sim.setJointTargetPosition(rAnkle, targetAnkle)
    sim.setJointTargetPosition(lAnkle, targetAnkle)
end
```

---

## 4. 実行手順
1. **Play** を押します。
2. モデルは最初 **空中で直立** していますが、重力で少し落ちて床に立ちます（または椅子に触れます）。
3. **0秒〜2秒**: 膝が曲がり、後ろにある椅子に向かって座ります（スクワット）。
4. **2秒〜**: 膝が伸びて（0度に向かって）、再び立ち上がります。

この方法なら、「立ち上がり＝0度に戻る」だけなので、符号で迷うことはありません！
