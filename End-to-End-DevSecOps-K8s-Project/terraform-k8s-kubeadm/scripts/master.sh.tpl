#!/bin/bash
# =============================================================================
# Kubernetes Control-Plane Bootstrap
# Runs on: Master node only
# Based on: 01-kubeadm-cluster-setup (kubeadm v${k8s_version})
# Log: /var/log/k8s-master-setup.log
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/k8s-master-setup.log | logger -t k8s-master) 2>&1

echo "============================================================"
echo " Kubernetes Master Bootstrap — $(date)"
echo " Cluster: ${cluster_name}"
echo " Version: ${k8s_version}"
echo "============================================================"

# ─── STEP 1: Kernel modules & sysctl ─────────────────────────────────────────
echo "[1/9] Configuring kernel modules..."

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# ─── STEP 2: Disable swap ────────────────────────────────────────────────────
echo "[2/9] Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# ─── STEP 3: Install containerd ──────────────────────────────────────────────
echo "[3/9] Installing containerd..."
apt-get update -y
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Enable SystemdCgroup (required for kubelet + containerd cgroup alignment)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
echo "containerd: $(containerd --version)"

# ─── STEP 4: Install kubeadm, kubelet, kubectl ───────────────────────────────
echo "[4/9] Installing Kubernetes ${k8s_version} components..."
apt-get install -y apt-transport-https ca-certificates curl gnupg awscli

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${k8s_version}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${k8s_version}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl

# Hold packages to prevent accidental upgrades (production best practice)
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet
echo "kubeadm: $(kubeadm version --output=short)"

# ─── STEP 5: Fetch private IP from instance metadata ─────────────────────────
echo "[5/9] Fetching instance private IP..."
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Private IP: $PRIVATE_IP"

# ─── STEP 6: Initialize the cluster ──────────────────────────────────────────
echo "[6/9] Running kubeadm init..."
kubeadm init \
  --apiserver-advertise-address="$PRIVATE_IP" \
  --pod-network-cidr="${pod_network_cidr}" \
  --cri-socket=unix:///run/containerd/containerd.sock

# ─── STEP 7: Configure kubectl ───────────────────────────────────────────────
echo "[7/9] Configuring kubectl for ubuntu user..."
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Also set for root (used in remaining steps below)
export KUBECONFIG=/etc/kubernetes/admin.conf

# Wait for API server to accept connections
echo "Waiting for API server to become ready..."
until kubectl get nodes &>/dev/null; do
  echo "  API server not ready yet, retrying in 5s..."
  sleep 5
done
echo "API server is ready."

# ─── STEP 8: Install Calico CNI ──────────────────────────────────────────────
echo "[8/9] Installing Calico CNI ${calico_version}..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/calico.yaml

# Wait for Calico pods to come up
echo "Waiting for Calico pods to be running..."
sleep 30
kubectl wait --namespace=kube-system \
  --for=condition=Ready pods \
  --selector=k8s-app=calico-node \
  --timeout=180s || true

echo "Cluster nodes status:"
kubectl get nodes -o wide

# ─── STEP 9: Generate join command and publish to SSM ────────────────────────
echo "[9/9] Generating join command and storing in SSM..."
JOIN_COMMAND=$(kubeadm token create --print-join-command)

aws ssm put-parameter \
  --name "/${cluster_name}/join-command" \
  --value "$JOIN_COMMAND" \
  --type "SecureString" \
  --overwrite \
  --region "${aws_region}"

echo "Join command stored at SSM: /${cluster_name}/join-command"
echo ""
echo "============================================================"
echo " Master setup COMPLETE — $(date)"
echo " Run: kubectl get nodes"
echo "============================================================"
