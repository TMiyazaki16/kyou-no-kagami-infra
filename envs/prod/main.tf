# きょうのかがみ本番環境のルートモジュール。
#
# 依存の向き:
#   cloudsql ──┐
#   storage ───┼→ cloudrun（Cloud SQL 接続・パスワード・アップロード先）
#              │
#   storage ───┴→ lb ←── cloudrun
#
#   artifactregistry は他から参照されない。CI がビルドしたイメージの置き場で、
#   Cloud Run へのデプロイは CI が行う（Terraform は image を ignore_changes にしている）。
#
# DNS レコードはここでは作らない。公開ドメインのゾーン（tmiyazaki-works-zone）は別プロジェクト
# （ec-site-handson）にあるため。output の lb_ip_address を A レコードとして手動で追加する
# （README.md の「DNS レコードの追加」）。
#
# 利用者データ（Cloud SQL・アップロード用バケット）は protect_data で削除から守っている。
# 後片付けで消すときは protect_data = false を apply してから destroy する。

module "storage" {
  source = "../../modules/storage"

  depends_on = [google_project_service.required]

  name_prefix           = var.name_prefix
  frontend_bucket_name  = var.frontend_bucket_name
  uploads_bucket_name   = var.uploads_bucket_name
  location              = var.bucket_location
  uploads_force_destroy = !var.protect_data
}

module "artifactregistry" {
  source = "../../modules/artifactregistry"

  depends_on = [google_project_service.required]

  repository_id = var.name_prefix
  location      = var.region
  description   = "Container images for ${var.name_prefix}"
}

module "cloudsql" {
  source = "../../modules/cloudsql"

  depends_on = [google_project_service.required]

  instance_name       = var.cloudsql_instance_name
  region              = var.region
  database_version    = var.cloudsql_database_version
  tier                = var.cloudsql_tier
  activation_policy   = var.cloudsql_activation_policy
  deletion_protection = var.protect_data

  database_name      = var.mysql_database
  app_user_name      = var.mysql_user
  password_secret_id = "${var.name_prefix}-mysql-password"
}

module "cloudrun" {
  source = "../../modules/cloudrun"

  depends_on = [google_project_service.required]

  project_id   = var.project_id
  service_name = "${var.name_prefix}-back"
  location     = var.region

  max_instance_count = var.cloudrun_max_instance_count

  cloudsql_connection_name      = module.cloudsql.connection_name
  mysql_user                    = module.cloudsql.app_user_name
  mysql_database                = module.cloudsql.database_name
  mysql_password_secret_name    = module.cloudsql.password_secret_name
  mysql_password_secret_version = module.cloudsql.password_secret_version

  upload_bucket_name = module.storage.uploads_bucket_name

  # 公開デモは当面モック動作（空のまま）
  gemini_api_key_secret_id = var.gemini_api_key_secret_id
  gemini_model             = var.gemini_model
}

module "lb" {
  source = "../../modules/lb"

  depends_on = [google_project_service.required]

  name_prefix                = var.name_prefix
  site_domain                = var.site_domain
  backend_region             = var.region
  cloud_run_service_name     = module.cloudrun.service_name
  frontend_backend_bucket_id = module.storage.frontend_backend_bucket_id
}
