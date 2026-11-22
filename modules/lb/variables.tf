variable "name_prefix" {
  description = "ロードバランサ関連リソース名の接頭辞"
  type        = string
}

variable "site_domain" {
  description = "配信するサイトの FQDN。マネージド証明書の対象ドメインにもなる"
  type        = string
}

variable "backend_region" {
  description = "serverless NEG を配置するリージョン（Cloud Run と同じ）"
  type        = string
}

variable "cloud_run_service_name" {
  description = "/api/* と /uploads/* のルーティング先となる Cloud Run サービス名"
  type        = string
}

variable "frontend_backend_bucket_id" {
  description = "既定のバックエンドとなるバックエンドバケットの ID（modules/storage の output）"
  type        = string
}

variable "spa_entry_path" {
  description = "404 時に返すフロントのエントリポイント"
  type        = string
  default     = "/index.html"
}
