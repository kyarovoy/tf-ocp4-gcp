
resource "local_file" "installer_config" {
  content = templatefile("${path.module}/templates/install-config.yaml.tmpl", {
    base_domain = var.domain
    cluster_name = var.cluster_name
    worker_node_type = var.worker_vm_type
    worker_disk_size = var.worker_os_disk_size
    master_node_type = var.master_vm_type
    master_disk_size = var.master_os_disk_size
    cluster_network = var.cluster_network
    machine_network = var.machine_network
    service_network = var.service_network
    gcp_project_id = var.gcp_project_id
    gcp_region = var.gcp_region
    gcp_vpc = var.gcp_vpc
    gcp_master_subnet = var.vpc_master_subnet
    gcp_worker_subnet = var.vpc_worker_subnet
    pull_secret = var.pull_secret
    public_ssh_key =  var.public_ssh_key
  })
  filename = "${path.root}/files/install-config.yaml"
  depends_on = [var.gcp_vpc]
}

resource "null_resource" "installer_files" {
  provisioner "local-exec" {
    command = <<EOT
      wget -qO- https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.openshift_version}/openshift-install-mac-${var.openshift_version}.tar.gz | tar xvz - -C "${path.root}/files"
      wget -qO- https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${var.openshift_version}/openshift-client-mac-${var.openshift_version}.tar.gz | tar xvz - -C "${path.root}/files"
      rm -fr "${path.root}/files/README.md"
    EOT
  }

  provisioner "local-exec" {
    command = "rm -fR oc kubectl openshift-install"
    when = "destroy"
    working_dir = "${path.root}/files"
  }
  depends_on = [var.gcp_vpc]
}

resource "null_resource" "openshift_install_create_cluster" {
  provisioner "local-exec" {
    command = "./openshift-install create cluster --log-level=info"
    environment = {
      GCLOUD_KEYFILE_JSON = var.gcp_service_account
    }
    working_dir = "${path.root}/files"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "./openshift-install destroy cluster --log-level=info"
    environment = {
      GCLOUD_KEYFILE_JSON = var.gcp_service_account
    }
    working_dir = "${path.root}/files"
  }

  depends_on = [null_resource.installer_files,local_file.installer_config,var.gcp_vpc]

}