output "vpn_address" {
  value = google_compute_address.external-bastion-ip.address
  depends_on = [
    google_compute_address.external-bastion-ip,
    google_compute_instance.bastion,
    google_compute_firewall.external-bastion-ssh-allow,
    google_compute_firewall.external-vpn-allow
  ]
}