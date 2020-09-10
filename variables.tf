variable "gcp_project_id" {
  default = ""
}
variable "gcp_region" {
  default = "us-east1"
}

variable "gcp_service_account" {
  default = "files/credentials.json"
}

variable "openshift_version" {
  default = "4.5.0"
}

variable "openshift_cluster_name" {
  default = "ocp4"
}
variable "openshift_base_domain" {
  default = "ocp.local"
}

variable "openshift_pull_secret" {
  default = "pull-secret.txt"
}

# Masters
variable "openshift_master_count" {
  default = "3"
}
variable "openshift_master_instance_flavor" {
  default = "n1-standard-4"
}
variable "openshift_master_os_disk_size" {
  default = "10GB"
}

# Workers
variable "openshift_worker_count" {
  default = "3"
}
variable "openshift_worker_instance_flavor" {
  default = "n1-standard-4"
}
variable "openshift_worker_os_disk_size" {
  default = "10GB"
}

variable "openshift_vpc" {
  default = "ocp"
}

variable "openshift_machine_network" {
  default = "10.0.0.0/16"
}

# IPs for PODs
variable "openshift_cluster_network" {
  default = "10.128.0.0/14"
}

variable "openshift_cluster_network_per_node" {
  default = "23"
}

# IPs for Services (2044)
variable "openshift_service_network" {
  default = "172.30.0.0/16"
}

variable "gcp_vpc_master_subnet" {
  default = "ocp4-master-subnet"
}
variable "gcp_vpc_worker_subnet" {
  default = "ocp4-worker-subnet"
}