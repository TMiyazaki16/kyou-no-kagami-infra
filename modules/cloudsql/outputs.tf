output "instance_name" {
  description = "Cloud SQL インスタンス名"
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "接続名（<PROJECT>:<REGION>:<INSTANCE>）。Cloud Run の Cloud SQL 接続と /cloudsql/<これ> に使う"
  value       = google_sql_database_instance.this.connection_name
}

output "database_name" {
  description = "アプリ用データベース名"
  value       = google_sql_database.app.name
}

output "app_user_name" {
  description = "アプリ用 MySQL ユーザー名"
  value       = google_sql_user.app.name
}

output "password_secret_id" {
  description = "アプリ用パスワードを格納したシークレットの ID（短い名前）"
  value       = google_secret_manager_secret.app_password.secret_id
}

output "password_secret_name" {
  description = "アプリ用パスワードを格納したシークレットのリソース名（IAM 付与に使う）"
  value       = google_secret_manager_secret.app_password.id
}

output "password_secret_version" {
  description = "格納したシークレットのバージョン番号。Cloud Run はこの番号を固定で参照する"
  value       = google_secret_manager_secret_version.app_password.version
}
