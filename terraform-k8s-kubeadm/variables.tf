# ─────────────────────────────────────────────────────────────────────────────
# GENERAL
# ─────────────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy the cluster"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "k8s-kubeadm"
}

variable "environment" {
  description = "Environment tag (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ─────────────────────────────────────────────────────────────────────────────
# NETWORKING
# ─────────────────────────────────────────────────────────────────────────────

variable "vpc_id" {
  description = "VPC ID where the cluster nodes will be launched"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for all cluster nodes (all nodes must be in the same subnet)"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into nodes and reach the API server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "associate_public_ip" {
  description = "Assign public IPs to instances (required if subnet has no NAT gateway)"
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# EC2
# ─────────────────────────────────────────────────────────────────────────────

variable "key_name" {
  description = "Name of an existing EC2 Key Pair for SSH access"
  type        = string
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID. Leave empty to auto-select the latest."
  type        = string
  default     = ""
}

variable "master_instance_type" {
  description = "Instance type for the control-plane node (minimum: t3.medium = 2vCPU/4GB)"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

# ─── DYNAMIC WORKER SCALING ──────────────────────────────────────────────────
variable "worker_count" {
  description = <<-EOT
    Number of worker nodes to provision.
    Increase this value and run `terraform apply` to add more workers.
    New workers automatically fetch the join command from SSM and join the cluster.
  EOT
  type        = number
  default     = 2
}

variable "master_volume_size" {
  description = "Root EBS volume size in GB for the master node"
  type        = number
  default     = 20
}

variable "worker_volume_size" {
  description = "Root EBS volume size in GB for worker nodes"
  type        = number
  default     = 20
}

# ─────────────────────────────────────────────────────────────────────────────
# KUBERNETES
# ─────────────────────────────────────────────────────────────────────────────

variable "k8s_version" {
  description = "Kubernetes version for the apt repository (e.g. v1.34)"
  type        = string
  default     = "v1.34"
}

variable "calico_version" {
  description = "Calico CNI version to install"
  type        = string
  default     = "v3.27.2"
}

variable "pod_network_cidr" {
  description = "Pod network CIDR — must match Calico's default (192.168.0.0/16)"
  type        = string
  default     = "192.168.0.0/16"
}
