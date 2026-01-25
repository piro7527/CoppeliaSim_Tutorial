# CoppeliaSim Tutorial 8
## 懸垂二足モデルの拡張と実験

Tutorial 7 で作成した「懸垂二足モデル」をベースに、モデルのパラメータ変更や制御の追加を行い、物理挙動の変化を観察します。

---

## 🎯 目的
## 🎯 目的
- モデルの物理パラメータ（質量）を人体データに基づいて調整する
- 外力を加える位置（骨盤の中心 vs 右端）による挙動の違いを実験する
- 物理エンジン設定（Damping）で摩擦・減衰を追加する方法を学ぶ

---

## 🛠 使用環境
- **重要**: Tutorial 7 で作成した `SimpleBiped_Force.ttt` を**コピー**し、`SimpleBiped_Exp.ttt` などの別名で保存してから使用してください。
  - Tutorial 7 の完成ファイルはそのまま残しておきます。

---

## 1. 課題解決：関節が回転しすぎる問題

外力を加えた際、関節がありえない方向に曲がったり、360度回転してしまったりすることがあります。これを防ぐ設定を行います。

### 1.1 回転範囲の制限（Joint Limits）
膝（Knee）に関しては Tutorial 7 で設定済みですが、股関節（Hip）や足首（Ankle）も同様に人間のように一定範囲で止まるように設定しましょう。

#### 手順:
1. 制限したいジョイント（例: `RHip`）をダブルクリック
2. **Joint dynamic parameters** (または **Dynamic properties**) を開く
3. **Position is cyclic** のチェックを確認
   - **チェックが入っている場合**: 外してください（これがONだと無限回転します）。
   - **はじめから外れている場合**: そのままでOKです。
4. **Pos. min. [deg]** と **Pos. range [deg]** に数値を入力する
   - 空欄の場合は、クリックして数値を入力してください。
   > ⚠️ **入力できない場合**: シミュレーションが**停止**しているか確認してください。
   >
   > ⚠️ **Spherical Joint (球関節) の場合**: `PelvisJoint` などの球関節は、この画面で角度制限を設定できません（入力欄がグレーアウトまたは無効になります）。今のところは制限なしで進めるか、パラメータ設定をスキップしてください。

#### 推奨設定例:
| 関節             | Min [deg] | Range [deg] | 備考                     |
| :--------------- | :-------- | :---------- | :----------------------- |
| **Knee** (膝)    | -120      | 120         | Tutorial 7で設定済み     |
| **Hip** (股)     | -30       | 120         | 後ろ30度〜前90度         |
| **Ankle** (足首) | -20       | 45          | **Position 0.00** (推奨) |

### 1.2 体幹へのめり込みを防ぐ（衝突判定）
Trunk（体幹）とPelvis（骨盤）などが衝突せず、身体が柱をすり抜けてしまう場合は、**Respondable** 設定を確認します。

#### 手順:
1. `Trunk` をダブルクリックして **Show dynamic properties dialog** を開く
2. **Body is respondable** にチェックを入れる
3. `Pelvis` も同様に **Body is respondable** にチェックを入れる

> ⚠️ **注意**: 
> `Trunk` と `Pelvis` が初期位置で重なっている（めり込んでいる）状態で両方を Respondable にすると、シミュレーション開始直後に反発力で**吹き飛ぶ（爆発する）**ことがあります。
> これを避けるには、以下のいずれかを行います：
> - `Pelvis` の位置を少し下げて、`Trunk` と完全に接触しないようにする
> - もし多少重なっていても安定させたい場合は、物理エンジンを Bullet から Newton や ODE に変えてみる（相性があります）

---

## 2. パラメータ変更実験

### 2.1 質量をリアルな値に変更（体重60kg想定）
人間の身体部分の質量比（Winterのデータなど）を参考に、体重60kgの人間を想定した質量を設定します。

#### 設定値:
| 部位          | 役割                       | 質量設定    | 備考               |
| :------------ | :------------------------- | :---------- | :----------------- |
| **Pelvis**    | 上半身（頭・腕・体幹）相当 | **41.0 kg** | 全身の約68%        |
| **R/L Thigh** | 大腿                       | **6.0 kg**  | 片脚、全身の約10%  |
| **R/L Shank** | 下腿                       | **2.5 kg**  | 片脚、全身の約4%   |
| **R/L Foot**  | 足部                       | **1.0 kg**  | 片脚、全身の約1.6% |
> **合計**: 41 + (6+2.5+1)*2 = 60 kg



---



## 3. 外力パラメータの変更実験

ここでは、Tutorial 7 で設定した「骨盤への外力」の条件を変更し、身体がどのように反応するかを実験します。

### 3.1 外力を加える位置の変更（右側へ）
現在は「骨盤の中心」に力を加えていますが、これを「骨盤の右側」に変更してみます。
中心からオフセットした位置に力を加えることで、回転（ヨー軸周りなどの）モーメントが発生し、違った挙動になるはずです。

#### 修正するスクリプト:
以下のコードをコピーして、スクリプト全体を上書きしてください。
> **注意**: コードブロックの最初にある ` ```lua ` と、最後の ` ``` ` はコピーしないでください。中身のコードのみを貼り付けます。

```lua
function sysCall_init()
    pelvisHandle = sim.getObject('/Pelvis')
    
    -- Enable zero gravity mode (prevent feet from dangling)
    sim.setArrayParameter(sim.arrayparam_gravity, {0, 0, 0})
    
    print("Zero Gravity Mode: ON (Gravity set to 0,0,0)")
    
    forceDelay = 2.0        -- Apply force after 2.0 seconds
    forceDuration = 0.3     -- Duration of force application
    forceMagnitude = 1.0    -- 1.0 Newton (Adjusted)
    forceStarted = false
    forceEnded = false
    
    print("=== Pelvis Force Demo Ready ===")
    print("Force will be applied at t=" .. forceDelay .. " seconds")
end

function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    if t >= forceDelay and t < forceDelay + forceDuration then
        if not forceStarted then
             forceStarted = true
             print("Force started!")
        end
        
        -- Define force vector
        local force = {0, forceMagnitude, 0}
        
        -- Change position from center {0, 0, 0} to right edge {0.1, 0, 0}
        -- Pelvis width is 0.20m, so 0.1m is the right edge
        local position = {0.1, 0, 0} 
        
        sim.addForce(pelvisHandle, position, force)
        
    elseif t >= forceDelay + forceDuration and not forceEnded then
        forceEnded = true
        print("Force ended!")
    end
end
```

#### 実験と観察:
- **予想**: 重心から離れた位置を押すため、骨盤が回転しようとする動きが含まれるはずです。
- **観察**: 脚の揺れ方に左右差が出るか、ねじれが発生するかを確認してください。

### 3.2 参考：揺れを抑える（摩擦・減衰の追加）
「外力を弱める」と揺れ幅は小さくなりますが、摩擦がないといつまでも揺れ続けてしまいます。
球関節（PelvisJoint）の設定を変更するのは難しいため、**Pelvis（骨盤自体）** に空気抵抗のような減衰を設定するのが最も簡単です。

#### 手順:
1. `Pelvis`（直方体）をダブルクリック
2. **Dynamic properties dialog** を開く
3. **Engine properties** (または **Bullet properties**) というボタンがある場合はそれをクリック
4. 使用している物理エンジン（通常は **Bullet**）の項目を探します。
5. 以下の値を変更してください（初期値は 0 になっていることが多いです）：
   - **linearDamping** (または linearDrag): **0.5**
   - **angularDamping** (または angularDrag): **0.5**
   


> 💡 **外力を減らすのとどう違う？**
> - **外力を減らす**: 最初に「ドン」と押される勢いが弱くなるだけです（小さい幅で揺れ続けます）。
> - **減衰(Damping)を増やす**: 揺れがすぐに収束して止まるようになります（ブレーキがかかるイメージ）。

---
