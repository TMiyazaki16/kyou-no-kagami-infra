# この構成が必要とする GCP API。
#
# 1 つでも漏れると apply が 403 で途中失敗するため、コードで明示する。すでに有効な API に
# 対しては何も起きない（既存の有効化状態を取り込むだけ）。
#
# disable_on_destroy = false にしているのは、destroy のたびに API を無効化すると、再 apply の
# たびに有効化の伝播待ちが発生するため。
#
# envs/prod-bootstrap 側で有効化するもの（二重管理を避けるため、ここには書かない）:
#   cloudresourcemanager / iam / iamcredentials / storage / sts

locals {
  required_services = [
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_services)

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}
