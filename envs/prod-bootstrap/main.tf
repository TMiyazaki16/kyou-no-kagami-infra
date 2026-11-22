# 作り直さない前提のリソースを置くルートモジュール。一度だけ apply し、destroy しない。
#
# ここに置くのは次の 2 つ。
#
#   - envs/prod の tfstate を置く GCS バケット
#     envs/prod が自分の state 置き場を作ることはできない（鶏と卵）。また state を消すと
#     envs/prod の管理下にあるリソースを Terraform から辿れなくなる。
#   - GitHub Actions 用の Workload Identity 連携とデプロイ用サービスアカウント
#     Pool は削除後 30 日間ソフトデリート状態で残り、同じ ID で再作成できない。作っても
#     課金されないため消しても得が無く、作り直すと GitHub 側の設定（2 リポジトリ分）を手で直す
#     必要が生じる。
#
# この state 自体はローカル（Cloud Shell のホーム）に置かれる。バケットを作った後で同じバケットへ
# 移す手順は README.md の「bootstrap の state をバケットへ移す」を参照。
#
# 権限（ロール）の付与は原則ここでは行わない。付与先の Cloud Run やバケットは envs/prod 側に
# あるため、それらに紐づく IAM バインディングも envs/prod/ci_iam.tf で一緒に管理する。
# 例外は tfstate バケットへの権限で、バケットがこの state にあるためここで付与する。

# ------------------------------------------------------------
# tfstate バケット
# ------------------------------------------------------------
resource "google_storage_bucket" "tfstate" {
  depends_on = [google_project_service.required]

  name                        = var.tfstate_bucket_name
  location                    = var.tfstate_bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # state を失うと管理下のリソースを辿れなくなるため、中身ごとの削除は許さない
  force_destroy = false

  # 誤って上書き・削除した state を戻せるように世代を残す
  versioning {
    enabled = true
  }

  # 古い世代が増え続けないよう、新しい世代が一定数を超えた非現行世代を消す
  lifecycle_rule {
    condition {
      num_newer_versions = var.tfstate_noncurrent_versions_to_keep
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}

# ------------------------------------------------------------
# GitHub Actions（Workload Identity 連携）
# ------------------------------------------------------------
module "github_oidc" {
  source = "../../modules/github_oidc"

  depends_on = [google_project_service.required]

  github_owner = var.github_owner
  repositories = var.github_repositories
}

# infra リポジトリの CI（terraform plan 想定）が state を読めるようにする。
# 読み取りのみのため、CI の plan は -lock=false で実行する前提（ロックの作成には書き込み権限が要る）。
# 注意: state には Cloud SQL のアプリ用パスワードが平文で入る。state を読める主体は
# パスワードも読めるのと同じ扱いになる。
resource "google_storage_bucket_iam_member" "ci_infra_state_reader" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${module.github_oidc.service_account_emails["infra"]}"
}
