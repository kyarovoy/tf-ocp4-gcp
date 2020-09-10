resource "google_compute_address" "external-bastion-ip" {
  name = "external-bastion-ip"
}

resource "google_compute_instance" "bastion" {
  name = "bastion"
  machine_type = var.instance_flavor
  zone = var.instance_zone
  can_ip_forward = true

  tags = ["bastion", "vpn"]

  boot_disk {
    device_name = "bastion"
    initialize_params {
      image = "centos-cloud/centos-8"
      size  = var.instance_disk_size
      type = "pd-standard"
    }
  }

  network_interface {
    network = var.vpc
    subnetwork = "management"
    access_config {
      nat_ip = google_compute_address.external-bastion-ip.address
    }
  }

  provisioner "remote-exec" {
    connection {
      user = "centos"
      private_key = file(var.ssh_key)
      host = self.network_interface.0.access_config.0.nat_ip
    }
    inline = ["# Connected!", templatefile("${path.module}/templates/bastion_startup_script.tmpl", { routes = var.routes })]
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_key} centos@${self.network_interface.0.access_config.0.nat_ip}:~/client.ovpn ${path.root}/files/"
  }

  provisioner "local-exec" {
    command = "rm -fr ${path.root}/files/client.ovpn"
    when = "destroy"
  }
}

resource "google_compute_firewall" "external-vpn-allow" {
  name = "external-vpn-alllow"
  network = var.vpc

  allow {
    protocol = "udp"
    ports = ["1194"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["bastion"]

}

resource "google_compute_firewall" "external-bastion-ssh-allow" {
  name = "external-bastion-ssh-alllow"
  network = var.vpc

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["bastion"]

}

