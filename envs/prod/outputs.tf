output "lb_ip_address" {
  description = "ロードバランサのグローバル静的 IP。ec-site-handson 側の Cloud DNS ゾーンに site_domain の A レコードとして追加する"
  value       = module.lb.ip_address
}

output "site_url" {
  description = "サイトの公開 URL"
  value       = "https://${var.site_domain}"
}

output "ssl_certificate_name" {
  description = "マネージド SSL 証明書のリソース名（プロビジョニング状態の確認用）"
  value       = module.lb.ssl_certificate_name
}

output "frontend_bucket_url" {
  description = "フロントのビルド成果物（app/frontend/dist）のアップロード先"
  value       = module.storage.frontend_bucket_url
}

output "uploads_bucket_name" {
  description = "アップロード保存先のバケット名（Cloud Run の GCS_UPLOAD_BUCKET に設定済み）"
  value       = module.storage.uploads_bucket_name
}

output "cloud_run_service_name" {
  description = "バックエンドの Cloud Run サービス名（CI の gcloud run deploy の対象）"
  value       = module.cloudrun.service_name
}

output "cloud_run_service_uri" {
  description = "Cloud Run が払い出す直接 URL（疎通確認用）"
  value       = module.cloudrun.service_uri
}

output "cloud_run_service_account_email" {
  description = "Cloud Run の実行サービスアカウント"
  value       = module.cloudrun.service_account_email
}

output "cloudsql_connection_name" {
  description = "Cloud SQL の接続名（MYSQL_HOST=/cloudsql/<これ>）"
  value       = module.cloudsql.connection_name
}

output "mysql_password_secret_id" {
  description = "アプリ用 MySQL パスワードを格納したシークレット ID（値は Secret Manager で確認する。output には出さない）"
  value       = module.cloudsql.password_secret_id
}

output "artifact_registry_url" {
  description = "イメージ URI の接頭辞。CI はここへ push する"
  value       = module.artifactregistry.repository_url
}

output "backend_image_uri_example" {
  description = "バックエンドのイメージ URI の例（タグは CI が付ける）"
  value       = "${module.artifactregistry.repository_url}/${var.name_prefix}-back:<tag>"
}

output "app_deploy_sa_email" {
  description = "アプリリポジトリ用デプロイサービスアカウント（本体は envs/prod-bootstrap が管理）"
  value       = data.google_service_account.ci_app.email
}
