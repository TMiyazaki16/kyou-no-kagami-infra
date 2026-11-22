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

variable "tfstate_bucket_name" {
  description = "envs/prod の tfstate を置くバケット名（グローバルで一意。envs/prod/backend.hcl の bucket と一致させる）"
  type        = string
  default     = "kyou-no-kagami-tfstate"
}

variable "tfstate_bucket_location" {
  description = "tfstate バケットのロケーション"
  type        = string
  default     = "ASIA-NORTHEAST1"
}

variable "tfstate_noncurrent_versions_to_keep" {
  description = "tfstate の非現行世代を何世代まで残すか"
  type        = number
  default     = 20
}

variable "github_owner" {
  description = "信頼する GitHub のオーナー"
  type        = string
  default     = "TMiyazaki16"
}

variable "github_repositories" {
  description = <<-EOT
    デプロイ用サービスアカウントを作るリポジトリ（キーはサービスアカウント ID の一部になる）。
    キー app / infra は envs/prod/ci_iam.tf と outputs.tf が参照しているため変えない。
  EOT
  type        = map(string)
  default = {
    app   = "kyou-no-kagami"
    infra = "kyou-no-kagami-infra"
  }

  validation {
    condition     = contains(keys(var.github_repositories), "app") && contains(keys(var.github_repositories), "infra")
    error_message = "github_repositories にはキー app と infra の両方が必要。"
  }
}
