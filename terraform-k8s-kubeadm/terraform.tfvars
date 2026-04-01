# Copy this file to terraform.tfvars and fill in your values.
# cp terraform.tfvars.example terraform.tfvars

# ─── Required ────────────────────────────────────────────────────────────────

aws_region = "us-east-1"
vpc_id     = "vpc-9bdedae1"
subnet_id  = "subnet-24897f05"
key_name   = "o2bkids"

# ─── Scaling: change worker_count and run terraform apply to add nodes ────────

worker_count = 2   # → set to 3, 4, 5... to add more workers

# ─── Optional overrides ──────────────────────────────────────────────────────

cluster_name         = "k8s-kubeadm"
environment          = "dev"
master_instance_type = "t3.medium"
worker_instance_type = "t3.medium"
master_volume_size   = 20
worker_volume_size   = 20
k8s_version          = "v1.34"
calico_version       = "v3.27.2"
pod_network_cidr     = "192.168.0.0/16"

# Restrict SSH + API access to your IP (recommended for production)
allowed_ssh_cidrs = ["0.0.0.0/0"]

# Set to false if using a private subnet with a NAT gateway
associate_public_ip = true

# Leave empty to auto-select latest Ubuntu 22.04 LTS AMI
ami_id = ""
