# CoppeliaSim Tutorial 13
## 物理演算による立ち上がり (Sit-to-Stand with Physics)

Tutorial 12では、スクリプトで仮想的な力（Antibody/Support Force）を加えて立ち上がり動作を補助しました。
今回は、**物理演算（Physics）** を最大限に活用し、実際に椅子に座り、そこから脚力（トルク）だけで立ち上がるシミュレーションを行います。

---

## 🎯 目的
1.  **「椅子」** の物理特性（Respondable）を有効にする
2.  **「骨盤」** の物理特性（Respondable）を有効にする
3.  スクリプトから「反力計算」を削除し、純粋な関節制御で立ち上がる

---

## 1. 環境設定（物理プロパティの変更）

Tutorial 12 のモデル（`sitToStand.ttt` など）を使用します。

### 1-0. 床（Floor）の確認
足が乗るための「床」が必要です。
シーン内に `Floor` または `Plane` があり、**Respondable が ON** になっていることを確認してください。

### 1-1. 椅子の設定変更（足元スペースの確保）
立ち上がりやすくするために足を少し後ろに引きたいのですが、椅子が「箱（ブロック）」のままだと踵が当たって引けません。
そこで、椅子を「座面だけの板（空中に固定）」に変更し、下にスペースを作ります。

1.  Scene Hierarchy で **`Chair`** を選択します。
2.  **View** > **Apply Customization** (または Geometry properties) でサイズを変更します：
    *   Size: **X=0.40, Y=0.40, Z=0.05** （薄い板にします）
3.  位置（Z）を調整します：
    *   Position: **Z=0.425** （床から浮かせます。上面の高さは 0.45m で変わりません）
4.  **Scene Object Properties** > **Common** > **Dynamic properties**：
    *   **Respondable**: **ON**
    *   **Dynamic**: **OFF** (Static)
    *   これで「空中に浮いた座面」になり、足が椅子の下に入り込めるようになります。

### 1-2. 骨盤の大型化（HATモデル化）
立ち上がり動作を有利にするため、現在の「骨盤ブロック」を、**「頭部・上肢・体幹（HAT）」を含めた縦長のオブジェクト** に変更します。
高さ（Z）を大きくすることで、重心位置（CoM）が上がり、前傾動作（お辞儀）をした際に重心がより前方に移動しやすくなります（テコの原理）。

1.  Scene Hierarchy で **`Pelvis`** を選択します。
2.  **View** > **Apply Customization** (または Geometry properties) でサイズを変更します：
    *   Size: **X=0.15, Y=0.25, Z=0.60** （縦長にします）
3.  位置（Z）を調整します：
    *   Position: **Z=1.125**
    *   これで股関節の上にちょうど上半身が乗る形になります（0.825 + 0.30）。
4.  **Scene Object Properties** > **Common** で以下を設定します：
    *   **Respondable**: **ON**
    *   （`RThigh`, `LThigh` は OFF のまま）

### 1-2a. モデルの質量設定（参考）
このモデルは **体重60kgの人間** を想定した質量設定になっています（Tutorial 8参照）。

| 部位       | 説明                       | 質量    | 割合   |
| ---------- | -------------------------- | ------- | ------ |
| **Pelvis** | 上半身（頭・腕・体幹）相当 | 41.0 kg | 約68%  |
| **Thigh**  | 大腿（片側）               | 6.0 kg  | 約10%  |
| **Shank**  | 下腿（片側）               | 2.5 kg  | 約4%   |
| **Foot**   | 足部（片側）               | 1.0 kg  | 約1.6% |

> **合計**: 41 + (6+2.5+1)×2 = **60 kg**

この設定により、シミュレーションで得られるトルク値（例：膝の伸展トルク約40 N*m）は、実際の人間の立ち上がり動作と同程度の現実的な値になります。

### 1-3. 足部（RFoot）の固定解除 (重要)
**転倒しないようにバランス制御を行う** ためには、足が床に固定されていては意味がありません。
そこで、足を床から切り離し、物理演算の対象（Dynamic）にします。

1.  Scene Hierarchy で **`RFoot`** を選択します。
2.  **Scene Object Properties** > **Common** > **Dynamic properties** で以下を設定します：
    *   **Dynamic**: **ON** (チェックを入れる)
    *   これで足は物理法則に従い、バランスを崩せば倒れるようになります。
3.  **重要**: 足が軽すぎると摩擦力が足りずに滑ってしまいます。質量（Mass）を **2.0kg** 程度まで増やしてください。
    *   物理学のおさらい：摩擦力 $F = \mu N$ （$\mu$:摩擦係数, $N$:垂直抗力）。
    *   質量を増やすことで $N$ が大きくなり、結果として強い摩擦力（グリップ）が得られます。

### 1-4. ワイドベース化（擬似的な両足モデル）
ご指摘の通り、**一本足（片足）だけでバランスを取るのは非常に困難** です（左右にすぐ倒れてしまいます）。
そこで、足の幅（Y軸）を広げ、左右の足を一本にまとめたような「ワイドモデル」に変更します。

**（なぜ2本足にしないのか？）**
2本足にすると、右足と左足の動きを完全に同期させる必要があり、制御もデバッグも複雑になります。
まずは **「立ち上がりの重心制御」** という本質的な課題に集中するため、あえて1本の太い足で代用します。

1.  Scene Hierarchy で **`RFoot`** を選択します。
2.  **View** > **Apply Customization** (または Geometry properties) でサイズを変更します：
    *   Size: **X=0.25, Y=0.30, Z=0.05** （幅と長さを広げます）
    *   **幅（Y）**: 左右のバランスを安定させます（擬似両足）。
    *   **長さ（X）**: 前後の支持基底面を広げ、立ち上がり時の前方転倒を防ぎます。
3.  これで前後・左右ともに安定性が劇的に向上し、**「重心制御」** に集中できるようになります。

### 1-5. 脚部のセンタリング（Y軸位置の修正）
現在、右脚（RFoot〜RHip）は `Y=-0.08` にあり、骨盤の中心（Y=0）からずれています。
これでは片足立ちと同じで、常に左側に倒れる力が働いてしまいます。
脚部全体を体の真ん中に移動させます。

1.  Scene Hierarchy で **`RFoot`** を選択します（子オブジェクトごと移動します）。
2.  位置（Y）を修正します：
    *   Position: **Y=0.0**
    *   （注意：これにより、子オブジェクトである Pelvis も一緒に動いてしまいます）
3.  Scene Hierarchy で **`Pelvis`** を選択します。
4.  位置（Y）を修正（リセット）します：
    *   Position: **Y=0.0** （**World座標** で確認してください）
    *   または、親（RHipJoint）に対する **Relative Position** を **Y=0** にします。
5.  これで「足」も「骨盤」も、すべてのパーツが Y=0（正中線）に揃いました。

これで、シミュレーションを開始すると「骨盤が椅子の上に物理的に乗っかる」ようになります。

---

## 2. スクリプトの修正（Physics Version）

物理的な椅子が支えてくれるため、スクリプトで「仮想反力（supportForce）」を計算する必要がなくなりました。
シンプルになったスクリプトに書き換えます。

`RFoot` の子スクリプトを開き、中身をすべて以下のように書き換えてください。

```lua
sim = require('sim')

function sysCall_init()
    rAnkle = sim.getObject(":/RAnkleJoint")
    rKnee  = sim.getObject(":/RKneeJoint")
    rHip   = sim.getObject(":/RHipJoint")
    -- pelvis = sim.getObject(":/Pelvis") -- 力を加える必要がないため取得不要

    -- グラフ用
    graphHandle = sim.getObject(":/TorqueGraph")
    if graphHandle ~= -1 then
        torqueStream = sim.addGraphStream(graphHandle, "Knee Torque (Physics)", "N*m", 0, {1, 0, 0})
    end
    
    timer = 0
end

function sysCall_actuation()
    dt = sim.getSimulationTimeStep()
    timer = timer + dt
    
    -- --- 動作タイミングの設定（秒） ---
    -- 物理的な衝突が落ち着くまで少し時間を置くのがコツです
    -- 0〜1.0s: 初期安定化
    local t0 = 1.0  -- 動作開始
    local t1 = 2.0  -- 離殿（Seat-off）＆ 伸展開始
    local t2 = 4.0  -- 立ち上がり完了

    -- --- 動作フェーズ（角度）の設定 ---
    
    -- 初期位置（座位）：
    local sitAnkle = 0 * math.pi / 180
    local sitKnee  = -90 * math.pi / 180
    local sitHip   = 90 * math.pi / 180
    
    -- 前傾姿勢（離殿直前）：
    -- 重心を足の上に持ってくるため、深い前傾が必要です
    -- ここが浅いと、お尻が持ち上がらず後ろに倒れます
    local leanAnkle = 40 * math.pi / 180  -- 足首を強く曲げる
    local leanKnee  = -100 * math.pi / 180 -- 膝も少し深く
    local leanHip   = 136 * math.pi / 180 -- 体幹を大きく前へ（ユーザー実績値: 136度）
    
    -- 直立姿勢：
    local standAnkle = 0
    local standKnee  = 0
    local standHip   = 0

    -- --- 制御変数の計算 ---
    local targetAnkle = sitAnkle
    local targetKnee  = sitKnee
    local targetHip   = sitHip

    if timer < t0 then
        -- 【Phase 0】 初期安定化（椅子に座る）
        -- 物理演算で「ドスン」と座るので、少し待機します
        targetAnkle = sitAnkle
        targetKnee  = sitKnee
        targetHip   = sitHip
        
    elseif timer < t1 then
        -- 【Phase 1】 前傾動作 (Lean)
        -- 重心を前方（足の上）へ移動させる重要なフェーズ
        local duration = t1 - t0
        local ratio = (timer - t0) / duration
        targetAnkle = (1 - ratio) * sitAnkle + ratio * leanAnkle
        targetKnee  = (1 - ratio) * sitKnee  + ratio * leanKnee
        targetHip   = (1 - ratio) * sitHip   + ratio * leanHip
        
    elseif timer < t2 then
        -- 【Phase 2】 立ち上がり (Extension)
        local duration = t2 - t1
        local ratio = (timer - t1) / duration
        targetAnkle = (1 - ratio) * leanAnkle + ratio * standAnkle
        targetKnee  = (1 - ratio) * leanKnee  + ratio * standKnee
        targetHip   = (1 - ratio) * leanHip   + ratio * standHip
        
    else
        -- 【Phase 3】 直立保持
        targetAnkle = standAnkle
        targetKnee  = standKnee
        targetHip   = standHip
    end
    
    sim.setJointTargetPosition(rAnkle, targetAnkle)
    sim.setJointTargetPosition(rKnee, targetKnee)
    sim.setJointTargetPosition(rHip, targetHip)

    -- ※ sim.addForceAndTorque (Antibody force) は削除されました
end

function sysCall_sensing()
    if graphHandle ~= -1 then
        local torque = sim.getJointForce(rKnee)
        sim.setGraphStreamValue(graphHandle, torqueStream, torque)
    end
end
```

---

## 3. 実行と観察

シミュレーションを実行してみましょう。

1.  **開始直後**: ロボットが「ドスン」と椅子に座る挙動が見られるはずです（物理衝突）。
2.  **Phase 1 (〜2.0s)**: 体幹を前傾させます。
    *   この時、**足が地面から浮かないか** 確認してください。
    *   もし後ろに倒れるようなら、`leanHip` (前傾角度) をもっと深くするか、`leanAnkle` を調整する必要があります。
    *   逆に、`Chair` の高さを少し上げると立ちやすくなる場合もあります。
3.  **Phase 2 (2.0s〜)**: 膝を伸ばして立ち上がります。
    *   **ここが最難関です。**
    *   重心が足の上に乗り切っていないと、お尻が浮いた直後に後ろへ転倒します。
    *   逆に前傾しすぎると、前に倒れる可能性があります。

### コツ：バランスの調整
物理シミュレーションによる立ち上がりは、**「重心制御」** が命です。
うまくいかない場合は、以下のパラメータを微調整してみてください：

*   `leanAnkle`（足首の背屈角度）：大きくすると、脛（すね）が前に倒れ、重心が前に行きやすくなります。
*   `leanHip`（股関節の屈曲角度）：大きくすると、上半身が深くお辞儀します。

---

## 4. なぜこれが難しいのか？

Tutorial 12 ではスクリプトが「持ち上げる力」を補助していたため、多少重心がズレていても強制的に立ち上がれました。
しかし今回は、**現実の人間と同じく**、足裏の支持基底面（Base of Support）の中に重心（CoM）を入れないと、物理的に立つことができません。

これが成功すれば、非常にリアルなバイオメカニクス・シミュレーションができたことになります！

---

## 5. うまく立てない場合のヒント（Stability Tips）

物理シミュレーションでは、少しのパラメータ変化が挙動に大きく影響します。

### 5-1. 足が滑る場合
*   **質量（Mass）を増やす**: 手順1-3で設定した通り、足の質量を増やすのが最も手軽で効果的です。2.0kgでも滑るなら、3.0kg〜5.0kgまで増やしてみてください（ロボットとしては重すぎますが、シミュレーションの安定化テクニックとして有効です）。
*   **摩擦係数（Friction）**: CoppeliaSimのデフォルト素材はある程度の摩擦を持っていますが、床（Floor）と足（Foot）の材質設定（Material properties）を見直すことで、さらに滑りにくく設定可能です。

### 5-2. 重心が後ろに倒れる場合
*   **前傾（Lean）を深くする**: 変数 `leanHip`（股関節屈曲）を **140度** くらい（または実績値 136度）まで深くしてみてください。お辞儀が深くなるほど重心は前方に移動します。
*   **足首（Ankle）の角度**: `leanAnkle`（背屈）を大きくすると、膝が前に出て、その分お尻も前に行きます。

### 5-3. 勢いをつける（Dynamic Effect）
### 5-4. つま先が浮いてしまう（Forefoot Lift-off）
ご指摘のように、下腿を前に倒そう（背屈）とした瞬間、逆に「つま先が浮いてしまう」現象が起きることがあります。
これは、**重心（CoM）が踵（かかと）より後ろにある状態** で、無理に足首を曲げようとした反動です。

**対策：足を引く（Posterior Foot Placement）**
*   立ち上がり動作の基本として、**「足を引く（膝の下、あるいは少し後ろ）」** ことが重要です。
*   `RFoot` の位置を、椅子の方へ少し近づけて（例: **X = -0.1 〜 -0.15**）みてください。
    *   （手順1-1で椅子の下にスペースを作ったので、足がぶつからずに引けるはずです）
*   足が後ろにあることで、重心が足の上（支持基底面内）に入りやすくなり、つま先が浮くのを防げます。

### 5-5. 足を大きくして安定させる（Large Foot Strategy）
動作が惜しいところまでできている場合、単純に **「足のサイズ（前後径）」** を大きくすることで成功率が上がります。
手順1-4で設定した `RFoot` の Xサイズを、さらに **0.30** 程度まで大きくしてみてください。
支持基底面が前後に広がるため、立ち上がりの勢いで前に倒れそうになっても耐えられるようになります。
