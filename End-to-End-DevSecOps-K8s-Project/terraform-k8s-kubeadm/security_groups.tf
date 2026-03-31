# ─────────────────────────────────────────────────────────────────────────────
# MASTER SECURITY GROUP
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "master" {
  name        = "${var.cluster_name}-master-sg"
  description = "Kubernetes control-plane node"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-master-sg" })
}

# ─────────────────────────────────────────────────────────────────────────────
# WORKER SECURITY GROUP
# (defined before rules so both SGs exist before cross-references are added)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "worker" {
  name        = "${var.cluster_name}-worker-sg"
  description = "Kubernetes worker nodes"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.cluster_name}-worker-sg" })
}

# ─────────────────────────────────────────────────────────────────────────────
# MASTER INBOUND RULES
# Ref: https://kubernetes.io/docs/reference/networking/ports-and-protocols/
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group_rule" "master_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  description       = "SSH"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidrs
}

resource "aws_security_group_rule" "master_api_server" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  description       = "Kubernetes API Server (admin + workers)"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidrs
}

resource "aws_security_group_rule" "master_api_from_worker" {
  type                     = "ingress"
  security_group_id        = aws_security_group.master.id
  description              = "Kubernetes API Server from workers"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "master_etcd" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  description       = "etcd (control-plane only)"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "master_kubelet" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  description       = "Kubelet API"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "master_scheduler" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  description       = "kube-scheduler"
  from_port         = 10259
  to_port           = 10259
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "master_controller_manager" {
  type              = "ingress"
  security_group_id = aws_security_group.master.id
  description       = "kube-controller-manager"
  from_port         = 10257
  to_port           = 10257
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "master_calico_bgp" {
  type                     = "ingress"
  security_group_id        = aws_security_group.master.id
  description              = "Calico BGP from workers"
  from_port                = 179
  to_port                  = 179
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "master_calico_vxlan" {
  type                     = "ingress"
  security_group_id        = aws_security_group.master.id
  description              = "Calico VXLAN from workers"
  from_port                = 4789
  to_port                  = 4789
  protocol                 = "udp"
  source_security_group_id = aws_security_group.worker.id
}

# ─────────────────────────────────────────────────────────────────────────────
# WORKER INBOUND RULES
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group_rule" "worker_ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "SSH"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidrs
}

resource "aws_security_group_rule" "worker_kubelet_from_master" {
  type                     = "ingress"
  security_group_id        = aws_security_group.worker.id
  description              = "Kubelet API from master"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.master.id
}

resource "aws_security_group_rule" "worker_nodeport" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "NodePort Services (30000-32767)"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "worker_calico_bgp" {
  type                     = "ingress"
  security_group_id        = aws_security_group.worker.id
  description              = "Calico BGP from master"
  from_port                = 179
  to_port                  = 179
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.master.id
}

resource "aws_security_group_rule" "worker_calico_vxlan" {
  type                     = "ingress"
  security_group_id        = aws_security_group.worker.id
  description              = "Calico VXLAN from master"
  from_port                = 4789
  to_port                  = 4789
  protocol                 = "udp"
  source_security_group_id = aws_security_group.master.id
}

resource "aws_security_group_rule" "worker_to_worker" {
  type              = "ingress"
  security_group_id = aws_security_group.worker.id
  description       = "Worker-to-worker all traffic (Calico pod networking)"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
}
