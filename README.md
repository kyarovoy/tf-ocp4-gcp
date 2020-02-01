# OpenShift 4.3 on Google Cloud

This [terraform](terraform.io) implementation will deploy OpenShift 4.3 into a GCP VPC, with two subnets for controlplane and worker nodes.  Traffic to the master nodes is handled via a pair of loadbalancers, one for internal traffic and another for external API traffic.  Application loadbalancing is handled by a third loadbalancer that talks to the router pods on the infra or worker nodes.  Worker, Infra and Master nodes are deployed across 3 Availability Zones


# Prerequisites

1.  Install and init Google Cloud SDK

```
brew cask install google-cloud-sdk
gcloud init
```

2.  Generate ssh key

```
ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/openshift4_ssh_key
```

2.  Create bastion/VPN instance

```
gcloud compute addresses create external-bastion-ip --region us-east1
gcloud compute instances create bastion --machine-type=f1-micro --network=default --address external-bastion-ip --maintenance-policy=MIGRATE --no-service-account --no-scopes --tags=bastion --image-family=centos-8 --image-project=centos-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=bastion --can-ip-forward
```

3. Install and configure OpenVPN server

```
EXTERNAL_IP=$(gcloud compute addresses describe external-bastion-ip --region us-east1 | head -n 1 | awk '{ print $2 }')
ssh -i ~/.ssh/openshift4_ssh_key $EXTERNAL_IP
> curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
> chmod +x openvpn-install.sh
> sudo bash
> AUTO_INSTALL=y ./openvpn-install.sh
> DNS_SEARCH=$(cat /etc/resolv.conf | grep search | awk '{ print $2 }')
> echo push \"dhcp-option DOMAIN $DNS_SEARCH\">>/etc/openvpn/server.conf
> echo push \"route 169.254.169.254 255.255.255.255\">>/etc/openvpn/server.conf
> sed -i '/redirect-gateway/d' /etc/openvpn/server.conf
> systemctl restart openvpn-server@server
> iptables -t nat -A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE
> chkconfig iptables on
> service iptables save
gcloud compute firewall-rules create external-vpn-allow --action allow --target-tags bastion --source-ranges 0.0.0.0/0 --rules udp:1194
```

4. Install OpenVPN client and connect to a VPN

```
brew cask install tunnelblick
scp -i ~/.ssh/openshift4_ssh_key $EXTERNAL_IP:client.ovpn .
echo pull>>client.ovpn
open client.ovpn
...
ping bastion
```

5. Create Custom VPC network and subnets for OpenShift and establish peering

```
# Create VPC for OpenShift installation
gcloud compute networks create vpc-ocp --subnet-mode=custom --bgp-routing-mode=regional
gcloud compute networks subnets create ocp4-master-subnet --network=vpc-ocp --range=10.0.0.0/19 --region=us-east1
gcloud compute networks subnets create ocp4-worker-subnet --network=vpc-ocp --range=10.0.32.0/19 --region=us-east1

# Allow VPC external access to the Internet
gcloud compute routers create ocp-router --network=vpc-ocp --advertisement-mode=CUSTOM --region=us-east1 
gcloud compute routers nats create ocp-to-internet --router=ocp-router --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --region=us-east1

# Establish peering between OpenShift VPC and default VPC
gcloud beta compute networks peerings create default-to-vpc-ocp --network=default --peer-network vpc-ocp --import-custom-routes --export-custom-routes
gcloud beta compute networks peerings create vpc-ocp-to-default --network=vpc-ocp --peer-network default --import-custom-routes --export-custom-routes

# Allow connections in vpc-ocp network from default subnet IP address range in us-east1
gcloud compute firewall-rules create allow-default-to-ocp --network vpc-ocp --action allow --source-ranges 10.142.0.0/20
```

6. Download openshift v4 client files

```
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.3.0/openshift-install-mac-4.3.0.tar.gz
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.3.0/openshift-client-mac-4.3.0.tar.gz
tar zxvf openshift-install-mac-4.3.0.tar.gz
tar zxvf openshift-client-mac-4.3.0.tar.gz
```

7. Create DNS

```
gcloud dns managed-zones create ocp-dns --dns-name="ocp.local" --description="OCP Private zone" --visibility=private --networks=ocp-vpc
```

6. Prepare install-config.yaml

```

```

4.  [Enable Service APIs](https://github.com/openshift/installer/blob/master/docs/user/gcp/apis.md)
5.  [Configure DNS](https://github.com/openshift/installer/blob/master/docs/user/gcp/dns.md) 
6.  [Create GCP Service Account](https://github.com/openshift/installer/blob/master/docs/user/gcp/iam.md) with proper IAM roles 


# Minimal TFVARS file

```terraform
gcp_project_id      = "hsbc-261614"
gcp_region          = "us-central1"
cluster_name        = "ocp42"

# From Prereq. Step #2
gcp_public_dns_zone_name = "gcp-ncolon-xyz"
base_domain              = "gcp.ncolon.xyz"

# From Prereq. Step #3
gcp_service_account = "credentials.json"
```



# Customizable Variables

| Variable                              | Description                                                    | Default         | Type   |
| ------------------------------------- | -------------------------------------------------------------- | --------------- | ------ |
| gcp_project_id   | The target GCP project for the cluster. | -               | string |
| gcp_service_account    | Path to JSON file with details for the GCP APIs service account (from Prereq Step #3) | -               | string |
| gcp_region             | he target GCP region for the cluster | -               | string |
| gcp_extra_labels   | Extra GCP labels to be applied to created resources          | {}             | map |
| cluster_name                | Cluster Identifier                                                       | -               | string |
| openshift_master_count                | Number of master nodes to deploy                               | 3               | string |
| openshift_worker_count                | Number of worker nodes to deploy                               | 3               | string |
| openshift_infra_count                 | Number of infra nodes to deploy                                | 0              | string |
| machine_cidr                          | CIDR for OpenShift VNET                                        | 10.0.0.0/16     | string |
| base_domain                           | DNS name for your deployment                                   | -               | string |
| gcp_public_dns_zone_name | The name of the public DNS zone to use for this cluster (from Prereq Step #2) | -               | string |
| gcp_bootstrap_instance_type | Size of bootstrap VM                                           | n1-standard-4 | string |
| gcp_master_instance_type | Size of master node VMs                                        | n1-standard-4 | string |
| gcp_infra_instance_type | Size of infra node VMs                                         | n1-standard-4 | string |
| gcp_worker_instance_type | Sizs of worker node VMs                                        | n1-standard-4 | string |
| openshift_cluster_network_cidr        | CIDR for Kubernetes pods                                       | 10.128.0.0/14   | string |
| openshift_cluster_network_host_prefix | Detemines the number of pods a node can host.  23 gives you 510 pods per node. | 23 | string |
| openshift_service_network_cidr        | CIDR for Kubernetes services                                   | 172.30.0.0/16   | string |
| openshift_pull_secret                 | path to filename that holds your OpenShift [pull-secret](https://cloud.redhat.com/openshift/install/azure/installer-provisioned) | - | string |
| gcp_master_os_disk_size | Size of master node root volume                                | 1024            | string |
| gcp_worker_os_disk_size | Size of worker node root volume                                | 128             | string |
| gcp_infra_os_disk_size | Size of infra node root volume                                 | 128             | string |
| gcp_image_uri          | URL of the CoreOS image. Can be found [here](https://github.com/openshift/installer/blob/master/data/data/rhcos.json) | [URL](https://storage.googleapis.com/rhcos/rhcos/42.80.20191002.0.tar.gz) | string |
| openshift_version                     | Version of OpenShift to deploy.                                | latest          | strig |
|gcp_bootstrap_enabled|Setting this to false allows the bootstrap resources to be disabled|true|bool|
|gcp_bootstrap_lb|Setting this to false allows the bootstrap resources to be removed from the cluster load balancers|true|bool|
| airgapped                             | Configuration for an AirGapped environment                     | [AirGapped](airgapped.md) default is `false`| map |


# Deploy with Terraform

1. Clone github repository
```bash
git clone https://github.com/ibm-cloud-architecture/terraform-openshift4-gcp.git
```

2. Create your `terraform.tfvars` file

3. Deploy with terraform
```bash
$ terraform init
$ terraform plan
$ terraform apply
```
4.  Destroy bootstrap node
```bash
$ TF_VAR_gcp_bootstrap_enabled=false terraform apply
```
5.  To access your cluster
```bash
 $ export KUBECONFIG=$PWD/installer-files/auth/kubeconfig
 $ oc get nodes
NAME                                                         STATUS   ROLES          AGE   VERSION
ocp42-a26ek-master-0.us-central1-a.c.hsbc-261614.internal    Ready    master         95m   v1.14.6+31a56cf75
ocp42-a26ek-master-1.us-central1-b.c.hsbc-261614.internal    Ready    master         95m   v1.14.6+31a56cf75
ocp42-a26ek-master-2.us-central1-c.c.hsbc-261614.internal    Ready    master         95m   v1.14.6+31a56cf75
ocp42-a26ek-w-a-xrgvb.us-central1-a.c.hsbc-261614.internal   Ready    worker         91m   v1.14.6+31a56cf75
ocp42-a26ek-w-b-h72ss.us-central1-b.c.hsbc-261614.internal   Ready    worker         90m   v1.14.6+31a56cf75
ocp42-a26ek-w-c-4x64c.us-central1-c.c.hsbc-261614.internal   Ready    worker         90m   v1.14.6+31a56cf75
```



# Infra and Worker Node Deployment

Deployment of Openshift Worker and Infra nodes is handled by the machine-operator-api cluster operator.

```bash
$ oc get machineset -n openshift-machine-api
NAME              DESIRED   CURRENT   READY   AVAILABLE   AGE
ocp42-a26ek-w-a   1         1         1       1           91m
ocp42-a26ek-w-b   1         1         1       1           91m
ocp42-a26ek-w-c   1         1         1       1           91m

$ oc get machines -n openshift-machine-api
NAME                    STATE     TYPE            REGION        ZONE            AGE
ocp42-a26ek-w-a-xrgvb   RUNNING   n1-standard-4   us-central1   us-central1-a   91m
ocp42-a26ek-w-b-h72ss   RUNNING   n1-standard-4   us-central1   us-central1-b   91m
ocp42-a26ek-w-c-4x64c   RUNNING   n1-standard-4   us-central1   us-central1-c   91m
```

If `openshift_infra_count > 0` the infra nodes will host the router/ingress pods, all the monitoring infrastrucutre, and the image registry.
