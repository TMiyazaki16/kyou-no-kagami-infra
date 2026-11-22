output "frontend_bucket_name" {
  description = "フロントエンド配信用バケット名"
  value       = google_storage_bucket.frontend.name
}

output "frontend_bucket_url" {
  description = "フロントエンド配信用バケットの gs:// URL（ビルド成果物のアップロード先）"
  value       = google_storage_bucket.frontend.url
}

output "frontend_backend_bucket_id" {
  description = "LB の URL マップから参照するバックエンドバケットの ID"
  value       = google_compute_backend_bucket.frontend.id
}

output "uploads_bucket_name" {
  description = "アップロード用バケット名（アプリの GCS_UPLOAD_BUCKET）"
  value       = google_storage_bucket.uploads.name
}
