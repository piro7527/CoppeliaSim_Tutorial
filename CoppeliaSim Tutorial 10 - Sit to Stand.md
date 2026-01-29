# CoppeliaSim Tutorial 10
## 立ち上がり介助実験：モデル作成と制御

CoppeliaSimのチュートリアル第10弾です。今回は**椅子からの立ち上がり動作**（Sit-to-Stand）のシミュレーションを作成します。
骨盤・大腿・下腿・足部からなる4リンクモデルを作成し、椅子に座った状態から関節トルクを制御して立ち上がる動作を実現します。

---

## 🎯 目的
- **立ち上がり用モデル**（座った姿勢）を作成する
- **椅子と環境**をセットアップする
- **関節制御**により、椅子から立ち上がる動作を実現する
- 重心移動と床反力の関係を理解する

---

## 🛠 使用環境
- CoppeliaSim（Bullet 物理エンジン）
- **前提**: Tutorial 1〜7程度の知識があること

---

## 1. シーンと環境の作成

まずは椅子と床を作成します。
**推奨**: ファイルを新しく作成して、真っさらにした状態で始めてください（File > New Scene）。

### 1.1 床（Floor）の確認
シーンに既に `Floor` がある場合はそのままでOKです。ない場合は以下で作成します（通常はデフォルトで `ResizableFloor` などがあります）。
もしなければ：
1. **Add** > **Primitive shape** > **Plane**
2. サイズを適当に（例: 5m x 5m）設定して作成し、`Floor` と名前を付けます。
3. **Body is respondable** をONにします。
4. **Body is dynamic** はOFF（固定）にします。

### 1.2 椅子（Chair）の作成
座面と背もたれを持つシンプルな椅子を作成します。

**座面（Seat）:**
1. **Add** > **Primitive shape** > **Cuboid**
2. サイズ: **X=0.4, Y=0.4, Z=0.05**
3. 位置 (Position): **Z = 0.375** （高さ40cmの椅子の座面中心）
   - ※ 座面上面 = 0.375 + 0.025 = **0.40**
4. 名前を `ChairSeat` に変更
5. **Static** に設定（**Body is dynamic** のチェックを**外す**）
6. **Respondable** は **ON**

**脚（ChairLegs） - 省略可:**
今回は簡単のため、座面が空中に浮いている状態（Staticなので落ちない）でも実験は可能です。見た目を気にする場合は脚を追加してください。

---

## 2. 人体モデルの作成（座位姿勢）

椅子に座った状態のモデルを作成します。
モデル構成：**Pelvis** (骨盤), **Thigh** (大腿), **Shank** (下腿), **Foot** (足部)
左右対称に作成します。

モデルは **X軸方向** を向いて座る設定にします。

### 2.1 骨盤（Pelvis）
1. **Add** > **Primitive shape** > **Cuboid**
2. サイズ: **X=0.15, Y=0.25, Z=0.15**
3. 質量 (Mass): **2.0 kg**
4. 位置: **X=0, Y=0, Z=0.475** （座面の上に配置）
   - ※ 座面の上面(Z=0.40) + 骨盤の高さ半分(0.075) = 0.475
5. 名前: `Pelvis`
6. **Dynamic** & **Respondable**

### 2.2 右脚の作成

#### 右股関節（RHipJoint）
1. **Add** > **Joint** > **Revolute**
2. 名前: `RHipJoint`
3. 位置: **X=0, Y=-0.08, Z=0.44** （骨盤の右下寄り）
   - ※ 座面(0.40) + 大腿半径(0.04) = 0.44
   - ※ 座標系の注意: X軸を「前」とすると、Y軸は「左」になります（右手系）。そのため、**右**側は **Yマイナス** になります。
4. **Orientation**: **Alpha=-90, Beta=0, Gamma=0**
   - **重要**: この設定により、回転軸(Z軸)は**左向き**になります。
   - **左向きの軸**の場合：
     - **右ねじの法則**により、**正回転**は**伸展**（Thighが下へ向く）、**負回転**は**屈曲**（Thighが上へ向く）となります。
5. **Mode**: **Dynamic mode** に設定 ← **重要！**
   - ジョイントをダブルクリック > Scene Object Properties で **Mode** ドロップダウンを確認
   - 「Dynamic mode」でないと、リンク同士が物理的に接続されずバラバラになります
6. 親: `Pelvis`

#### 右大腿（RThigh）
1. **Add** > **Primitive shape** > **Cylinder**
2. サイズ: **半径 0.04, 長さ 0.35**
3. 質量: **1.5 kg**
4. 名前: `RThigh`
5. **Body is dynamic**: **ON** ← 重要！
6. **Body is respondable**: **ON**
7. 位置: **X=0.175, Y=-0.08, Z=0.44** （股関節から前方へ）
8. **Orientation**: **Alpha=0, Beta=90, Gamma=0** （横倒し＝水平）
9. 親: `RHipJoint` ← **Position/Orientationを設定した後に親を設定**

#### 右膝関節（RKneeJoint）
1. **Add** > **Joint** > **Revolute**
2. 名前: `RKneeJoint`
3. 位置: **X=0.35, Y=-0.08, Z=0.44** （大腿の先端）
4. **Orientation**: **Alpha=-90, Beta=0, Gamma=0**
   - 回転軸は股関節と同じく左向き。
   - **負回転**で**伸展**（Shankが下がる/伸びる）、**正回転**で**屈曲**（Shankが上がる）。
5. 親: `RThigh`

#### 右下腿（RShank）
1. **Add** > **Primitive shape** > **Cylinder**
2. サイズ: **半径 0.035, 長さ 0.40**
3. 質量: **1.0 kg**
4. 名前: `RShank`
5. **Body is dynamic**: **ON**
6. **Body is respondable**: **ON**
7. 位置: **X=0.35, Y=-0.08, Z=0.24** （膝から下方へ）
8. **Orientation**: **Alpha=0, Beta=0, Gamma=0** （垂直）
9. 親: `RKneeJoint`

#### 右足首関節（RAnkleJoint）
1. **Add** > **Joint** > **Revolute**
2. 名前: `RAnkleJoint`
3. 位置: **X=0.35, Y=-0.08, Z=0.04** （下腿の下端）
4. **Orientation**: **Alpha=-90, Beta=0, Gamma=0**
5. 親: `RShank`

#### 右足部（RFoot）
1. **Add** > **Primitive shape** > **Cuboid**
2. サイズ: **X=0.18, Y=0.08, Z=0.04**
3. 質量: **0.4 kg**
4. 名前: `RFoot`
5. **Body is dynamic**: **ON**
6. **Body is respondable**: **ON**
7. 位置: **X=0.40, Y=-0.08, Z=0.02** （床の上に接地）
8. 親: `RAnkleJoint`
9. 色: 分かりやすくするため、少し色を変えておくと良いでしょう。

> ⚠️ **重要**: 各オブジェクトは、**Position と Orientation を設定してから親を設定**してください。親を先に設定すると、座標がローカル座標系に変換されて意図しない位置になることがあります。

### 2.3 左脚の作成（コピー）
1. Scene hierarchyで `RHipJoint` から `RFoot` までを**全て選択**します。
   - ※ **Shiftキー（またはCtrl/Cmdキー）を押しながら**、階層内の全てのオブジェクトを **一つずつクリック** して選択してください。
2. **Ctrl+C** でコピーし、**Ctrl+V** でペーストします。
   - ※ ペーストすると、`Pelvis` と同じ階層（外側）に作られてしまうことがあります。
3. **親子関係の再設定（重要）**:
   - ペーストしてできた `RHipJoint0`（または `RHipJoint` のコピー）をドラッグして、**`Pelvis` の上にドロップ**します。
   - これにより、左脚が `Pelvis` の子オブジェクトになります。
   - 階層が `Pelvis` > `LHipJoint` ... となっていることを確認してください。
4. ペーストしたオブジェクトの名前を `LHipJoint` ... `LFoot` に変更します。
5. **Y座標の符号を反転**させます（例: Y=-0.08 → **Y=0.08**）。
   - **ヒント**: 親子関係が組まれているため、親である `LHipJoint` の座標を変更すれば、子オブジェクト（`LThigh` 以降）も自動的に追従して移動します。
   - `LHipJoint`: Y=0.08 に変更すれば、以下も自動的に Y=0.08 になります（念のため確認してください）。
   - `LHipJoint`: Y=0.08
   - `LThigh`: Y=0.08
   - `LKneeJoint`: Y=0.08
   - ...
5. **Orientation はそのまま**でOKです（左右で同じ値）。
   - 左脚の軸も左向きになるため、正負の回転方向の意味は右脚と同じになります。

### 2.4 モデルの確認
- 椅子に座り、足が床ついている状態になっていますか？
- 階層構造は以下のようになっているはずです：
```
Pelvis
 ├── RHipJoint -> RThigh -> RKneeJoint -> RShank -> RAnkleJoint -> RFoot
 └── LHipJoint -> LThigh -> LKneeJoint -> LShank -> LAnkleJoint -> LFoot
```

### 2.5 座標の確認表（重要）
画像で隙間ができている場合は、以下の値を再確認してください（すべてWorld座標系）：

| オブジェクト    | X     | Y     | Z (高さ)  | 備考                              |
| --------------- | ----- | ----- | --------- | --------------------------------- |
| **Pelvis**      | 0.0   | 0.0   | **0.475** | 座面の上                          |
| **RHipJoint**   | 0.0   | -0.08 | **0.44**  |                                   |
| **RThigh**      | 0.175 | -0.08 | **0.44**  | 水平                              |
| **RKneeJoint**  | 0.35  | -0.08 | **0.44**  |                                   |
| **RShank**      | 0.35  | -0.08 | **0.24**  | **長さが 0.40m** であることを確認 |
| **RAnkleJoint** | 0.35  | -0.08 | **0.04**  | 足の上                            |
| **RFoot**       | 0.40  | -0.08 | **0.02**  | 床の上                            |

> **ヒント**: 親子関係を作った後に座標がずれた場合は、Scene hierarchyで一度オブジェクトを親から切り離し（ドラッグして空の場所にドロップ）、再配置してから数値を入力し直してください。

> [!WARNING]
> **シミュレーション実行時の注意**
> この段階でシミュレーションを再生（Play）した際、モデルが**飛び上がったり、お尻と足がバラバラになったりする場合**は、設定に誤りがあります。
> - **原因1**: ジョイントの **Mode** が **Dynamic mode** になっていない（これが一番多いです）。全てのジョイントを確認してください。
> - **原因2**: オブジェクト同士が激しく干渉している。ただし、正しくジョイントで接続されていれば（Dynamic modeなら）、親子間の干渉は無視されるはずです。
> - **バラバラになる場合**は、次のステップ（制御モード設定）に進む前に、必ず修正してください。

---

## 3. ジョイントの制御モード設定

立ち上がり動作のため、各関節をトルク制御または位置制御できるようにします。
今回はシンプルに **位置制御 (Position control)** で目標角度を与えて動かします（高トルクで無理やり動かすイメージ）。

### 3.1 各関節の設定手順

各ジョイントを **1つずつ選択** し、以下の手順で設定します。

1. **Double click** > **Dynamic properties dialog** を開きます。
2. **Control mode** のドロップダウン（デフォルトでは「Free」）をクリックし、**Position** を選択します。
3. 以下の表を参考に **Max. torque [N*m]** を設定します。

### 3.2 関節ごとの推奨設定値

| 関節名                            | Target angle [deg] | Max. torque [N*m] | Max. velocity [deg/s] |
| --------------------------------- | ------------------ | ----------------- | --------------------- |
| **RHipJoint** / **LHipJoint**     | 0.00               | **150**           | 360.00                |
| **RKneeJoint** / **LKneeJoint**   | 0.00               | **150**           | 360.00                |
| **RAnkleJoint** / **LAnkleJoint** | 0.00               | **50**            | 360.00                |

> **各パラメータの意味**:
> - **Target angle**: 目標角度。スクリプトで動的に設定するため **0.00** のままでOK
> - **Max. torque**: 関節が発揮できる最大トルク。体重を支える股関節・膝は大きめに設定
> - **Max. velocity**: 関節の最大回転速度。デフォルト値（360 deg/s）で十分
> - うまく立ち上がれない場合は、Max. torque を **200** や **300** に増やしてみてください

---

## 4. 立ち上がりスクリプトの作成

`Pelvis` にスクリプトを追加して、各関節を動かします。

1. **Hierarchyで `Pelvis` を選択**します（※重要）。
2. **Add** > **Script** > **Child script (Non-threaded)**
   - こうすることで、スクリプトが `Pelvis` の下に紐づき、アイコンが `Pelvis` の横に表示されます。
3. 以下のLuaコードを記述します。

```lua
function sysCall_init()
    -- ハンドルの取得
    rHip = sim.getObjectHandle("RHipJoint")
    lHip = sim.getObjectHandle("LHipJoint")
    rKnee = sim.getObjectHandle("RKneeJoint")
    lKnee = sim.getObjectHandle("LKneeJoint")
    rAnkle = sim.getObjectHandle("RAnkleJoint")
    lAnkle = sim.getObjectHandle("LAnkleJoint")

    -- 動作フェーズ管理
    phase = 0
    timer = 0
end

function sysCall_actuation()
    dt = sim.getSimulationTimeStep()
    timer = timer + dt
    
    -- ターゲット角度の変数（ラジアン）
    local targetHip = 0
    local targetKnee = 0
    local targetAnkle = 0

    -- 関節軸の設定に基づく回転方向（Alpha=-90の場合）：
    -- Hip:  負(-45) = 屈曲（前屈） / 正(+10) = 伸展（直立）
    -- Knee: 正(+90) = 屈曲（正座） / 負(-90) = 伸展（直立）
    
    -- フェーズ1: 重心前方移動（お辞儀） [0.0s - 1.0s]
    if timer < 1.0 then
        -- 股関節を深く曲げる（上体を前に倒す）
        targetHip = -45 * math.pi / 180   -- 屈曲
        targetKnee = 0                    -- そのまま
        targetAnkle = 20 * math.pi / 180  -- 軽く背屈してバランスをとる
        
    -- フェーズ2: 離殿・伸展（立ち上がり） [1.0s - 3.0s]
    elseif timer < 3.0 then
        -- 股関節・膝関節を伸展（直立へ）
        
        targetHip = 10 * math.pi / 180    -- 伸展（直立姿勢へ）
        targetKnee = -90 * math.pi / 180   -- 伸展（膝を伸ばす）
        targetAnkle = 10 * math.pi / 180  -- バランス調整
        
    else
        -- 3.0秒以降は姿勢保持
        targetHip = 10 * math.pi / 180
        targetKnee = -90 * math.pi / 180
        targetAnkle = 10 * math.pi / 180
    end
    
    -- 制御実行（P制御）
    sim.setJointTargetPosition(rHip, targetHip)
    sim.setJointTargetPosition(lHip, targetHip)
    sim.setJointTargetPosition(rKnee, targetKnee)
    sim.setJointTargetPosition(lKnee, targetKnee)
    sim.setJointTargetPosition(rAnkle, targetAnkle)
    sim.setJointTargetPosition(lAnkle, targetAnkle)
end
```

---

## 5. 実験と調整

### 5.1 とりあえず実行
**Play** ボタンを押して動きを確認します。
- **お辞儀をするか**: 最初の1秒で上半身が前に倒れるはずです。倒れない、逆に反る場合は `targetHip` の符号を再確認。
- **立ち上がるか**: 1秒後から膝が伸びて、体が持ち上がるはずです。膝が変な方向に曲がるなら `targetKnee` の符号を確認。

### 5.2 トラブルシューティング
- **後ろに倒れる**: 「お辞儀」の角度（-45度）をもっと深くする（-50, -60）か、足の位置を少し手前に引いてみてください。
- **力が足りない**: 各ジョイントの `Max torque` を増やしてください（150 -> 300など）。

---

## 6. 課題
1. **スムーズな立ち上がり**: パラメータを調整して、転倒せずに綺麗に立ち上がるシーケンスを作ってください。
2. **座面の高さ**: 椅子の高さを変えると、立ち上がりの難易度はどう変わりますか？
3. **介助**: もし自力で立ち上がれない（トルク制限を弱くするなど）場合、外部からどのような力を加えれば立てるでしょうか？（Tutorial 9の応用）

---

次回は、このモデルを使って実際に「介助プロトコル」を検証していきます。
