#!/bin/bash
# ============================
# Kubernetes Worker Setup Script (Ubuntu 24.04)
# Distributed System Lab 1
# ============================

set -e

# --- CONFIG SECTION ---
MASTER_NAME="master"
MASTER_IP="192.168.1.10"
WORKER_NAME="worker"
WORKER_IP="192.168.1.11"
# ----------------------

echo "[1/8] Update system"
sudo apt update -y && sudo apt upgrade -y

echo "[2/8] Disable swap & firewall"
sudo swapoff -a
sudo sed -i.bak '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo ufw disable
sudo systemctl disable ufw.service

echo "[3/8] Disable SELinux (if any)"
if [ -f /etc/selinux/config ]; then
  sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config || true
fi

echo "[4/8] Set hostname and hosts mapping"
sudo hostnamectl set-hostname $WORKER_NAME
sudo bash -c "cat >> /etc/hosts" <<EOF
$MASTER_IP $MASTER_NAME
$WORKER_IP $WORKER_NAME
EOF

echo "[5/8] Configure kernel modules and sysctl"
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

echo "[6/8] Install Containerd and Kubernetes"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update -y
sudo apt install -y containerd.io kubelet kubeadm kubectl
sudo systemctl enable containerd
sudo systemctl enable kubelet

echo "[7/8] Configure Containerd"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/sandbox_image = .*/sandbox_image = "registry.k8s.io\\/pause:3.10.1"/' /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

echo "[8/8] Reboot the system, then join this worker using the command from master:"
echo "👉 Example: sudo kubeadm join $MASTER_IP:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
echo "✅ Worker setup completed!"
