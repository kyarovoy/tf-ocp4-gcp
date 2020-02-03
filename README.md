# OpenShift 4.3 on Google Cloud

This guide show how to prepare GCP infrastructure and deploy private OpenShift 4.3 cluster into a GCP VPC, with two subnets for controlplane and worker nodes.  Traffic to the 3 x master nodes is handled via a pair of loadbalancers, one for internal traffic and another for external API traffic.  Application loadbalancing is handled by a third loadbalancer that talks to the router pods on the 3 x infra/worker nodes.  Worker, Infra and Master nodes are deployed across 3 Availability Zones.

As a part of this deployment we are configuring Bastion host with OpenVPN to access private OpenShift cluster resources.

# Prerequisites

1.  Install and init Google Cloud SDK with Owner account

```
brew cask install google-cloud-sdk
gcloud init
```

2. Enable Service APIs

```
for service in compute cloudapis cloudresourcemanager dns iam iamcredentials servicemanagement serviceusage storage-api storage-component do gcloud services enable $service; done
```

3. Create GCP Service Account for OpenShift provisioning

```
PROJECT=prototypesandacceleration
gcloud iam service-accounts create ocp-provisioner --description "OCP Provisioner" --display-name "OCP Provisioner"
for role in "compute.admin dns.admin iam.securityAdmin iam.serviceAccountAdmin iam.serviceAccountUser storage.admin iam.serviceAccountKeyAdmin" do
  gcloud projects add-iam-policy-binding $PROJECT \
  --member serviceAccount:ocp-provisioner@$PROJECT.iam.gserviceaccount.com --role roles/comput
done
  
```
4. Download pull secret for [cloud.rehat.com](https://cloud.redhat.com/openshift/install/gcp/installer-provisioned)

5.  Generate ssh key and add it to your ssh agent

```
ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/openshift4_ssh_key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/openshift4_ssh_key
```

6.  Create bastion/VPN instance

```
gcloud compute addresses create external-bastion-ip --region us-east1
gcloud compute instances create bastion --machine-type=f1-micro --network=default --address external-bastion-ip --maintenance-policy=MIGRATE --no-service-account --no-scopes --tags=bastion --image-family=centos-8 --image-project=centos-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=bastion --can-ip-forward
```

7. Install and configure OpenVPN server

```
EXTERNAL_IP=$(gcloud compute addresses describe external-bastion-ip --region us-east1 | head -n 1 | awk '{ print $2 }')
ssh $EXTERNAL_IP
> curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
> chmod +x openvpn-install.sh
> sudo bash
> AUTO_INSTALL=y ./openvpn-install.sh
> DNS_SEARCH=$(cat /etc/resolv.conf | grep search | awk '{ print $2 }')
> echo push \"dhcp-option DOMAIN $DNS_SEARCH\">>/etc/openvpn/server.conf
> echo push \"route 169.254.169.254 255.255.255.255\">>/etc/openvpn/server.conf
> echo push \"route 10.142.0.0 255.255.254.0\">>/etc/openvpn/server.conf
> echo push \"route 10.0.0.0 255.255.224.0\">>/etc/openvpn/server.conf
> echo push \"route 10.0.32.0 255.255.224.0\">>/etc/openvpn/server.conf
> sed -i '/redirect-gateway/d' /etc/openvpn/server.conf
> systemctl restart openvpn-server@server
> iptables -t nat -A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE
> chkconfig iptables on
> service iptables save
gcloud compute firewall-rules create external-vpn-allow --action allow --target-tags bastion --source-ranges 0.0.0.0/0 --rules udp:1194
```

8. Install OpenVPN client and connect to a VPN

```
brew cask install tunnelblick
scp -i $EXTERNAL_IP:client.ovpn .
echo pull>>client.ovpn
open client.ovpn
...
ping bastion
```

9. Create Custom VPC network and subnets for OpenShift with Internet access, establish peering with default network

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

10. Download openshift v4 client files

```
# wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.3.0/openshift-install-mac-4.3.0.tar.gz
# wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.3.0/openshift-client-mac-4.3.0.tar.gz
# tar zxvf openshift-install-mac-4.3.0.tar.gz
# tar zxvf openshift-client-mac-4.3.0.tar.gz
```

11. Prepare install-config.yaml

```
apiVersion: v1
baseDomain: ocp.local
compute:
- hyperthreading: Enabled
  name: worker
  platform:
    gcp:
      rootVolume:
        iops: 4000
        size: 500
        type: io1
      type: n1-standard-4
  replicas: 3
controlPlane:
  hyperthreading: Enabled
  name: master
  platform:
    gcp:
      rootVolume:
        iops: 4000
        size: 500
        type: io1
      type: n1-standard-4
  replicas: 3
metadata:
  creationTimestamp: null
  name: ocp4
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineCIDR: 10.0.0.0/16
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  gcp:
    projectID: prototypesandacceleration
    region: us-east1
    network: vpc-ocp
    controlPlaneSubnet: ocp4-master-subnet
    computeSubnet: ocp4-worker-subnet
publish: Internal
pullSecret: '<your pull secret>'
sshKey: <your ssh key>
```

12. Deploy cluster

```
# ./openshift-install create cluster --dir=. --log-level=info
INFO Consuming Install Config from target directory
INFO Creating infrastructure resources...
INFO Waiting up to 30m0s for the Kubernetes API at https://api.ocp4.ocp.local:6443...
INFO API v1.16.2 up
INFO Waiting up to 30m0s for bootstrapping to complete...
INFO Destroying the bootstrap resources...
INFO Waiting up to 30m0s for the cluster at https://api.ocp4.ocp.local:6443 to initialize...
INFO Waiting up to 10m0s for the openshift-console route to be created...
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/Users/kiarov/ocp/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.ocp4.ocp.local
INFO Login to the console with user: kubeadmin, password: <pass>
```

13. Ensure all nodes are ready

```
# export KUBECONFIG=/Users/kiarov/ocp/auth/kubeconfig
# oc get nodes
NAME                                                        STATUS    ROLES     AGE       VERSION
ocp4-scbkq-m-0.c.prototypesandacceleration.internal         Ready     master    19m       v1.16.2
ocp4-scbkq-m-1.c.prototypesandacceleration.internal         Ready     master    19m       v1.16.2
ocp4-scbkq-m-2.c.prototypesandacceleration.internal         Ready     master    19m       v1.16.2
ocp4-scbkq-w-b-x6ssx.c.prototypesandacceleration.internal   Ready     worker    10m       v1.16.2
ocp4-scbkq-w-c-74tsl.c.prototypesandacceleration.internal   Ready     worker    10m       v1.16.2
ocp4-scbkq-w-d-j8wwv.c.prototypesandacceleration.internal   Ready     worker    10m       v1.16.2
```

14. Log in to the cluster console at [https://console-openshift-console.apps.ocp4.ocp.local](https://console-openshift-console.apps.ocp4.ocp.local)
