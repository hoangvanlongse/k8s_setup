#!/bin/bash
# ============================
# Kubernetes Master Setup Script (Ubuntu 24.04)
# Distributed System Lab 1 (Fixed Version)
# ============================

set -e

# --- CONFIG SECTION ---
MASTER_NAME="master"
MASTER_IP="192.168.1.10"
WORKER_NAME="worker"
WORKER_IP="192.168.1.11"
# ----------------------

echo "[1/10] Update system"
sudo apt update -y && sudo apt upgrade -y

echo "[2/10] Disable swap & firewall"
sudo swapoff -a
sudo sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo ufw disable
sudo systemctl disable ufw.service

echo "[3/10] Disable SELinux (if any)"
if [ -f /etc/selinux/config ]; then
  sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config || true
fi

echo "[4/10] Set hostname and hosts mapping"
sudo hostnamectl set-hostname $MASTER_NAME
sudo bash -c "cat >> /etc/hosts" <<EOF
$MASTER_IP $MASTER_NAME
$WORKER_IP $WORKER_NAME
EOF

echo "[5/10] Configure kernel modules and sysctl"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

echo "[6/10] Add Docker & Kubernetes repositories (fixed syntax)"
# Clean up old files
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/sources.list.d/kubernetes.list

# Docker repo
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Kubernetes repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# Update package list
sudo apt update -y

echo "[7/10] Install Containerd and Kubernetes packages"
sudo apt install -y containerd.io kubelet kubeadm kubectl
sudo systemctl enable containerd
sudo systemctl enable kubelet

echo "[8/10] Configure Containerd"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
# dùng dấu # thay cho / trong sed để tránh lỗi
sudo sed -i 's#sandbox_image = .*#sandbox_image = "registry.k8s.io/pause:3.10.1"#' /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd


echo "[9/10] Initialize Kubernetes master"
sudo kubeadm init --control-plane-endpoint=$MASTER_NAME --pod-network-cidr=192.168.0.0/16

echo "[10/10] Setup kubeconfig & Calico"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.3/manifests/calico.yaml

echo "✅ Master setup completed!"
echo "👉 Run 'kubeadm token create --print-join-command' to get the join command for workers."
