
provider "google" {
  credentials = file(var.gcp_service_account)
  project = var.gcp_project_id
  region  = var.gcp_region
}

resource "tls_private_key" "sshkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "sshkey_private" {
  content         = tls_private_key.sshkey.private_key_pem
  filename        = "${path.root}/files/openshift_rsa"
  file_permission = 0600
}

resource "local_file" "write_public_key" {
  content         = tls_private_key.sshkey.public_key_openssh
  filename        = "${path.root}/files/openshift_rsa.pub"
  file_permission = 0600
}

resource "google_compute_project_metadata_item" "ssh-keys" {
  key   = "ssh-keys"
  value  = "centos:${tls_private_key.sshkey.public_key_openssh}"
}

module "network" {
  source = "./network"
  vpc = var.openshift_vpc
  machine_network = var.openshift_machine_network
}

module "bastion" {
  source  = "./bastion"
  ssh_key = local_file.sshkey_private.filename
  routes  = [var.openshift_machine_network, var.openshift_cluster_network, var.openshift_service_network]
  vpc = module.network.vpc
}

module "openshift4" {
  source                = "./openshift4"

  gcp_vpc                = module.network.vpc
  gcp_region             = var.gcp_region
  gcp_project_id         = var.gcp_project_id
  gcp_service_account    = var.gcp_service_account
  openshift_version      = var.openshift_version
  master_count           = var.openshift_master_count
  worker_count           = var.openshift_worker_count
  domain                 = var.openshift_base_domain
  cluster_name           = var.openshift_cluster_name
  pull_secret            = chomp(file("${path.root}/${var.openshift_pull_secret}"))
  public_ssh_key         = chomp(tls_private_key.sshkey.public_key_openssh)
  master_vm_type         = var.openshift_master_instance_flavor
  worker_vm_type         = var.openshift_worker_instance_flavor
  master_os_disk_size    = var.openshift_master_os_disk_size
  worker_os_disk_size    = var.openshift_worker_os_disk_size
  vpc_master_subnet      = var.gcp_vpc_master_subnet
  vpc_worker_subnet      = var.gcp_vpc_worker_subnet

}

