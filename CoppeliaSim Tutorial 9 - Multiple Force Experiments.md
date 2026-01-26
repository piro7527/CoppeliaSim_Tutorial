# CoppeliaSim Tutorial 9
## 遊脚期の介助力パターンを再現する

このチュートリアルでは、理学療法士が歩行介助時に骨盤へ加える力のパターンを、宙吊り二足モデルに適用します。論文の研究データに基づき、正弦波半波モデルで力を生成します。

---

## 🎯 目的
- 研究論文に基づいた介助力パターンをシミュレーションで再現する
- 正弦波半波（Half-wave sinusoid）による力の生成を学ぶ
- 複数の外力を異なるタイミングで順次適用する

---

## 📚 背景：論文からのパラメータ

理学療法士が遊脚期（Swing Phase）に骨盤へ加える介助力を分析した結果、以下の2つの力が重要であることが分かりました：

| 力                | 振幅     | ピーク時刻 | 適用区間    | 目的                     |
| ----------------- | -------- | ---------- | ----------- | ------------------------ |
| **LH Up** (上方)  | 30.875 N | 0.17 s     | 0.07–0.27 s | つま先のクリアランス確保 |
| **LH Fwd** (前方) | 9.75 N   | 0.42 s     | 0.32–0.52 s | 骨盤の前方回旋促進       |

### 波形モデル
力は半波長の正弦波として表現されます：

```
F(t) = A × sin(ω × (t - tstart))    （tstart ≤ t ≤ tend のとき）
F(t) = 0                             （それ以外）
```

- **ω（角周波数）** = π / ΔT = π / 0.20 = **15.708 rad/s**
- **ΔT（半波の持続時間）** = **0.20 s**

---

## 🛠 使用環境
- **重要**: Tutorial 8 で作成した `SimpleBiped_Exp.ttt` を**コピー**し、`SimpleBiped_SwingAssist.ttt` などの別名で保存してから使用してください。
  - Tutorial 8 の完成ファイルはそのまま残しておきます。
  - **手順**: Finder で `SimpleBiped_Exp.ttt` を複製（⌘+D）→ 名前を変更 → CoppeliaSim で開く

---

## 1. スクリプトの作成

### 1.1 既存スクリプトの確認
1. 複製して作成した `SimpleBiped_SwingAssist.ttt` を開く
2. Scene hierarchy で `Pelvis` を見つける
3. `Pelvis` に付いているスクリプトをダブルクリックして開く

### 1.2 スクリプトを書き換え
以下のコードに **完全に置き換え** てください：

```lua
function sysCall_init()
    pelvisHandle = sim.getObject('/Pelvis')
    
    -- Enable zero gravity mode
    sim.setArrayParameter(sim.arrayparam_gravity, {0, 0, 0})
    print("Zero Gravity Mode: ON")
    
    -------------------------------------------------
    -- ASSISTIVE FORCE PARAMETERS (from research paper)
    -------------------------------------------------
    -- Duration of each half-wave sinusoid
    deltaT = 0.20  -- seconds
    
    -- Angular frequency
    omega = math.pi / deltaT  -- 15.708 rad/s
    
    -- LH Up (Upward force on left pelvis)
    lhUp = {
        amplitude = 30.875,   -- Newton
        tpeak = 0.17,         -- Peak timing (s)
        tstart = 0.07,        -- Start timing (s)
        tend = 0.27           -- End timing (s)
    }
    
    -- LH Fwd (Forward force on left pelvis)
    lhFwd = {
        amplitude = 9.75,     -- Newton
        tpeak = 0.42,         -- Peak timing (s)
        tstart = 0.32,        -- Start timing (s)
        tend = 0.52           -- End timing (s)
    }
    
    -- Delay before starting the pattern (for observation)
    patternDelay = 2.0
    
    print("=== Swing Phase Assistive Force Pattern ===")
    print(string.format("LH Up:  %.2f N, peak at %.2f s (%.2f - %.2f s)", 
          lhUp.amplitude, lhUp.tpeak, lhUp.tstart, lhUp.tend))
    print(string.format("LH Fwd: %.2f N, peak at %.2f s (%.2f - %.2f s)", 
          lhFwd.amplitude, lhFwd.tpeak, lhFwd.tstart, lhFwd.tend))
    print(string.format("Pattern starts after %.1f seconds", patternDelay))
end

-- Calculate half-wave sinusoidal force
function calcSineForce(t, tstart, tend, amplitude, omega)
    if t >= tstart and t <= tend then
        return amplitude * math.sin(omega * (t - tstart))
    else
        return 0
    end
end

function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    -- Wait for delay period
    if t < patternDelay then
        return
    end
    
    -- Relative time within the pattern
    local tRel = t - patternDelay
    
    -- Calculate forces
    local forceUp = calcSineForce(tRel, lhUp.tstart, lhUp.tend, lhUp.amplitude, omega)
    local forceFwd = calcSineForce(tRel, lhFwd.tstart, lhFwd.tend, lhFwd.amplitude, omega)
    
    -- Apply LH Up (upward force in Z direction)
    if forceUp > 0 then
        -- Position: right side of pelvis (+0.1 in X direction)
        -- Note: In CoppeliaSim, Y is forward, X is right/left
        local posUp = {0.1, 0, 0}
        local forceVecUp = {0, 0, forceUp}  -- Z direction (upward)
        sim.addForce(pelvisHandle, posUp, forceVecUp)
    end
    
    -- Apply LH Fwd (forward force in Y direction)
    if forceFwd > 0 then
        -- Position: right side of pelvis
        local posFwd = {0.1, 0, 0}
        local forceVecFwd = {0, forceFwd, 0}  -- Y direction (forward)
        sim.addForce(pelvisHandle, posFwd, forceVecFwd)
    end
    
    -- Print peak timings (once)
    if tRel >= lhUp.tpeak - 0.01 and tRel <= lhUp.tpeak + 0.01 then
        if not lhUpPeakPrinted then
            print(string.format("[%.2f s] LH Up peak: %.2f N", t, forceUp))
            lhUpPeakPrinted = true
        end
    end
    
    if tRel >= lhFwd.tpeak - 0.01 and tRel <= lhFwd.tpeak + 0.01 then
        if not lhFwdPeakPrinted then
            print(string.format("[%.2f s] LH Fwd peak: %.2f N", t, forceFwd))
            lhFwdPeakPrinted = true
        end
    end
end
```

---

## 2. コードの解説

### 2.1 パラメータ設定（`sysCall_init`）

| 変数                  | 値          | 説明                 |
| --------------------- | ----------- | -------------------- |
| `deltaT`              | 0.20        | 半波の持続時間（秒） |
| `omega`               | 15.708      | 角周波数（rad/s）    |
| `lhUp.amplitude`      | 30.875      | 上方力の振幅（N）    |
| `lhUp.tstart / tend`  | 0.07 / 0.27 | 上方力の適用区間     |
| `lhFwd.amplitude`     | 9.75        | 前方力の振幅（N）    |
| `lhFwd.tstart / tend` | 0.32 / 0.52 | 前方力の適用区間     |

### 2.2 正弦波半波の計算（`calcSineForce`）

```lua
function calcSineForce(t, tstart, tend, amplitude, omega)
    if t >= tstart and t <= tend then
        return amplitude * math.sin(omega * (t - tstart))
    else
        return 0
    end
end
```

この関数は：
1. 適用区間内（`tstart ≤ t ≤ tend`）のみ力を返す
2. `sin(0)` から始まり、`sin(π)` で終わる半波を生成
3. ピークは区間の中央（`t = tstart + deltaT/2`）で発生

### 2.3 力の適用方向

| 力     | 適用位置      | 力のベクトル       | 意味                  |
| ------ | ------------- | ------------------ | --------------------- |
| LH Up  | `{0.1, 0, 0}` | `{0, 0, forceUp}`  | 右側で上向き          |
| LH Fwd | `{0.1, 0, 0}` | `{0, forceFwd, 0}` | 右側で前向き（Y方向） |

> 💡 **右側を選んだ理由**: 骨盤の右側（X = +0.1）に力を加えることで、理学療法士が右手で骨盤を支える動作を再現します。

---

## 3. シミュレーション実行

1. ▶️ **Start simulation**
2. 最初の2秒間は何も起きません（`patternDelay`）
3. **2.07秒〜2.27秒**: 上方向への力が適用される
   - 骨盤が持ち上がり、脚が揺れ始めます
4. **2.32秒〜2.52秒**: 前方向への力が適用される
   - 骨盤が前に押され、回転運動が発生します
5. コンソールで以下のような出力を確認：
   ```
   [2.17 s] LH Up peak: 30.88 N
   [2.42 s] LH Fwd peak: 9.75 N
   ```

### 3.1 観察ポイント
- 上方力（LH Up）による骨盤の上昇と脚の揺れ
- 前方力（LH Fwd）による骨盤の前方回旋
- 2つの力のタイミングの違いによる複合的な動き

---

## 4. パラメータ変更実験

### 実験1: 力の振幅を変える

```lua
-- より強い力で試す（2倍）
lhUp.amplitude = 61.75    -- 元の2倍
lhFwd.amplitude = 19.50   -- 元の2倍
```

→ 揺れが大きくなるか観察

### 実験2: タイミングを変える

```lua
-- 2つの力を同時に適用
lhUp.tstart = 0.07
lhUp.tend = 0.27
lhFwd.tstart = 0.07   -- 変更前: 0.32
lhFwd.tend = 0.27     -- 変更前: 0.52
```

→ 同時に上方と前方の力が加わるとどうなるか

### 実験3: 適用位置を変える

```lua
-- 右側に適用（右手を模擬）
local posUp = {0.1, 0, 0}   -- 変更前: {-0.1, 0, 0}
```

→ 回転方向が逆になるか確認

---

## 5. 連続パターンへの拡張（発展課題）

実際の歩行では、遊脚期のパターンが歩行周期ごとに繰り返されます。以下のように修正すると、周期的なパターンを生成できます：

```lua
function sysCall_actuation()
    local t = sim.getSimulationTime()
    
    if t < patternDelay then
        return
    end
    
    -- 1歩行周期 = 1.0秒と仮定
    local gaitCycleDuration = 1.0
    
    -- 現在の歩行周期内での相対時間
    local tRel = (t - patternDelay) % gaitCycleDuration
    
    -- 以下は同じ...
end
```

> ⚠️ **注意**: この連続パターンでは力が繰り返し適用されるため、減衰（Damping）が設定されていないと揺れが蓄積していきます。

---

## 🔧 トラブルシューティング

| 症状                       | 対処法                                        |
| -------------------------- | --------------------------------------------- |
| 何も動かない               | スクリプトにエラーがないかコンソールを確認    |
| 動きが小さすぎる           | `amplitude` を大きくする / 質量（Mass）を確認 |
| 動きが激しすぎる           | `amplitude` を小さくする / Damping を追加     |
| 脚だけ動いて骨盤が動かない | 無重力モードになっているか確認                |

---

## 📝 まとめ

このチュートリアルでは：
1. 研究論文から抽出した介助力パラメータを使用
2. 正弦波半波モデルで滑らかな力の変化を実現
3. 複数の力を異なるタイミングで順次適用

これにより、理学療法士の歩行介助技術をシミュレーションで再現する基礎ができました。

---

## 🚀 次へのステップ

- 力の適用結果（骨盤の位置・角度変化）をグラフ化する
- 左右の脚それぞれに対応した介助パターンを実装
- 地面との接触を含めた歩行シミュレーションへ発展
