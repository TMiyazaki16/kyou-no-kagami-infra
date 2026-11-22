output "tfstate_bucket_name" {
  description = "envs/prod の backend.hcl の bucket に設定する値"
  value       = google_storage_bucket.tfstate.name
}

output "wif_provider_name" {
  description = "GitHub Actions の google-github-actions/auth に設定する workload_identity_provider の値（両リポジトリ共通）"
  value       = module.github_oidc.provider_name
}

output "app_deploy_sa_email" {
  description = "アプリリポジトリ（kyou-no-kagami）の CI が使うデプロイ用サービスアカウント"
  value       = module.github_oidc.service_account_emails["app"]
}

output "infra_ci_sa_email" {
  description = "infra リポジトリ（kyou-no-kagami-infra）の CI が使うサービスアカウント（読み取り専用。plan 想定）"
  value       = module.github_oidc.service_account_emails["infra"]
}
