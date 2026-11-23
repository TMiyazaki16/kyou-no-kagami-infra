---
name: verify-infra
description: Terraform リポジトリの検品。terraform fmt -recursive -check、両 env の init -backend=false ＋ validate、オーナーが実行した plan 出力の確認（置換・削除・公開範囲・保護対象）を行い、PR に貼れる形で報告する。PR を出す前、レビューで確かめるとき、「検品して」「validate して」と言われたときに使う。apply はしない。
---

# verify-infra — fmt ＋ validate ＋ plan の確認

コマンド・対象 env などの値は、リポジトリ直下の `AGENTS.md` の「開発フロー」節にある **「スキルが参照する値」表** から読む（`<terraform>`・`<対象 env>`・`<不変条件>`）。表の値とこの文書が食い違ったら `AGENTS.md` を正とする。

## 守ること

- **`terraform apply` / `destroy` / `import` / `state` 操作をしない。** Claude が実行してよいのは `fmt -check`・`init -backend=false`・`validate` だけ
- **`plan` は Claude からは実行しない**（ADC と backend 設定が要り、オーナー環境でだけ実行する）。plan はオーナー（または infra CI）が実行し、その出力を Claude が読む
- `terraform.tfvars`・`backend.hcl`・`.env`・認証情報を作らない・変えない・読み上げない
- `terraform fmt` を `-check` なしで実行して勝手に整形しない（整形が必要なら、差分のあるファイルを報告してから直す）
- 未実施の手順を実施済みと書かない

## 1. 版を確かめる

```sh
cat .terraform-version          # 実行する版の正
<terraform> version             # 一致すること
```

違う版しか無いときは、その旨を報告に書く（`required_version` の範囲内なら検証は続けてよい）。

## 2. 整形

```sh
<terraform> fmt -recursive -check    # リポジトリ直下で。出力なし・終了コード 0 なら合格
```

差分のあるファイル名が出たら不合格。`<terraform> fmt -recursive -diff -check` で差分を見て報告する。

## 3. 構文・参照の検証（両 env）

`<対象 env>` のすべてで行う（このリポジトリは `envs/prod` と `envs/prod-bootstrap`）。

```sh
for e in <対象 env>; do
  (cd "envs/$e" \
    && <terraform> init -backend=false -input=false -lockfile=readonly > /dev/null \
    && <terraform> validate) || echo "NG: $e"
done
```

- `-backend=false` なので認証情報なしで動き、state には触れない。`.terraform/` は `.gitignore` 済み
- `-lockfile=readonly` で `.terraform.lock.hcl` を書き換えない。プロバイダの版を変える変更でここが失敗するのは想定どおりなので、その場合は `-lockfile=readonly` を外して実行し、lock の差分を PR に含めて報告する
- 両 env で `Success! The configuration is valid.` なら合格

## 4. plan の確認（オーナーが実行した出力を読む）

`*.tf` を変える PR では、オーナー（Cloud Shell）に次を依頼する。plan ファイル（`*.tfplan`）は属性値を平文で持つので保存・共有を求めない。

```sh
# envs/<env> で（オーナーが実行）
terraform init -backend-config=backend.hcl
terraform plan -lock=false
```

受け取った出力で次を確かめ、報告に書く。

| 観点 | 確かめること |
|---|---|
| 件数 | `Plan: X to add, Y to change, Z to destroy` が Issue の意図と合っているか |
| 置換 | `-/+`（must be replaced）が無いか。特に **静的 IP・Cloud SQL・バケット** の置換は人間確認が必要 |
| 削除 | `destroy` が意図どおりか。`envs/prod-bootstrap`（tfstate バケット・Workload Identity Pool）の削除は提案しない |
| データ保護 | `protect_data`・`deletion_protection` が意図せず外れていないか |
| 公開範囲 | `allUsers` / `allAuthenticatedUsers` への権限、ingress の緩和、Cloud SQL の承認済みネットワーク追加がないか |
| IAM | 権限が原則リソース単位か（プロジェクトレベルの付与が増えていないか） |
| Cloud Run | イメージ・`client`・`client_version` の差分が出ていないか（`ignore_changes` が外れていないか） |
| 秘密 | 出力・output に秘密の値が出ていないか（`(sensitive value)` になっているか） |

plan を受け取れなかったときは「plan 未確認（理由）」と報告し、PR 本文にもそう書く。

## 5. 差分と運用ルールの照合

`<不変条件>`（`AGENTS.md` の「運用の前提」と「人間確認が必要なとき」）を、差分に関係するものから 1 つずつ確かめる。

- モジュールにドメイン名・プロジェクト ID・バケット名を直書きしていないか（変数で受け、既定値は `envs/<env>/variables.tf`）
- 新しいモジュールは `main.tf` / `variables.tf` / `outputs.tf` / `versions.tf` の 4 点が揃っているか
- 新しい outputs に `description` があるか。リソース名・変数名・outputs を変えたら `README.md` を更新したか
- Terraform の版を上げたなら `.terraform-version` と各 `versions.tf` の `required_version` を揃えたか
- `.github/workflows/` に差分がないか

## 報告フォーマット（PR の「テスト・ビルド結果」にそのまま貼れる形）

```markdown
### 検品結果（verify-infra）
- Terraform：v<版>（`.terraform-version` と一致 / 不一致）
- `terraform fmt -recursive -check` → 差分なし
- `envs/prod`：`init -backend=false` → `validate` 成功
- `envs/prod-bootstrap`：`init -backend=false` → `validate` 成功
- plan：<オーナー実行の結果の要約（X add / Y change / Z destroy、置換の有無）> または「未確認（理由）」
- 運用ルール：<関係した項目と確認結果>
- apply：未実施（オーナーの OK 後にオーナーが実行）
```
