variable "openshift_version" {
  default = "4.5.0"
}

variable "gcp_region" {
  default = ""
}

variable "gcp_project_id" {
  default = ""
}

variable "public_ssh_key" {
  default = ""
}

variable "pull_secret" {
  default = ""
}

variable "master_vm_type" {
  default = ""
}

variable "master_os_disk_size" {
  default = "50"
}

variable "master_count" {
  default = "3"
}

variable "worker_vm_type" {
  default = ""
}

variable "worker_os_disk_size" {
  default = "50"
}

variable "worker_count" {
  default = "3"
}

variable "cluster_name" {
  default = ""
}
variable "domain" {
  default = ""
}

variable "cluster_network" {
  default = "10.128.0.0/14"
}
variable "machine_network" {
  default = "10.0.0.0/16"
}
variable "service_network" {
  default = "172.30.0.0/16"
}

variable "gcp_vpc" {
  default = ""
}

variable "vpc_master_subnet" {
  default = ""
}

variable "vpc_worker_subnet" {
  default = ""
}

variable "gcp_service_account" {
  default = "files/credentials.json"
}