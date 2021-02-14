#!/bin/bash

# $1 can be either master or node
ENV=$1
if [ "$ENV" == "master" -o "$ENV" == "node" ] ; then
    true 
else echo "ERROR : $1 should be master or node"
fi

#Disable swap, swapoff then edit your fstab removing any entry for swap partitions
#You can recover the space with fdisk. You may want to reboot to ensure your config is ok.
swapoff -a

sudo yum install -y yum-utils device-mapper-persistent-data lvm2

sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

sudo yum install -y docker-ce-19.03.13 docker-ce-cli-19.03.13 containerd.io

sudo mkdir /etc/docker

sudo bash -c 'cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF'

sudo mkdir -p /etc/systemd/system/docker.service.d

sudo systemctl enable --now docker

echo "INFO: Docker status:"
systemctl is-active docker

echo "INFO: Docker is-enabled:"
systemctl is-enabled docker

sudo systemctl daemon-reload

echo "INFO: Docker is starting..."
sudo systemctl restart docker

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

sudo setenforce 0

sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

sudo yum install -y kubelet-1.19.7 kubeadm-1.19.7 kubectl-1.19.7 --disableexcludes=kubernetes

sudo systemctl enable --now kubelet

sudo systemctl stop firewalld

sudo systemctl disable firewalld 

sudo yum install -y iproute-tc

if [ "$ENV" == "master" ] ; then

    sudo yum install -y wget

    wget https://docs.projectcalico.org/manifests/calico.yaml

    sudo sed -i 's/# - name: CALICO_IPV4POOL_CIDR$/- name: CALICO_IPV4POOL_CIDR/' calico.yaml
    sudo sed -i 's/#   value: "192.168.0.0\/16"/  value: "192.168.0.0\/16"/' calico.yaml

    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version 1.19.7

    mkdir -p $HOME/.kube

    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    kubectl apply -f calico.yaml
fi

exit