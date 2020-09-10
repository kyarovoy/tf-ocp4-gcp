variable "routes" {
  type = list(string)
  description = "The list of routes pushed to OpenVPN clients"
}

variable "instance_flavor" {
  default = "g1-small"
}

variable "instance_zone" {
  default = "us-east1-b"
}

variable "vpc" {
  default = ""
}

variable "instance_disk_size" {
  default = "10"
}

variable "ssh_key" {
  default = ""
}