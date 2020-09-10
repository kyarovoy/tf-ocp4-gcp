variable "vpc" {
  default = ""
}

variable "machine_network" {
  default = "10.0.0.0/16"
}

variable "vpc_master_subnet_name" {
  default = "ocp4-master-subnet"
}
variable "vpc_worker_subnet_name" {
  default = "ocp4-worker-subnet"
}