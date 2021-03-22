variable "project" {
  description = "Project ID where Suricata should be deployed"
}

variable "custom_rules_path" {
  description = "Test rules that will easily trigger alerts"
}

module "suricata" {
  source = "./.."

  project = var.project
  network = google_compute_network.ids.id
  subnet  = google_compute_subnetwork.ids.id
  zone    = "us-central1-a"
  target_subnets = [
    google_compute_subnetwork.test.id
  ]
  custom_rules_path = var.custom_rules_path
}

resource "google_compute_network" "ids" {
  project                 = var.project
  name                    = "suricata-test"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "ids" {
  project       = var.project
  name          = "suricata-test-subnet"
  network       = google_compute_network.ids.id
  ip_cidr_range = "172.21.0.0/29"
  region        = "us-central1"
}

resource "google_compute_router" "router" {
  project = var.project
  name    = "suricata-test-router"
  region  = google_compute_subnetwork.ids.region
  network = google_compute_network.ids.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  project                = var.project
  name                   = "suricata-test-nat"
  router                 = google_compute_router.router.name
  region                 = google_compute_router.router.region
  nat_ip_allocate_option = "AUTO_ONLY"

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# TEST INSTANCE
resource "google_compute_subnetwork" "test" {
  project       = var.project
  name          = "suricata-test-subnet-2"
  network       = google_compute_network.ids.id
  ip_cidr_range = "172.21.1.0/24"
  region        = "us-central1"
}

resource "google_compute_instance" "default" {
  project      = var.project
  name         = "test"
  machine_type = "e2-small"
  zone         = "us-central1-a"

  tags = ["use-suricata", "http"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }
  metadata_startup_script = <<EOF
#! /bin/bash
apt-get update
apt-get install apache2 -y
EOF
  network_interface {
    subnetwork = google_compute_subnetwork.test.id

    access_config {
      // Ephemeral IP
    }
  }
}

resource "google_compute_firewall" "iap" {
  project = var.project
  name    = "allow-iap-to-test"
  network = google_compute_network.ids.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["use-suricata"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
resource "google_compute_firewall" "web" {
  project = var.project
  name    = "allow-web-to-test"
  network = google_compute_network.ids.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http"]
}