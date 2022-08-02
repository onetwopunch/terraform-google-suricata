provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

locals {
  use_custom_rules   = var.custom_rules_path != ""
  rule_file          = "/opt/my.rules"
  rule_entry         = local.use_custom_rules ? " - ${local.rule_file}" : ""
  custom_rule_bucket = local.use_custom_rules ? split("/", var.custom_rules_path)[2] : ""

  default_suricata_config = templatefile("${path.module}/templates/suricata.yaml", {
    rule_entry = local.rule_entry
  })
  suricata_config = var.suricata_config_path != "" ? file(var.suricata_config_path) : local.default_suricata_config
}

resource "google_compute_instance_template" "ids" {
  name_prefix  = "${var.prefix}-"
  machine_type = "e2-medium"

  disk {
    source_image = var.vm_source_image
    auto_delete  = true
    boot         = true
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup.sh", {
    fast_config       = var.enable_fast_export ? file("${path.module}/templates/fast.conf") : ""
    eve_config        = var.enable_eve_export ? file("${path.module}/templates/eve.conf") : ""
    suricata_config   = local.suricata_config
    custom_rules_path = var.custom_rules_path
    rule_file         = local.rule_file
  })

  service_account {
    email  = google_service_account.ids.email
    scopes = ["cloud-platform"]
  }

  network_interface {
    subnetwork = var.subnet
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "ids" {
  name               = "${var.prefix}-igm"
  base_instance_name = var.prefix
  zone               = var.zone
  target_size        = 1

  version {
    name              = "suricata-v1"
    instance_template = google_compute_instance_template.ids.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.ids.id
    initial_delay_sec = 300
  }
}

resource "google_compute_packet_mirroring" "ids" {
  name        = "${var.prefix}-mirroring"
  description = "Packet mirror for Suricata"
  network {
    url = var.network
  }
  collector_ilb {
    url = google_compute_forwarding_rule.ids.id
  }
  mirrored_resources {
    tags = var.target_tags
    dynamic "subnetworks" {
      for_each = var.target_subnets
      content {
        url = subnetworks.value
      }
    }
    dynamic "instances" {
      for_each = var.target_instances
      content {
        url = instances.value
      }
    }
  }
  filter {
    ip_protocols = var.filter.ip_protocols
    cidr_ranges  = var.filter.cidr_ranges
    direction    = var.filter.direction
  }
}

resource "google_compute_region_backend_service" "ids" {
  name          = "${var.prefix}-svc"
  health_checks = [google_compute_health_check.ids.id]
  backend {
    group          = google_compute_instance_group_manager.ids.instance_group
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_health_check" "ids" {
  name               = "${var.prefix}-healthcheck"
  check_interval_sec = 300
  timeout_sec        = 20
  tcp_health_check {
    port = "80"
  }
}

resource "google_compute_forwarding_rule" "ids" {
  name = "${var.prefix}-ilb"

  is_mirroring_collector = true
  ip_protocol            = "TCP"
  load_balancing_scheme  = "INTERNAL"
  backend_service        = google_compute_region_backend_service.ids.id
  all_ports              = true
  network                = var.network
  subnetwork             = var.subnet
  network_tier           = "PREMIUM"
}

resource "google_service_account" "ids" {
  account_id   = var.prefix
  display_name = "Suricata Service Account"
}

resource "google_project_iam_member" "ids" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])
  role   = each.value
  member = "serviceAccount:${google_service_account.ids.email}"
}

resource "google_storage_bucket_iam_member" "ids" {
  count  = local.use_custom_rules ? 1 : 0
  bucket = local.custom_rule_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.ids.email}"
}

resource "google_compute_firewall" "ids" {
  name     = "allow-all-to-suricata-except-ssh"
  network  = var.network
  priority = var.base_priority
  allow {
    protocol = "all"
  }
  source_ranges           = ["0.0.0.0/0"]
  target_service_accounts = [google_service_account.ids.email]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "ids_deny_ssh" {
  name     = "deny-ssh-to-suricata"
  network  = var.network
  priority = var.base_priority + 1
  deny {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges           = ["35.235.240.0/20"]
  target_service_accounts = [google_service_account.ids.email]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
resource "google_compute_firewall" "ids_iap" {
  name     = "allow-iap-to-suricata"
  network  = var.network
  priority = var.base_priority + 2

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges           = ["35.235.240.0/20"]
  target_service_accounts = [google_service_account.ids.email]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}