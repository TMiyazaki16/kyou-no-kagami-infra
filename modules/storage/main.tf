# Cloud Storage 一式。
#
#   - frontend: フロントのビルド成果物（Vite の dist）。LB のバックエンドバケットとして匿名公開する
#   - uploads : 利用者がアップロードした写真・音声。非公開。バックエンド（Cloud Run）だけが読み書きし、
#               /uploads/<名前> はバックエンドが GCS から読んで返す（アプリの UPLOAD_BACKEND=gcs）
#   - LB 用のバックエンドバケット（frontend を LB に繋ぐ口）

# ------------------------------------------------------------
# フロントエンド（静的配信）
# ------------------------------------------------------------
resource "google_storage_bucket" "frontend" {
  name                        = var.frontend_bucket_name
  location                    = var.location
  uniform_bucket_level_access = true

  # ビルド成果物は CI から再配置できるため、中身が残っていても削除できるようにする
  force_destroy = true

  website {
    main_page_suffix = var.index_document

    # LB を経由しない直接アクセス時のフォールバック
    not_found_page = var.index_document
  }
}

# 静的コンテンツを匿名公開する
resource "google_storage_bucket_iam_member" "frontend_public_read" {
  bucket = google_storage_bucket.frontend.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_compute_backend_bucket" "frontend" {
  name        = "${var.name_prefix}-frontend-bucket"
  bucket_name = google_storage_bucket.frontend.name
  enable_cdn  = var.enable_cdn
}

# ------------------------------------------------------------
# アップロード（非公開）
# ------------------------------------------------------------
resource "google_storage_bucket" "uploads" {
  name                        = var.uploads_bucket_name
  location                    = var.location
  uniform_bucket_level_access = true

  # 利用者のデータなので匿名公開を構成上できなくする（配信はバックエンド経由）
  public_access_prevention = "enforced"

  # 利用者のデータが入るため、既定では中身が残っていると削除できない。
  # 後片付けで消すときは env 側の protect_data = false を apply してから destroy する。
  force_destroy = var.uploads_force_destroy
}
