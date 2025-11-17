###############################################
# Terraform Provider
###############################################
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "evident-scion-472000-m7"   # <-- your project ID
  region  = "us-central1"
  zone    = "us-central1-a"
}

###############################################
# VPC Network
###############################################
resource "google_compute_network" "vpc" {
  name                    = "flask-vpc"
  auto_create_subnetworks = false
}

###############################################
# Public Subnet for Flask VM
###############################################
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
}

###############################################
# Firewall Rule - Allow Flask App (port 5000)
###############################################
resource "google_compute_firewall" "allow_flask" {
  name    = "allow-flask"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-flask"]
}

###############################################
# Compute Engine Instance Running Docker Container
###############################################
resource "google_compute_instance" "flask_vm" {
  name         = "flask-vm"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  # COS (Container-Optimized OS)
  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  # Attach to our subnet
  network_interface {
    subnetwork    = google_compute_subnetwork.public_subnet.id
    access_config {}   # Enables Public IP
  }

  tags = ["allow-flask"]

  ###############################################
  # Run Docker Container on Startup
  ###############################################
  metadata = {
    "gce-container-declaration" = <<EOF
spec:
  containers:
  - name: flask-app
    image: us-central1-docker.pkg.dev/evident-scion-472000-m7/flask-repo/flask-app:v1
    stdin: false
    tty: false
    ports:
    - containerPort: 5000
  restartPolicy: Always
EOF
  }
}
