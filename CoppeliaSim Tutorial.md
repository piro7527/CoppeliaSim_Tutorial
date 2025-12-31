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
2. **File → New scene**

---

## 2. Sphere（落下する物体）の作成と設定

### 2.1 Sphere を作成
1. **Add → Primitive shape → Sphere**
2. Scene hierarchy に `Sphere` が表示されることを確認

---

### 2.2 Sphere を動的オブジェクトにする
1. Scene hierarchy で **Sphere** を選択
2. **Shape → Dynamic properties dialog** を開く
3. **Rigid Body Dynamic Properties** で設定：

| 項目 | 設定 |
|---|---|
| Body is dynamic | ✅ ON |
| Body is respondable | ✅ ON |
| Mass | 1.0（任意） |

4. **Apply / Apply to selection**

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
