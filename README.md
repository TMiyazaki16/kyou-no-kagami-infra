# kyou-no-kagami-infra

「きょうのかがみ」本番環境（GCP プロジェクト `kyou-no-kagami`）のインフラを Terraform で管理するリポジトリ。
アプリは [TMiyazaki16/kyou-no-kagami](https://github.com/TMiyazaki16/kyou-no-kagami)。構成と書き方は
`sample-ec-infra`（EC サイト本番）に揃えている。

## ディレクトリ構成

```
envs/
  prod-bootstrap/  一度だけ apply し destroy しないリソース（tfstate バケット・Workload Identity 連携）
  prod/            本番のルートモジュール（モジュールの組み立てと環境固有値）
modules/
  artifactregistry/  CI がビルドしたコンテナイメージの置き場
  cloudsql/          Cloud SQL for MySQL・DB・アプリ用ユーザー・パスワード（生成して Secret Manager へ）
  cloudrun/          バックエンド API の Cloud Run サービスと実行サービスアカウント
  storage/           フロント配信用バケット・アップロード用バケット・LB 用バックエンドバケット
  lb/                外部アプリケーションロードバランサ一式
  github_oidc/       GitHub Actions から GCP を操作するための Workload Identity 連携
```

## 構成の概要

```
             https://kyou-no-kagami.tmiyazaki-works.com
                          │
               [ 外部アプリケーション LB ]（静的 IP・マネージド証明書・HTTP→HTTPS 301）
                ├ /api/*, /uploads/* → Serverless NEG → Cloud Run（FastAPI、:8000）
                │                                         ├ Cloud SQL（MySQL、Unix ソケット /cloudsql/<接続名>）
                │                                         └ GCS アップロード用バケット（非公開）
                └ それ以外           → バックエンドバケット → GCS フロント用バケット（Vite の dist）
```

Cloud Run に渡している環境変数（`modules/cloudrun/main.tf`）:

| 変数 | 値 |
| --- | --- |
| `DB_BACKEND` | `mysql` |
| `MYSQL_HOST` | `/cloudsql/<PROJECT>:<REGION>:<INSTANCE>` |
| `MYSQL_USER` / `MYSQL_DATABASE` | `kagami_app` / `kagami` |
| `MYSQL_PASSWORD` | Secret Manager `kagami-mysql-password`（Terraform が生成） |
| `UPLOAD_BACKEND` / `GCS_UPLOAD_BUCKET` | `gcs` / `kyou-no-kagami-uploads` |
| `GEMINI_API_KEY` | 既定では渡さない（アプリはモックで動く）。`gemini_api_key_secret_id` を指定したときだけ |

- 存在しないパスは LB がバケットの 404 を 200 + `/index.html` に書き換える。この書き換えは
  バケット向けの経路だけで、`/api/*`・`/uploads/*` の 404 はそのまま返す。
- DNS レコードはこのリポジトリでは作らない。ゾーン `tmiyazaki-works-zone` が別プロジェクト
  （`ec-site-handson`）にあるため。下の「DNS レコードの追加」を参照。

## 前提

- **apply / destroy はオーナーが Cloud Shell で実行する**（プロジェクトのオーナー権限で実行する前提）。
  Claude や CI からは apply しない。Cloud Shell には terraform が入っている。版が古い・違う場合は
  `.terraform-version`（1.9.8）に合わせる。
- GCP プロジェクト `kyou-no-kagami` は作成・課金リンク済み。
- 秘密情報はコードにも tfvars にも書かない。MySQL のパスワードは `random_password` で生成し Secret Manager に入れる。
  ただし **state には平文で入る**ため、tfstate バケットの読み取り権限はパスワードの読み取り権限と同じ扱いになる。

## 初期セットアップ

### 1. bootstrap（初回のみ。destroy しない）

```sh
git clone https://github.com/TMiyazaki16/kyou-no-kagami-infra.git
cd kyou-no-kagami-infra/envs/prod-bootstrap
gcloud config set project kyou-no-kagami
terraform init
terraform plan
terraform apply
terraform output     # tfstate_bucket_name / wif_provider_name / *_sa_email を控える
```

作られるもの: tfstate バケット `kyou-no-kagami-tfstate`（バージョニング有効・公開禁止）、
Workload Identity Pool / Provider、サービスアカウント `github-actions-app` と `github-actions-infra`。

#### bootstrap の state をバケットへ移す（推奨）

この時点で bootstrap の state は Cloud Shell のローカル（`terraform.tfstate`）にある。Cloud Shell の
ホームは長期間使わないと消えるため、作ったバケットへ移しておく。

```sh
# envs/prod-bootstrap で
cat > backend.tf <<'EOF'
terraform {
  backend "gcs" {}
}
EOF
terraform init -migrate-state \
  -backend-config="bucket=kyou-no-kagami-tfstate" \
  -backend-config="prefix=kyou-no-kagami/bootstrap"
rm -f terraform.tfstate terraform.tfstate.backup   # 移行が成功したことを確認してから
```

`backend.tf` は commit してよい（値は持たない）。以後の `terraform init` には上と同じ `-backend-config` を付ける。

### 2. prod

```sh
cd ../prod
cp backend.hcl.example backend.hcl       # bucket が tfstate_bucket_name と一致していることを確認
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

- 変数の既定値は `variables.tf` にあるため、通常 `terraform.tfvars` は不要。上書きするときだけ
  `terraform.tfvars.example` をコピーする（`*.tfvars` と `backend.hcl` は commit しない）。
- Cloud SQL の作成に 10〜15 分ほどかかる。
- apply 直後の Cloud Run は初期イメージ（hello）で動いている。アプリのイメージは CI がデプロイする。

### 3. DNS レコードの追加（ec-site-handson 側のゾーン）

```sh
IP=$(terraform output -raw lb_ip_address)    # envs/prod で

gcloud dns record-sets create kyou-no-kagami.tmiyazaki-works.com. \
  --project=ec-site-handson \
  --zone=tmiyazaki-works-zone \
  --type=A --ttl=300 --rrdatas="$IP"

# 確認
gcloud dns record-sets list --project=ec-site-handson --zone=tmiyazaki-works-zone --name=kyou-no-kagami.tmiyazaki-works.com.
dig +short kyou-no-kagami.tmiyazaki-works.com
```

- 実行するアカウントに `ec-site-handson` の DNS 編集権限が必要（オーナーなら可）。
- ゾーンに CAA レコードがある場合、`pki.goog` が許可されていること（EC でもマネージド証明書を使っているので通常は満たしている）。
- LB を destroy → apply すると静的 IP が変わる。そのときは `record-sets update` で付け替える。
- 将来 EC 側の Terraform（`sample-ec-infra` の dns）で管理する案もあるが、EC の prod は平時 destroy する運用のため、
  このレコードはそこに乗せず手動管理にしている。

### 4. apply 後の確認

1. マネージド証明書が `ACTIVE` になるまで待つ（DNS が IP を指してから数十分〜1 時間程度）。
   `gcloud compute ssl-certificates describe kagami-ssl-cert --global --format='value(managed.status)'`
   それまでは HTTPS で証明書エラーや接続エラーが出る（異常ではない）。
2. アプリリポジトリの CI でバックエンドのイメージを build / push し、Cloud Run へデプロイする。
3. フロントをビルドしてバケットへ同期する（例: `gcloud storage rsync -r -d app/frontend/dist gs://kyou-no-kagami-frontend`。
   `index.html` には `Cache-Control: no-cache` を付ける）。
4. `https://kyou-no-kagami.tmiyazaki-works.com/api/health` が 200 を返すことを確認する。

## GitHub Actions に設定する値

`envs/prod-bootstrap` の output を各リポジトリの Actions 変数へ設定する（Pool は destroy しないため値は変わらない）。

| 値 | 設定先 |
| --- | --- |
| `wif_provider_name` | 両リポジトリ |
| `app_deploy_sa_email` | `kyou-no-kagami`（イメージ push・Cloud Run デプロイ・フロント同期） |
| `infra_ci_sa_email` | `kyou-no-kagami-infra`（読み取り専用。fmt / validate / `plan -lock=false` 想定） |

各サービスアカウントへの権限付与は `envs/prod/ci_iam.tf`（tfstate バケットへの読み取りだけは `envs/prod-bootstrap`）。
CI からの Cloud Run デプロイは **イメージの差し替えだけ**にする（`gcloud run deploy --image ...`）。環境変数・
シークレット・Cloud SQL 接続は Terraform 管理なので、CI で変えると次の apply で巻き戻る。

## outputs（envs/prod）

| 名前 | 用途 |
| --- | --- |
| `lb_ip_address` | DNS の A レコードに設定する LB の静的 IP |
| `site_url` | 公開 URL |
| `ssl_certificate_name` | 証明書のプロビジョニング状態の確認用 |
| `frontend_bucket_url` | フロントのビルド成果物のアップロード先 |
| `uploads_bucket_name` | アップロード保存先 |
| `cloud_run_service_name` / `cloud_run_service_uri` | CI のデプロイ先 / 直接 URL（疎通確認用） |
| `cloud_run_service_account_email` | Cloud Run の実行サービスアカウント |
| `cloudsql_connection_name` | Cloud SQL の接続名 |
| `mysql_password_secret_id` | MySQL パスワードのシークレット ID（値は出力しない） |
| `artifact_registry_url` / `backend_image_uri_example` | CI の push 先 |
| `app_deploy_sa_email` | アプリリポジトリ用デプロイ SA |

## 費用の目安

常時かかるのは主に次の 2 つ（2026 年時点の公開価格からの概算。正確な額は料金ページと請求で確認すること）。

- **LB の転送ルール**（HTTP と HTTPS の 2 本）: 月 $18 前後。アクセスが無くてもかかる
- **Cloud SQL db-f1-micro**: インスタンス月 $8〜10 前後 ＋ SSD 10GB・バックアップ分

Cloud Run（最小インスタンス 0）・GCS・Artifact Registry・Secret Manager はデモ規模ならごく小さい。

## 後片付け

### 一時停止（データを残して Cloud SQL の課金を止める）

```sh
# envs/prod で
terraform apply -var='cloudsql_activation_policy=NEVER'
```

Cloud SQL のインスタンス料金は止まる（ストレージ・バックアップ料金は残る）。再開は `ALWAYS` で apply。
LB の料金は残るため、しばらく使わないなら下の全削除にする。止めている間はアプリの API がエラーになる。

### 全削除（envs/prod）

利用者データ（Cloud SQL・アップロード用バケット）は `protect_data = true` で削除から守っているため、2 段階で消す。

```sh
# envs/prod で
terraform apply  -var='protect_data=false'    # 削除保護を外す（この apply ではリソースは消えない）
terraform destroy -var='protect_data=false'
```

- Cloud SQL を消すと自動バックアップも消える。残したいデータは先に `gcloud sql export sql` で GCS 等へ書き出す。
- Cloud SQL のインスタンス名は削除後しばらく再利用できない。すぐ作り直すときは `cloudsql_instance_name` を変える。
- 削除後、`ec-site-handson` 側の A レコード `kyou-no-kagami.tmiyazaki-works.com` も消す
  （`gcloud dns record-sets delete kyou-no-kagami.tmiyazaki-works.com. --project=ec-site-handson --zone=tmiyazaki-works-zone --type=A`）。
- Artifact Registry もイメージごと消える。再構築後は CI でビルドし直す。

### bootstrap / プロジェクトごと

`envs/prod-bootstrap` は原則 destroy しない（費用はほぼ tfstate の保管料のみ）。プロジェクトごと使い終えたら、
`envs/prod` を destroy したうえで `gcloud projects delete kyou-no-kagami` で全て止める（30 日間は復元可能）。

## 開発フロー

アプリリポジトリ（[TMiyazaki16/kyou-no-kagami](https://github.com/TMiyazaki16/kyou-no-kagami)）と同じく Issue ドリブンで進めます（2026-11-23〜）。
MCP のセットアップ（`.mcp.json`、PAT の環境変数 `GITHUB_PERSONAL_ACCESS_TOKEN`）と流れの詳細はアプリリポジトリの README「開発フロー」節、
Claude Code 向けの運用ルールは `AGENTS.md`（`CLAUDE.md` はそのシンボリックリンク）の「開発フロー」節を参照してください。

- PMの条件提示 → Claude が Issue を起票（必須項目：背景 / スコープ / 受け入れ条件 / 対象外）→ Issue ごとのブランチで実装 → PR → PM がレビューしてマージ
- ブランチ名：`<リポジトリ名（小文字）>-i<番号>-<タイトルを英訳したスラッグ>`（例：`kyou-no-kagami-infra-i3-add-seed-job-iam`）。main への直接 push は禁止
- PR 本文に `Closes #<番号>` と検証結果（`terraform fmt -recursive -check`、両 env の `init -backend=false` ＋ `validate`、plan の確認）を書く
- スキル（`.claude/skills/`）：`file-issue` / `start-issue` / `open-pr` / `verify-infra` / `code-review`

### Terraform 固有の注意

- **plan → オーナーの OK → apply** のゲートは変わりません。PR のマージでは apply されず、apply はオーナーが Cloud Shell で行います。
  Claude は plan / apply / destroy / state 操作を実行せず、オーナーが取った plan の出力を読んで置換・削除・公開範囲を確認します。
- 置換（`-/+`）・削除・公開範囲の拡大・`protect_data` の解除を含む PR は、本文の冒頭に明記します。
- **`.github/workflows` はオーナーの手だけで変更します**（Claude 用の PAT には Workflows 権限を付けていません）。
