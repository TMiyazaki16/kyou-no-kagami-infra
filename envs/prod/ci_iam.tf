# GitHub Actions のサービスアカウントに対する権限付与。
#
# Workload Identity 連携（Pool / Provider）とサービスアカウント本体は envs/prod-bootstrap が作る
# （destroy しない state）。ここで行うのは「この state が持つリソースに対して、何をしてよいか」の
# 付与だけ。付与先のバケットや Cloud Run サービスは作り直されうるため、その紐づけもここで持つ。
#
# 権限は原則プロジェクト全体ではなく、対象のリソース単位で与える。プロジェクトレベルで与えると
# 今後追加される別のリソースにも自動的に権限が及んでしまうため。
#
# 前提: envs/prod-bootstrap を先に apply しておくこと。未適用の場合、下の data 参照が
# 「サービスアカウントが見つからない」というエラーになる。

data "google_service_account" "ci_app" {
  account_id = "github-actions-app"
}

data "google_service_account" "ci_infra" {
  account_id = "github-actions-infra"
}

# ============================================================
# アプリリポジトリ（kyou-no-kagami）
#   - バックエンド: イメージを push し、Cloud Run へデプロイする
#   - フロントエンド: ビルド成果物をバケットへ同期する
# EC はフロント / バックでリポジトリが分かれていたが、かがみは 1 リポジトリのため SA も 1 つ。
# ============================================================
resource "google_artifact_registry_repository_iam_member" "ci_app_writer" {
  project    = var.project_id
  location   = var.region
  repository = module.artifactregistry.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_service_account.ci_app.email}"
}

resource "google_cloud_run_v2_service_iam_member" "ci_app_developer" {
  name     = module.cloudrun.service_name
  location = module.cloudrun.location
  role     = "roles/run.developer"
  member   = "serviceAccount:${data.google_service_account.ci_app.email}"
}

# Cloud Run のデプロイには「アプリを動かす実行サービスアカウントを使ってよい」権限が要る。
# プロジェクトレベルで付けるとプロジェクト内の全サービスアカウントになりすませてしまうため、
# 実行サービスアカウント 1 つに限定する。
resource "google_service_account_iam_member" "ci_app_act_as_runtime" {
  service_account_id = module.cloudrun.service_account_name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_service_account.ci_app.email}"
}

# objectViewer ではなく objectAdmin なのは、古いファイルの削除（rsync -d 相当）が必要なため。
resource "google_storage_bucket_iam_member" "ci_app_frontend_object_admin" {
  bucket = module.storage.frontend_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_service_account.ci_app.email}"
}

# rsync は同期を始める前に宛先バケットのメタデータを取得するため storage.buckets.get が要る。
# legacyBucketReader が持つのは storage.buckets.get と storage.objects.list のみで、
# バケットの設定変更や削除はできない。
resource "google_storage_bucket_iam_member" "ci_app_frontend_bucket_reader" {
  bucket = module.storage.frontend_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${data.google_service_account.ci_app.email}"
}

# ============================================================
# infra リポジトリ（kyou-no-kagami-infra）
#   CI での fmt / validate / plan を想定した読み取り専用の権限。apply はオーナーが
#   Cloud Shell で行うため、変更権限は与えない。
#   state の読み取り権限は tfstate バケットを持つ envs/prod-bootstrap 側で付与している。
#
#   plan の refresh は全リソースと IAM ポリシーを読むため、ここだけはプロジェクトレベルで
#   読み取りロールを付ける（いずれも変更権限を含まない）。
#   ※ この権限で plan が完走するかは未検証（初回の CI 実行で 403 が出たら不足分を足す）
# ============================================================
resource "google_project_iam_member" "ci_infra_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${data.google_service_account.ci_infra.email}"
}

resource "google_project_iam_member" "ci_infra_security_reviewer" {
  project = var.project_id
  role    = "roles/iam.securityReviewer"
  member  = "serviceAccount:${data.google_service_account.ci_infra.email}"
}

# google_secret_manager_secret_version の refresh は値そのものを読む。state を読める時点で
# パスワードは見えている（state に平文で入る）ため、追加で露出が増えるわけではない。
resource "google_secret_manager_secret_iam_member" "ci_infra_mysql_password" {
  secret_id = module.cloudsql.password_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_service_account.ci_infra.email}"
}
