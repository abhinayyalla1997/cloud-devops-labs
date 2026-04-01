#!/bin/bash
# =============================================================================
# Kubernetes Worker Bootstrap
# Runs on: Worker nodes
# Polls SSM for the join command written by the master.
# Works for initial workers AND workers added later (just increase worker_count).
# Log: /var/log/k8s-worker-setup.log
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/k8s-worker-setup.log | logger -t k8s-worker) 2>&1

echo "============================================================"
echo " Kubernetes Worker Bootstrap — $(date)"
echo " Cluster: ${cluster_name}"
echo " Version: ${k8s_version}"
echo "============================================================"

# ─── STEP 1: Kernel modules & sysctl ─────────────────────────────────────────
echo "[1/7] Configuring kernel modules..."

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
echo "[2/7] Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# ─── STEP 3: Install containerd ──────────────────────────────────────────────
echo "[3/7] Installing containerd..."
apt-get update -y
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Enable SystemdCgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
echo "containerd: $(containerd --version)"

# ─── STEP 4: Install kubeadm, kubelet, kubectl ───────────────────────────────
echo "[4/7] Installing Kubernetes ${k8s_version} components..."
apt-get install -y apt-transport-https ca-certificates curl gnupg awscli

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${k8s_version}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${k8s_version}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl

apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet
echo "kubeadm: $(kubeadm version --output=short)"

# ─── STEP 5: Poll SSM for join command ───────────────────────────────────────
# The master writes the join command to SSM after kubeadm init.
# Workers wait here until it's available — this makes scaling seamless:
# new workers added later will automatically pick up the existing join command.
echo "[5/7] Waiting for join command in SSM (/${cluster_name}/join-command)..."

MAX_RETRIES=40   # 40 x 30s = 20 minutes max wait
RETRY=0
JOIN_COMMAND=""

while [ $RETRY -lt $MAX_RETRIES ]; do
  VALUE=$(aws ssm get-parameter \
    --name "/${cluster_name}/join-command" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text \
    --region "${aws_region}" 2>/dev/null || true)

  # Check that we got a real join command (not the Terraform placeholder)
  if [[ -n "$VALUE" && "$VALUE" != "placeholder" && "$VALUE" == *"kubeadm join"* ]]; then
    JOIN_COMMAND="$VALUE"
    echo "Got join command from SSM."
    break
  fi

  RETRY=$((RETRY + 1))
  echo "  Attempt $RETRY/$MAX_RETRIES — not ready yet, retrying in 30s..."
  sleep 30
done

if [[ -z "$JOIN_COMMAND" ]]; then
  echo "ERROR: Timed out waiting for join command. Check master setup log."
  exit 1
fi

# ─── STEP 6: Join the cluster ────────────────────────────────────────────────
echo "[6/7] Joining the Kubernetes cluster..."
eval "$JOIN_COMMAND"

# ─── STEP 7: Done ────────────────────────────────────────────────────────────
echo "[7/7] Worker joined successfully — $(date)"
echo ""
echo "From master, verify with: kubectl get nodes -o wide"
echo "============================================================"
echo " Worker Bootstrap COMPLETE"
echo "============================================================"
