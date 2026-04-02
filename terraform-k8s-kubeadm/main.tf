terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ── Remote State: S3 Backend ──────────────────────────────────────────────
  # State file is stored in S3 so every pipeline run (apply / destroy)
  # reads and writes the same state — no local state, no artifacts.
  #
  # `region` is intentionally omitted here; it is passed at runtime via:
  #   terraform init -backend-config="region=<AWS_REGION>"
  #
  # Production recommendation: add a DynamoDB table for state locking:
  #   dynamodb_table = "terraform-state-lock"
  backend "s3" {
    bucket  = "cicd-test-13102022"
    key     = "terraform-k8s-kubeadm/terraform.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────────────────────────────────────
# Auto-select latest Ubuntu 22.04 LTS if no AMI is specified
# ─────────────────────────────────────────────────────────────────────────────

data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu_22_04.id

  common_tags = {
    Cluster     = var.cluster_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# SSM Parameter — Terraform creates it with a placeholder value.
# The master user_data overwrites it with the real kubeadm join command.
# Workers poll this parameter until they get the real value, then join.
# Adding more workers later (by increasing worker_count) works automatically
# because the join command is already stored in SSM.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_ssm_parameter" "join_command" {
  name        = "/${var.cluster_name}/join-command"
  type        = "SecureString"
  value       = "placeholder"
  description = "Kubeadm join command written by master at init time"

  lifecycle {
    # Terraform must not overwrite the real join command written by master
    ignore_changes = [value]
  }

  tags = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# MASTER / CONTROL-PLANE NODE
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_instance" "master" {
  ami                         = local.ami_id
  instance_type               = var.master_instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.master.id]
  iam_instance_profile        = aws_iam_instance_profile.master.name
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.master_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    tags                  = merge(local.common_tags, { Name = "${var.cluster_name}-master-root" })
  }

  user_data = templatefile("${path.module}/scripts/master.sh.tpl", {
    cluster_name     = var.cluster_name
    k8s_version      = var.k8s_version
    pod_network_cidr = var.pod_network_cidr
    calico_version   = var.calico_version
    aws_region       = var.aws_region
  })

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-master"
    Role = "master"
  })

  # SSM parameter must exist before master tries to write to it
  depends_on = [aws_ssm_parameter.join_command]
}

# ─────────────────────────────────────────────────────────────────────────────
# WORKER NODES
#
# Dynamic scaling: change worker_count and run `terraform apply`.
# New nodes bootstrap themselves, poll SSM for the join command,
# and join the cluster automatically — no manual intervention needed.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_instance" "workers" {
  count = var.worker_count

  ami                         = local.ami_id
  instance_type               = var.worker_instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.worker.id]
  iam_instance_profile        = aws_iam_instance_profile.worker.name
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.worker_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    tags                  = merge(local.common_tags, { Name = "${var.cluster_name}-worker-${count.index + 1}-root" })
  }

  user_data = templatefile("${path.module}/scripts/worker.sh.tpl", {
    cluster_name = var.cluster_name
    k8s_version  = var.k8s_version
    aws_region   = var.aws_region
  })

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
  })

  # Workers start after master so the SSM param is being populated;
  # they poll SSM internally until the real join command appears.
  depends_on = [aws_instance.master]
}
