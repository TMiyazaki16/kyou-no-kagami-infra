# バックエンド API（FastAPI）。ロードバランサの /api/* と /uploads/* から serverless NEG 経由で到達する。
#
# - DB は Cloud SQL for MySQL。Cloud SQL 接続を /cloudsql にマウントし、Unix ソケットで繋ぐ
# - パスワードは Secret Manager から環境変数 MYSQL_PASSWORD として注入する
# - アップロードは GCS（UPLOAD_BACKEND=gcs）。認証は実行サービスアカウントの ADC

# ------------------------------------------------------------
# 実行サービスアカウント
# ------------------------------------------------------------
# 既定の Compute Engine サービスアカウント（プロジェクト編集者相当）を使わず、専用の SA に
# 必要な権限だけを付ける。
resource "google_service_account" "runtime" {
  account_id   = "${var.service_name}-run"
  display_name = "Cloud Run runtime for ${var.service_name}"
}

# Cloud SQL 接続に必要。Cloud SQL の IAM はインスタンス単位で付けられないため、プロジェクトレベル。
# cloudsql.client は接続（instances.connect / get）のみで、インスタンスの変更・削除はできない。
resource "google_project_iam_member" "runtime_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# 実行 SA を指定した Cloud Run は、シークレットをこの SA の権限で解決する。
# これが無いとリビジョンの起動時にシークレット解決で失敗する。
resource "google_secret_manager_secret_iam_member" "runtime_mysql_password" {
  secret_id = var.mysql_password_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "runtime_gemini_api_key" {
  count = var.gemini_api_key_secret_id == "" ? 0 : 1

  secret_id = var.gemini_api_key_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

# アップロードの保存・読み出し・削除。objectUser はオブジェクトの作成・取得・削除・一覧までで、
# バケットの設定変更や IAM の変更はできない。
resource "google_storage_bucket_iam_member" "runtime_uploads" {
  bucket = var.upload_bucket_name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.runtime.email}"
}

# ------------------------------------------------------------
# Cloud Run サービス
# ------------------------------------------------------------
resource "google_cloud_run_v2_service" "this" {
  name     = var.service_name
  location = var.location
  ingress  = "INGRESS_TRAFFIC_ALL"

  # バックエンドは状態を持たない（DB とアップロードは外部）ため、作り直しても失うものは無い
  deletion_protection = false

  # サービスレベルの scaling（template.scaling とは別物）。設定しないと API が返す既定値と
  # 設定の差が毎回 plan に出続けるため、既定値どおりの内容を明示して差分を消す。
  scaling {
    min_instance_count = 0
  }

  template {
    service_account = google_service_account.runtime.email

    # Gemini の呼び出し（音声の文字起こし込み）を待てるように長めにする（旧 nginx の
    # proxy_read_timeout と同じ 120 秒）。serverless NEG 経由では LB 側のタイムアウトは
    # 設定できず、この値が効く。
    timeout = "${var.request_timeout_seconds}s"

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instance_count
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.cloudsql_connection_name]
      }
    }

    containers {
      image = var.initial_image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        # リクエスト処理中だけ CPU を割り当てる（既定の課金モード）
        cpu_idle = true
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      env {
        name  = "DB_BACKEND"
        value = "mysql"
      }

      env {
        name  = "MYSQL_HOST"
        value = "/cloudsql/${var.cloudsql_connection_name}"
      }

      env {
        name  = "MYSQL_USER"
        value = var.mysql_user
      }

      env {
        name  = "MYSQL_DATABASE"
        value = var.mysql_database
      }

      env {
        name = "MYSQL_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.mysql_password_secret_name
            version = var.mysql_password_secret_version
          }
        }
      }

      env {
        name  = "UPLOAD_BACKEND"
        value = "gcs"
      }

      env {
        name  = "GCS_UPLOAD_BUCKET"
        value = var.upload_bucket_name
      }

      # 未設定ならアプリはローカルモックで動く（公開デモの既定）。
      # 使う場合は Secret Manager にキーを手動で入れ、シークレット ID を渡す。
      dynamic "env" {
        for_each = var.gemini_api_key_secret_id == "" ? [] : [var.gemini_api_key_secret_id]
        content {
          name = "GEMINI_API_KEY"
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      dynamic "env" {
        for_each = var.gemini_model == "" ? [] : [var.gemini_model]
        content {
          name  = "GEMINI_MODEL"
          value = env.value
        }
      }
    }
  }

  # CI がデプロイした本番イメージを Terraform が初期イメージへ巻き戻さないようにする。
  #
  # client / client_version は「最後にデプロイしたツール」を GCP 側が記録するメタデータで、
  # CI が gcloud run deploy を実行するたびに付与される。無視しないと CI が動くたびに
  # plan へ差分が出続け、本当に見るべき差分が埋もれる。どちらも CI の責任範囲に属する。
  #
  # 環境変数・シークレット・Cloud SQL 接続は Terraform の管理。CI はイメージだけを差し替える
  # （gcloud run deploy --image のみ。--set-env-vars 等を使うと次の apply で巻き戻る）。
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_iam_member.runtime_cloudsql_client,
    google_secret_manager_secret_iam_member.runtime_mysql_password,
    google_secret_manager_secret_iam_member.runtime_gemini_api_key,
    google_storage_bucket_iam_member.runtime_uploads,
  ]
}

# 未認証アクセスを許可（アプリ自体がトークン認証を持つ。入口は LB）
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.allow_unauthenticated ? 1 : 0

  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
