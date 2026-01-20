# CoppeliaSim Tutorial  
## Sphere を落下させて Cuboid 床で跳ねさせる（Bullet）

このリポジトリは **CoppeliaSim 初心者向けの物理シミュレーション入門**です。  
Sphere を落下させ、**Cuboid 床との衝突・反発（restitution）**を確認します。

---

## 🎯 目的
- 動的オブジェクト（Sphere）と静的オブジェクト（床Cuboid）の違いを理解する  
- Bullet 物理エンジンにおける **restitution（反発係数）** の挙動を確認する  
- 初期めり込み（オーバーラップ）による典型的トラブルを防ぐ  

---

## 🛠 使用環境
- CoppeliaSim（Bullet 物理エンジン）
- OS：不問（Windows / macOS / Linux）

---

## 1. 新しいシーンを作成
1. CoppeliaSim を起動
   > 起動時に新しいシーンが自動的に作成されます。もし作成されていない場合は **File → New scene** を選択してください。

---

## 2. Sphere（落下する物体）の作成と設定

Sphere を作成し、物理演算の対象となるように設定します。

1. **Add → Primitive shape → Sphere** を選択
   > 作成時に設定画面が表示されない場合は、作成後に Sphere をダブルクリック、または **Tools > Scene object properties** を開いて設定してください。
   > - **Size**: **Scene object properties** 内の **Texture / geometry properties** 欄にある **Geometry** ボタンをクリックし、表示されるダイアログで設定
   > - **Dynamics**: **Scene object properties** 内の **Show dynamic properties dialog** (または **Dynamics** タブ) から設定

   | カテゴリ     | 項目                | 設定値   |
   | ------------ | ------------------- | -------- |
   | **Geometry** | Size (X, Y, Z)      | **0.1**  |
   | **Dynamics** | Body is dynamic     | ✅ **ON** |
   | **Dynamics** | Body is respondable | ✅ **ON** |
   | **Dynamics** | Mass                | **1.0**  |

---

### 2.3 Sphere の Bullet 設定（反発）
1. **Engine properties** をクリック
2. `bullet` の項目を設定：

```json
"bullet": {
  "restitution": 0.8,
  "friction": 0.5,
  "linearDamping": 0,
  "angularDamping": 0
}
```

#### パラメータの説明

| パラメータ         | 値  | 説明                                                                                   |
| ------------------ | --- | -------------------------------------------------------------------------------------- |
| **restitution**    | 0.8 | **反発係数**。衝突後にどれだけ跳ね返るかを表す。`0.0`=跳ね返らない、`1.0`=完全弾性衝突 |
| **friction**       | 0.5 | **摩擦係数**。物体表面の滑りにくさ。`0.0`=滑る、`1.0`=高摩擦                           |
| **linearDamping**  | 0   | **線形減衰**。移動速度に対する空気抵抗のような減衰。`0`=減衰なし                       |
| **angularDamping** | 0   | **角速度減衰**。回転速度に対する減衰。`0`=減衰なし                                     |

> 💡 **実験のヒント**: `restitution` を `0.2` に下げるとあまり跳ねなくなり、`linearDamping` を `0.5` にすると空気抵抗があるような動きになります。

---

### 2.4 Sphere の位置設定
Sphere を床から離れた位置に移動させます。

1. Scene hierarchy で **Sphere** を選択
2. **Scene object properties** → **Position** タブを開く
3. **Z** を `1.0` [m] に設定

---

## 3. Cuboid（床）の作成と設定

Sphere が衝突するための床を作成します。

### 3.1 Cuboid を作成
1. **Add → Primitive shape → Cuboid**
2. 設定ダイアログで以下を入力し **Create**（または作成後に Geometry 設定）：
   - **Size (X, Y, Z)**: `2.0`, `2.0`, `0.1`

### 3.2 Cuboid を静的オブジェクト（床）にする
床は落下してほしくないため、**Dynamic（動く）** 設定は OFF にし、**Respondable（衝突判定あり）** だけ ON にします。

1. **Scene object properties** → **Dynamic properties** を開く
2. 以下の通り設定：

| 項目                | 設定      | 備考                 |
| ------------------- | --------- | -------------------- |
| Body is dynamic     | ⬜️ **OFF** | 床なので動かない     |
| Body is respondable | ✅ **ON**  | 衝突判定は有効にする |

### 3.3 Cuboid の Bullet 設定（反発係数）
床も弾むように Bullet エンジンの設定を行います。

1. **Engine properties** → `bullet` の項目を設定：
   ```json
   "bullet": {
     "restitution": 0.8,
     "friction": 0.5
   }
   ```
   > **restitution（反発係数）** が Sphere と床の両方で設定されていることで、弾む挙動が確認できます。

---

## 4. シミュレーションの実行

設定が完了したら実際に動かしてみましょう。
**注意**: このチュートリアルは **Bullet** エンジンを使用します。

1. 画面上部のメニューから **Simulation → Bullet 2.83**（または 2.78）を選択
   > デフォルト以外のエンジン（Newton, ODEなど）になっていると、上記で設定した `bullet` の反発係数が反映されず、跳ねません。
2. **Toggle real-time mode**（ウサギと亀のアイコン、または時計のアイコン）を ON にします
   > Real-time mode にしないと計算が速すぎて、跳ねる様子が見えない（または計算が不安定になる）場合があります。
3. **Start simulation**（再生ボタン ▶️）をクリック
4. Sphere が自由落下し、Cuboid の床で弾むことを確認してください。
5. 確認後、**Stop simulation**（停止ボタン ⏹️）をクリック

### ⚠️ うまく跳ねない場合
- **跳ねずに止まる**: 物理エンジンが `Bullet` 以外になっていませんか？（手順1を確認）
- **動作が速すぎて見えない**: **Real-time mode** が ON になっていますか？（手順2を確認）
- **床をすり抜ける**: Cuboid の `Body is respondable` が ON になっていますか？
- **落下しない**: Sphere の `Body is dynamic` が ON になっていますか？
