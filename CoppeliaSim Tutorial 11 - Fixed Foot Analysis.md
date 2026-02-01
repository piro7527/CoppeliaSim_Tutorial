# CoppeliaSim Tutorial 11
## 転倒しないトルク解析：足部固定モデル（CKC）

前回の Tutorial 10 では「バランスを取りながら立つ」ことの難しさを体験しました。
今回は、**「絶対に転倒しない環境」** を作り、**関節にかかる負荷（トルク）** を純粋に観察・解析するためのモデルを作成します。

ロボット工学では **ベース固定（Fixed Base）**、理学療法では **CKC（閉鎖運動連鎖）** と呼ばれる状態に近いです。

---

## 🎯 目的
1.  **足部を「親（固定点）」、骨盤を「子（自由端）」** とする逆転モデルを作成する
2.  スクリプトで膝の曲げ伸ばし（スクワット）を行う
3.  **グラフ** を使って、動作中の関節トルクの変化を可視化する

---

## 1. コンセプト：親子関係の逆転

通常の人体モデル（Tutorial 10）と、今回の解析用モデルの違いです。

*   **通常（Floating Base）**: `骨盤` がルート。足は空中にブラブラしており、床反力で立つ。バランス制御が必要。
*   **今回（Fixed Base）**: `足` がルート。足は床に固定され、そこから膝→股関節→骨盤と積み上がる。**絶対に倒れない。**

---

## 2. 解析用モデルの作成

新規シーン（New Scene）から作成します。

### 2.1 足（RFoot）を固定する
まず、全体の土台となる「右足」を作ります。

1.  **Add** > **Primitive shape** > **Cuboid**
2.  サイズ: **X=0.20, Y=0.08, Z=0.05**
3.  位置: **X=0, Y=-0.08, Z=0.025**
4.  名前: `RFoot`
5.  **Dynamic**: **OFF** (Static) ← **重要！**
    *   これで足が空間に「釘付け」になります。動きません。
6.  **Respondable**: **ON**

### 2.2 右足首（RAnkleJoint）
足の上に足首関節を載せます。

1.  **Add** > **Joint** > **Revolute**
2.  名前: `RAnkleJoint`
3.  位置: **X=0, Y=-0.08, Z=0.075**
4.  **Orientation**: **Alpha=-90, Beta=0, Gamma=0**
5.  **Mode**: **Dynamic mode** (Control loop enabled)
    *   **Control Mode**: **Position**
    *   **Position is cyclic**: **OFF** (推奨)
    *   **Pos. min / range**: **-180** / **360**
    *   **Max Torque**: **500**
    *   **Max. velocity**: **360** (デフォルトのまま)
6.  **親**: `RFoot`

### 2.3 右下腿（RShank）
足首の上に下腿を載せます。

1.  **Add** > **Primitive shape** > **Cylinder**
2.  サイズ: **半径 0.035, 長さ 0.40**
3.  質量: **3.0 kg** (体重60kgを想定)
4.  名前: `RShank`
5.  位置: **X=0, Y=-0.08, Z=0.275**
6.  **Orientation**: **Alpha=0, Beta=0, Gamma=0**
7.  **Dynamic**: **ON**
8.  **親**: `RAnkleJoint`

### 2.4 右膝関節（RKneeJoint）
下腿の上に膝を載せます。

1.  **Add** > **Joint** > **Revolute**
2.  名前: `RKneeJoint`
3.  位置: **X=0, Y=-0.08, Z=0.475**
4.  **Orientation**: **Alpha=-90, Beta=0, Gamma=0**
5.  **Mode**: **Dynamic mode**
    *   **Control Mode**: **Position**
    *   **Position is cyclic**: **OFF**
    *   **Pos. min / range**: **-180** / **360**
    *   **Max Torque**: **500**
    *   **Max. velocity**: **360** (デフォルトのまま)
6.  **親**: `RShank`

### 2.5 右大腿（RThigh）
膝の上に大腿を載せます。

1.  **Add** > **Primitive shape** > **Cylinder**
2.  サイズ: **半径 0.04, 長さ 0.35**
3.  質量: **6.0 kg**
4.  名前: `RThigh`
5.  位置: **X=0, Y=-0.08, Z=0.65**
6.  **Orientation**: **Alpha=0, Beta=0, Gamma=0**
7.  **Dynamic**: **ON**
8.  **親**: `RKneeJoint`

### 2.6 右股関節（RHipJoint）
大腿の上に股関節を載せます。

1.  **Add** > **Joint** > **Revolute**
2.  名前: `RHipJoint`
3.  位置: **X=0, Y=-0.08, Z=0.825**
4.  **Orientation**: **Alpha=-90, Beta=0, Gamma=0**
5.  **Mode**: **Dynamic mode**
    *   **Control Mode**: **Position**
    *   **Position is cyclic**: **OFF**
    *   **Pos. min / range**: **-180** / **360**
    *   **Max Torque**: **500**
    *   **Max. velocity**: **360** (デフォルトのまま)
6.  **親**: `RThigh`

### 2.7 骨盤（Pelvis）
最後に、股関節の上に骨盤を載せます。これが「重り」になります。

1.  **Add** > **Primitive shape** > **Cuboid**
2.  サイズ: **X=0.15, Y=0.25, Z=0.15**
3.  質量: **20.0 kg**
    *   **解説**: 体重約60kgの人が「両足スクワット」をする想定です。
    *   本来の上半身質量（約40kg）を左右の脚で分担するため、片側 **20kg** と設定しています。
4.  名前: `Pelvis`
5.  位置: **X=0, Y=0, Z=0.90**
6.  **Dynamic**: **ON**
7.  **親**: `RHipJoint`

---

## 3. 左脚の実装（ダミー）
今回はトルク解析なので、右脚（一本足）だけで十分です。
もし左脚も付けたい場合、左足(`LFoot`)も **Static** にして床に固定し、そこから積み上げて、最後に `LHipJoint` を `Pelvis` に接続する...というのは**ループ構造（閉リンク）**になり、設定が少し難しくなります。

まずはシンプルに **「一本足スクワット」** で解析しましょう。体重（Pelvis質量）を大きくすれば負荷は再現できます。

---

## 4. スクリプトで動かす
一番下の `RFoot` にスクリプトを付けます。

1.  `RFoot` を選択 > Add > Script > Child script
2.  以下のコードを入力（**グラフ機能も含まれています**）

```lua
sim = require('sim')

function sysCall_init()
    -- ":/" でシーン内の名前（エイリアス）を検索します
    rAnkle = sim.getObject(":/RAnkleJoint")
    rKnee  = sim.getObject(":/RKneeJoint")
    rHip   = sim.getObject(":/RHipJoint")
    
    -- グラフの自動セットアップ
    -- もし "TorqueGraph" という名前のグラフがあれば、そこにデータを送ります
    graphHandle = sim.getObject(":/TorqueGraph")
    
    -- ストリーム（データを入れる箱）を作成: 
    -- 引数: グラフハンドル, ストリーム名, 単位, オプション, 色{R,G,B}
    torqueStream = sim.addGraphStream(graphHandle, "Knee Torque", "N*m", 0, {1, 0, 0})
    
    timer = 0
end

function sysCall_actuation()
    dt = sim.getSimulationTimeStep()
    timer = timer + dt
    
    -- 初期姿勢：座った状態（深く曲げた状態）
    -- 立ち上がり：0度（直立）に向かって伸ばしていく
    
    local targetAnkle = 0
    local targetKnee = 0
    local targetHip = 0

    if timer < 1.0 then
        -- 1.0秒までは座った姿勢をキープ（開始直後の安定化）
        -- Fixed Footモデルでの「座る」角度:
        -- 足首：+25 (前傾), 膝：-90 (後方へ屈曲), 股：+90 (上体起こし)
        targetAnkle = 25 * math.pi / 180   
        targetKnee  = -90 * math.pi / 180
        targetHip   = 90 * math.pi / 180
        
    elseif timer < 4.0 then
        -- 1.0秒〜4.0秒：3秒かけてゆっくり立ち上がる（0度へ）
        -- 線形補間（Lerp）で滑らかに変化させます
        local ratio = (timer - 1.0) / 3.0
        
        targetAnkle = (1.0 - ratio) * (25 * math.pi / 180)
        targetKnee  = (1.0 - ratio) * (-90 * math.pi / 180)
        targetHip   = (1.0 - ratio) * (90 * math.pi / 180)
        
    else
        -- 4.0秒以降：直立キープ
        targetAnkle = 0
        targetKnee  = 0
        targetHip   = 0
    end
    
    sim.setJointTargetPosition(rAnkle, targetAnkle)
    sim.setJointTargetPosition(rKnee, targetKnee)
    sim.setJointTargetPosition(rHip, targetHip)
end

function sysCall_sensing()
    -- センシングフェーズでトルクを計測してグラフに追加
    local torque = sim.getJointForce(rKnee)
    sim.setGraphStreamValue(graphHandle, torqueStream, torque)
end
```

---

## 5. グラフの準備
手動設定は大変なので、**空のグラフ** を作るだけでOKです。

1.  **Add** > **Graph**
2.  名前を `TorqueGraph` に変更してください。
3.  **これだけです！**（中身の設定はスクリプトが自動でやります）

### 実行
再生ボタンを押すと、立ち上がり動作とともにグラフウィンドウに「膝のトルク」が赤線で描画されます。
（深く曲げている最初の1秒間が最もトルクが高く、立ち上がると下がっていく様子が見えるはずです）

### 実行
再生ボタンを押すと、一本足のアバターが座った状態からゆっくり立ち上がり、直立します。
グラフウィンドウに波形が表示され、**「深くしゃがんでいる時（開始直後）にトルクが最大になり、立ち上がると下がっていく」** 様子が確認できるはずです。

これで「転倒」を気にせず、存分に力学的な実験ができます！
