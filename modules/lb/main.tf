# 外部アプリケーションロードバランサ（グローバル）。
# 既定はフロントエンドのバケット、/api/* と /uploads/* は Cloud Run へ振り分ける。
# フロント用のバックエンドバケットは modules/storage が持ち、ID を受け取る。

locals {
  # 存在しないパスへのフォールバック。バケットの 404 を 200 に書き換えてエントリポイントを返す。
  # （現在のフロントはクライアントルーティングを使っていないが、EC と同じ方式で備えておく）
  spa_error_response = {
    match_response_codes   = ["404"]
    path                   = var.spa_entry_path
    override_response_code = 200
  }

  path_matcher_name = "${var.name_prefix}-path-matcher"
}

# ------------------------------------------------------------
# フロントエンド IP
# ------------------------------------------------------------
resource "google_compute_global_address" "lb_ip" {
  name       = "${var.name_prefix}-lb-ip"
  ip_version = "IPV4"
}

# ------------------------------------------------------------
# バックエンド: Cloud Run（API とアップロード配信）
# ------------------------------------------------------------
resource "google_compute_region_network_endpoint_group" "api" {
  name                  = "${var.name_prefix}-neg"
  region                = var.backend_region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

# serverless NEG のバックエンドでは timeout_sec は効かない（Cloud Run 側の timeout が適用される）
resource "google_compute_backend_service" "api" {
  name                  = "${var.name_prefix}-backend-service"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.api.id
  }
}

# ------------------------------------------------------------
# ルーティング（HTTPS）
# ------------------------------------------------------------
# EC との違い: SPA フォールバック（404 → index.html）を path_matcher の既定ではなく、
# バケット向けの path_rule（/*）にだけ付けている。path_matcher の既定に付けると
# /api/* や /uploads/* の path_rule にも継承され、API の 404（例: 家族コードが見つからない）
# やアップロードの 404 が 200 + index.html に化けるため。
resource "google_compute_url_map" "https" {
  name            = "${var.name_prefix}-url-map"
  default_service = var.frontend_backend_bucket_id

  host_rule {
    hosts        = [var.site_domain]
    path_matcher = local.path_matcher_name
  }

  path_matcher {
    name            = local.path_matcher_name
    default_service = var.frontend_backend_bucket_id

    # パスは最長一致のため、/api/* と /uploads/* は下の /* より優先される
    path_rule {
      paths   = ["/api/*", "/uploads/*"]
      service = google_compute_backend_service.api.id
    }

    path_rule {
      paths   = ["/*"]
      service = var.frontend_backend_bucket_id

      custom_error_response_policy {
        error_response_rule {
          match_response_codes   = local.spa_error_response.match_response_codes
          path                   = local.spa_error_response.path
          override_response_code = local.spa_error_response.override_response_code
        }
        error_service = var.frontend_backend_bucket_id
      }
    }
  }
}

# ------------------------------------------------------------
# HTTPS フロントエンド
# ------------------------------------------------------------
# マネージド証明書は DNS が LB の IP を指してから ACTIVE になる（数十分かかる場合がある）
resource "google_compute_managed_ssl_certificate" "this" {
  name = "${var.name_prefix}-ssl-cert"

  managed {
    domains = [var.site_domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "this" {
  name             = "${var.name_prefix}-https-proxy"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${var.name_prefix}-https-forwarding-rule"
  target                = google_compute_target_https_proxy.this.id
  ip_address            = google_compute_global_address.lb_ip.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# ------------------------------------------------------------
# HTTP フロントエンド（HTTPS へリダイレクト）
# ------------------------------------------------------------
resource "google_compute_url_map" "http_redirect" {
  name = "${var.name_prefix}-http-redirect-map"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "this" {
  name    = "${var.name_prefix}-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name_prefix}-http-forwarding-rule"
  target                = google_compute_target_http_proxy.this.id
  ip_address            = google_compute_global_address.lb_ip.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
