variable "instance_name" {
  description = "Cloud SQL インスタンス名（削除後しばらくは同じ名前で再作成できない点に注意）"
  type        = string
}

variable "region" {
  description = "インスタンスを配置するリージョン"
  type        = string
}

variable "database_version" {
  description = "MySQL のバージョン（例: MYSQL_8_0 / MYSQL_8_4）"
  type        = string
  default     = "MYSQL_8_4"

  validation {
    condition     = startswith(var.database_version, "MYSQL_8")
    error_message = "database_version は MySQL 8 系（MYSQL_8_*）を指定する。"
  }
}

variable "tier" {
  description = "マシンタイプ。共有コアの db-f1-micro が最小"
  type        = string
  default     = "db-f1-micro"
}

variable "activation_policy" {
  description = "ALWAYS（起動）または NEVER（停止。インスタンス料金が止まりストレージ料金だけ残る）"
  type        = string
  default     = "ALWAYS"

  validation {
    condition     = contains(["ALWAYS", "NEVER"], var.activation_policy)
    error_message = "activation_policy は ALWAYS または NEVER を指定する。"
  }
}

variable "disk_size_gb" {
  description = "ディスクサイズ（GB、最小 10）"
  type        = number
  default     = 10
}

variable "disk_autoresize_limit_gb" {
  description = "自動拡張の上限（GB）。費用の上限を決めるため 0（無制限）にしない"
  type        = number
  default     = 20

  validation {
    condition     = var.disk_autoresize_limit_gb > 0
    error_message = "disk_autoresize_limit_gb は 1 以上で指定する（0 は無制限になる）。"
  }
}

variable "deletion_protection" {
  description = "削除保護（Terraform 側と GCP 側の両方）。true の間は destroy できない"
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "自動バックアップを有効にするか"
  type        = bool
  default     = true
}

variable "retained_backups" {
  description = "保持する自動バックアップの数"
  type        = number
  default     = 7
}

variable "database_name" {
  description = "アプリが使うデータベース名（アプリの MYSQL_DATABASE）"
  type        = string
}

variable "app_user_name" {
  description = "アプリが使う MySQL ユーザー名（アプリの MYSQL_USER）"
  type        = string
}

variable "password_secret_id" {
  description = "アプリ用パスワードを格納する Secret Manager のシークレット ID"
  type        = string
}
