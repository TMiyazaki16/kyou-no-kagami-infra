# リポジトリガイドライン

## プロジェクト概要

「きょうのかがみ」の Google Cloud インフラ（IaC）。アプリコードは置かない（アプリは `TMiyazaki16/kyou-no-kagami`）。
構成・命名・書き方は `TMiyazaki16/sample-ec-infra` に揃えている。

- フロントエンド: Cloud Storage（Vite のビルド成果物）
- バックエンド API: Cloud Run（FastAPI、:8000）
- DB: Cloud SQL for MySQL（Unix ソケット接続。パスワードは Terraform が生成して Secret Manager へ）
- アップロード: Cloud Storage（非公開。バックエンドが読み書き・配信）
- 公開経路: 外部アプリケーションロードバランサ（`/api/*`・`/uploads/*` は Cloud Run、それ以外は Storage）
- DNS: **このリポジトリでは管理しない**。ゾーンは別プロジェクト `ec-site-handson` にあり、A レコードは手動で追加する

構成の概要と運用手順は `README.md` を正とする。

## ディレクトリ構成

- `envs/<env>/` — 環境ごとのルートモジュール。モジュールの組み立てと環境固有値だけを置く
- `envs/prod-bootstrap/` — 一度だけ apply し **destroy しない** state。tfstate バケット（envs/prod の state 置き場）と Workload Identity Pool（削除後 30 日は同じ ID で再作成できない）。ここへ destroy を提案しない
- `modules/<機能>/` — 再利用するモジュール。`main.tf` / `variables.tf` / `outputs.tf` / `versions.tf` の 4 点を揃える

モジュール側にドメイン名・プロジェクト ID・バケット名を直書きしない。必ず変数で受け、既定値は `envs/<env>/variables.tf` に置く。

## 開発コマンド

ホストに terraform が無い場合は `.terraform-version` と同じ版を入れる。

```sh
terraform fmt -recursive -check   # リポジトリ直下で。整形差分なし
cd envs/prod
terraform init -backend=false     # 認証情報なしで検証だけするとき
terraform validate
```

- `plan` / `apply` には ADC と backend 設定（`terraform init -backend-config=backend.hcl`）が要る
- Terraform の版数は 2 か所にある。**実行する版**の正は `.terraform-version`、**許容する版**は各 `versions.tf` の `required_version`。上げるときは両方を揃える

## 運用の前提

- **apply / destroy はオーナーが Cloud Shell で行う**。エージェントは apply / destroy / state 操作を実行しない
- 利用者データを持つ Cloud SQL とアップロード用バケットは `protect_data`（既定 true）で削除から守っている。EC の「平時は destroy」運用とは違い、prod を気軽に destroy しない。消すときは `protect_data = false` を apply してから destroy（README の後片付け）
- フロント用バケットと Cloud Run は作り直しても失うものが無いので、EC と同じく `force_destroy = true` / `deletion_protection = false`
- MySQL のパスワードは `random_password` → `google_sql_user` と Secret Manager。値をコード・tfvars・output・ログに出さない。state には平文で入るため、tfstate バケットの権限を広げない
- Cloud Run のコンテナイメージは CI がデプロイする。`lifecycle { ignore_changes = [...] }` を外さない（イメージと `client` / `client_version`）。環境変数・シークレット・Cloud SQL 接続は Terraform 管理
- `GEMINI_API_KEY` は既定で渡さない（公開デモはモック）。使うときはシークレットを手動作成し `gemini_api_key_secret_id` を指定する。Terraform でキーの値を扱わない
- GitHub Actions の SA は `envs/prod-bootstrap` が作り、権限付与は `envs/prod/ci_iam.tf`。権限は原則リソース単位（例外: Cloud Run 実行 SA の `cloudsql.client` と、infra CI の読み取りロールはプロジェクトレベル）
- LB の SPA フォールバック（404 → index.html）はバケット向けの path_rule だけに付ける。path_matcher の既定に付けると `/api/*`・`/uploads/*` の 404 まで 200 に化ける
- マネージド SSL 証明書は DNS が LB の IP を指すまで `ACTIVE` にならない。apply 直後の証明書エラーは異常とは限らない

## AI開発ルール

### 人間確認が必要なとき

次に該当したら、実装に入らず前提・選択肢・影響を提示して確認を待つ。

- `terraform apply` / `terraform destroy` / state の手動改変（`state rm`、`import` を含む）
- 既存リソースの置換（静的 IP、Cloud SQL、バケット）を伴う変更
- 新規モジュールの追加、新しい GCP サービスの導入、環境の追加
- 公開範囲が広がる変更（`allUsers` への権限付与、ingress の緩和、Cloud SQL の承認済みネットワーク追加）
- 依頼スコープを超える変更（無関係なモジュールのリファクタ、アプリリポジトリの変更）
- 3 ファイル以上または複数モジュールにまたがる変更 → 先に計画（変更対象 / README の更新要否 / 検証方針 / リスク）を提示する

### そのまま進めてよいとき

既存モジュールのパターンに沿った変数・`validation`・コメント・ドキュメントの追加。置いた仮定は作業報告に明記する。パスやリソース名は実在を確認してから参照する。

### 明示依頼なしでは実行しない

- `git commit` / `git push` / force push / `git reset --hard`
- `terraform.tfvars`、`backend.hcl`、`.env`、認証情報の作成・変更・コミット
- シークレット値の出力・ログ出力・ファイルへの書き出し

### 変更時チェックリスト

1. `terraform fmt -recursive -check` が差分なし
2. 両 env で `terraform validate` が成功
3. 可能なら `terraform plan` を実行し、置換（`-/+`）や削除が意図どおりか確認する（plan はオーナー環境でのみ可能）
4. リソース名・変数名・outputs を変えたら `README.md` を更新する
5. 新しい outputs は用途を `description` に書く

### 報告

実行したコマンドと結果、置いた仮定、確認が必要な事項を明記する。plan を実行できなかった場合はその理由も書く。未実施の手順を実施済みと書かない。
