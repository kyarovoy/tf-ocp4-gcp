# Create OCP VPC
resource "google_compute_network" "gcp_vpc" {
  name = var.vpc
  auto_create_subnetworks = "false"
  routing_mode = "REGIONAL"
}

# Create Management subnet
resource "google_compute_subnetwork" "ocp4_management_subnet" {
  name = "management"
  network = google_compute_network.gcp_vpc.self_link
  ip_cidr_range = cidrsubnet(var.machine_network, 3, 0)
}

# Create OCP VPC subnets
resource "google_compute_subnetwork" "ocp4_master_subnet" {
  name = var.vpc_master_subnet_name
  network = google_compute_network.gcp_vpc.self_link
  ip_cidr_range = cidrsubnet(var.machine_network, 3, 1)
}

resource "google_compute_subnetwork" "ocp4_worker_subnet" {
  name = var.vpc_worker_subnet_name
  network = google_compute_network.gcp_vpc.self_link
  ip_cidr_range = cidrsubnet(var.machine_network, 3, 2)
}

# Allow OCP VPC access the Internet
resource "google_compute_router" "ocp-router" {
  name    = "ocp-router"
  network = google_compute_network.gcp_vpc.name
  bgp {
    asn = 64514
    advertise_mode = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_router_nat" "ocp-to-internet" {
  name                               = "ocp-to-internet"
  router                             = google_compute_router.ocp-router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}