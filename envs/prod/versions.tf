terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # state は envs/prod-bootstrap が作る GCS バケットに置く。値は backend.hcl から渡す
  # （terraform init -backend-config=backend.hcl。backend.hcl.example 参照）。
  backend "gcs" {}
}
