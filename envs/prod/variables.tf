variable "project_id" {
  description = "GCP プロジェクト ID"
  type        = string
  default     = "kyou-no-kagami"
}

variable "region" {
  description = "リソースを配置するリージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "name_prefix" {
  description = "リソース名の接頭辞（Artifact Registry のリポジトリ ID にもなる）"
  type        = string
  default     = "kagami"
}

variable "site_domain" {
  description = "サイトを公開する FQDN（マネージド証明書の対象。DNS レコードは別プロジェクトのゾーンに手動で追加する）"
  type        = string
  default     = "kyou-no-kagami.tmiyazaki-works.com"
}

variable "frontend_bucket_name" {
  description = "フロントエンド（ビルド成果物）配信用バケット名（グローバルで一意）"
  type        = string
  default     = "kyou-no-kagami-frontend"
}

variable "uploads_bucket_name" {
  description = "アップロード（写真・音声）保存用バケット名（グローバルで一意）"
  type        = string
  default     = "kyou-no-kagami-uploads"
}

variable "bucket_location" {
  description = "バケットのロケーション"
  type        = string
  default     = "ASIA-NORTHEAST1"
}

variable "protect_data" {
  description = <<-EOT
    利用者データ（Cloud SQL・アップロード用バケット）を削除から守るか。
    true の間は Cloud SQL の削除保護が有効で、中身の残ったアップロード用バケットは消せない。
    後片付けで destroy するときだけ false にして一度 apply してから destroy する。
  EOT
  type        = bool
  default     = true
}

variable "cloudsql_instance_name" {
  description = "Cloud SQL インスタンス名。削除後しばらく（最大 1 週間程度）同じ名前で作り直せないため、destroy 直後に再構築するときは変える"
  type        = string
  default     = "kagami-mysql"
}

variable "cloudsql_database_version" {
  description = "Cloud SQL の MySQL バージョン"
  type        = string
  default     = "MYSQL_8_4"
}

variable "cloudsql_tier" {
  description = "Cloud SQL のマシンタイプ"
  type        = string
  default     = "db-f1-micro"
}

variable "cloudsql_activation_policy" {
  description = "Cloud SQL を起動しておくか（ALWAYS）、停止するか（NEVER。インスタンス料金が止まる）"
  type        = string
  default     = "ALWAYS"
}

variable "mysql_database" {
  description = "アプリ用データベース名（MYSQL_DATABASE）"
  type        = string
  default     = "kagami"
}

variable "mysql_user" {
  description = "アプリ用 MySQL ユーザー名（MYSQL_USER）"
  type        = string
  default     = "kagami_app"
}

variable "cloudrun_max_instance_count" {
  description = "Cloud Run のインスタンス数上限"
  type        = number
  default     = 2
}

variable "gemini_api_key_secret_id" {
  description = "GEMINI_API_KEY を入れた手動作成のシークレット ID。空ならキーを渡さず、アプリはモックで動く"
  type        = string
  default     = ""
}

variable "gemini_model" {
  description = "GEMINI_MODEL。空ならアプリ既定のモデル"
  type        = string
  default     = ""
}
