variable "project_id" {
  description = "GCP プロジェクト ID（実行 SA へのプロジェクトレベルの付与に使う）"
  type        = string
}

variable "service_name" {
  description = "Cloud Run サービス名（実行 SA の ID は <これ>-run になる。合計 30 文字以内）"
  type        = string

  validation {
    condition     = length(var.service_name) <= 26
    error_message = "service_name は 26 文字以内にする（サービスアカウント ID <service_name>-run が 30 文字を超えるため）。"
  }
}

variable "location" {
  description = "Cloud Run サービスを配置するリージョン"
  type        = string
}

variable "initial_image" {
  description = "初期コンテナイメージ。実際のアプリイメージは CI からデプロイする（PORT 環境変数に従うイメージであること）"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "container_port" {
  description = "コンテナが待ち受けるポート（アプリの Dockerfile は uvicorn --port 8000）"
  type        = number
  default     = 8000
}

variable "cpu" {
  description = "コンテナの CPU 上限"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "コンテナのメモリ上限"
  type        = string
  default     = "512Mi"
}

variable "request_timeout_seconds" {
  description = "リクエストのタイムアウト（秒）"
  type        = number
  default     = 120
}

variable "max_instance_count" {
  description = "インスタンス数の上限（費用と Cloud SQL の接続数の上限を兼ねる）"
  type        = number
  default     = 2

  validation {
    condition     = var.max_instance_count >= 1
    error_message = "max_instance_count は 1 以上で指定する。"
  }
}

variable "allow_unauthenticated" {
  description = "未認証の呼び出しを許可するか（ロードバランサ経由で公開するため既定は true）"
  type        = bool
  default     = true
}

variable "cloudsql_connection_name" {
  description = "Cloud SQL の接続名（<PROJECT>:<REGION>:<INSTANCE>）"
  type        = string
}

variable "mysql_user" {
  description = "アプリの MYSQL_USER"
  type        = string
}

variable "mysql_database" {
  description = "アプリの MYSQL_DATABASE"
  type        = string
}

variable "mysql_password_secret_name" {
  description = "MYSQL_PASSWORD を格納したシークレット（ID またはリソース名）"
  type        = string
}

variable "mysql_password_secret_version" {
  description = "参照するシークレットのバージョン。固定番号にすると、パスワード更新時に新しいリビジョンが作られる"
  type        = string
  default     = "latest"
}

variable "upload_bucket_name" {
  description = "アップロード保存先のバケット名（アプリの GCS_UPLOAD_BUCKET）"
  type        = string
}

variable "gemini_api_key_secret_id" {
  description = "GEMINI_API_KEY を格納した手動作成のシークレット ID。空ならキーを渡さない（アプリはモックで動く）"
  type        = string
  default     = ""
}

variable "gemini_model" {
  description = "GEMINI_MODEL。空ならアプリ既定のモデルを使う"
  type        = string
  default     = ""
}
