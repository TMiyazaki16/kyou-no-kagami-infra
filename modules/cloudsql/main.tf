# Cloud SQL for MySQL。バックエンド（Cloud Run）から Unix ソケット（/cloudsql/<接続名>）で接続する。
#
# - 接続は Cloud Run の Cloud SQL 接続（内部で Cloud SQL Auth Proxy 相当）を使う。パブリック IP は
#   持つが承認済みネットワークは空のため、IAM（roles/cloudsql.client）を持つ主体からしか繋がらない。
#   VPC / プライベート IP は使わない（サーバーレス VPC コネクタ等の追加費用と構成を避けるため）
# - アプリ用ユーザーのパスワードは random_password で生成し、Secret Manager に格納する。
#   値はコードにも tfvars にも書かない。ただし state には平文で残る（state バケットの権限で守る）

resource "google_sql_database_instance" "this" {
  name             = var.instance_name
  region           = var.region
  database_version = var.database_version

  # Terraform 側の削除保護（destroy / 置換を plan の時点で止める）。
  # 利用者データが入るため env 側の protect_data で既定オンにしている
  deletion_protection = var.deletion_protection

  settings {
    # db-f1-micro などの共有コアは Enterprise エディションでしか使えない。
    # 新しい MySQL では既定が Enterprise Plus になることがあるため明示する
    edition           = "ENTERPRISE"
    tier              = var.tier
    availability_type = "ZONAL"

    # ALWAYS: 起動 / NEVER: 停止（インスタンス料金は止まり、ストレージ料金だけ残る）
    activation_policy = var.activation_policy

    disk_type             = "PD_SSD"
    disk_size             = var.disk_size_gb
    disk_autoresize       = true
    disk_autoresize_limit = var.disk_autoresize_limit_gb

    # GCP 側の削除保護（コンソール / gcloud からの削除も止める）
    deletion_protection_enabled = var.deletion_protection

    ip_configuration {
      ipv4_enabled = true
      # 承認済みネットワークは設定しない（Cloud SQL 接続経由のみ）
      ssl_mode = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled            = var.backup_enabled
      start_time         = "18:00" # UTC（JST 03:00）
      binary_log_enabled = false

      backup_retention_settings {
        retained_backups = var.retained_backups
      }
    }

    maintenance_window {
      day  = 7  # 日曜
      hour = 18 # UTC（JST 月曜 03:00）
    }

    insights_config {
      query_insights_enabled = false
    }
  }
}

resource "google_sql_database" "app" {
  name     = var.database_name
  instance = google_sql_database_instance.this.name

  # アプリのテーブル定義（storage_mysql.py）と同じ。SQLite と同じバイナリ照合にする
  charset   = "utf8mb4"
  collation = "utf8mb4_bin"
}

# ------------------------------------------------------------
# アプリ用ユーザーとパスワード
# ------------------------------------------------------------
resource "random_password" "app" {
  length = 32
  # 接続文字列や環境変数で扱いやすいよう、記号は引用・エスケープの要らないものに限る
  special          = true
  override_special = "-_.~"
}

resource "google_sql_user" "app" {
  name     = var.app_user_name
  instance = google_sql_database_instance.this.name
  host     = "%"
  password = random_password.app.result
}

resource "google_secret_manager_secret" "app_password" {
  secret_id = var.password_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "app_password" {
  secret      = google_secret_manager_secret.app_password.id
  secret_data = random_password.app.result
}
