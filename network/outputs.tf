output "vpc" {
  value = google_compute_network.gcp_vpc.name
  depends_on = [
    google_compute_network.gcp_vpc,
    google_compute_subnetwork.ocp4_management_subnet,
    google_compute_subnetwork.ocp4_master_subnet,
    google_compute_subnetwork.ocp4_worker_subnet,
    google_compute_router.ocp-router,
    google_compute_router_nat.ocp-to-internet
  ]
}