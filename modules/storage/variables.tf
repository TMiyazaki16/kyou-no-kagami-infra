variable "name_prefix" {
  description = "LB 用バックエンドバケットなど、バケット以外のリソース名の接頭辞"
  type        = string
}

variable "frontend_bucket_name" {
  description = "フロントエンド（ビルド成果物）配信用バケットの名前"
  type        = string
}

variable "uploads_bucket_name" {
  description = "アップロード（写真・音声）保存用バケットの名前"
  type        = string
}

variable "location" {
  description = "バケットのロケーション"
  type        = string
  default     = "ASIA-NORTHEAST1"
}

variable "index_document" {
  description = "ディレクトリ参照時に返すドキュメント"
  type        = string
  default     = "index.html"
}

variable "enable_cdn" {
  description = "バックエンドバケットで Cloud CDN を有効にするか"
  type        = bool
  default     = false
}

variable "uploads_force_destroy" {
  description = "アップロード用バケットに中身が残っていても削除できるようにするか（利用者データのため既定は false）"
  type        = bool
  default     = false
}
