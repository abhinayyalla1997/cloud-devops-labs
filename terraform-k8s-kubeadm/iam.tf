# ─────────────────────────────────────────────────────────────────────────────
# Shared EC2 assume-role trust policy
# ─────────────────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# MASTER — can write the join command to SSM
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "master" {
  name               = "${var.cluster_name}-master-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "master_ssm" {
  statement {
    sid    = "SSMWriteJoinCommand"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.cluster_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "master_ssm" {
  name   = "${var.cluster_name}-master-ssm"
  role   = aws_iam_role.master.id
  policy = data.aws_iam_policy_document.master_ssm.json
}

resource "aws_iam_instance_profile" "master" {
  name = "${var.cluster_name}-master-profile"
  role = aws_iam_role.master.name
  tags = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# WORKER — can only read the join command from SSM
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "worker" {
  name               = "${var.cluster_name}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "worker_ssm" {
  statement {
    sid    = "SSMReadJoinCommand"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.cluster_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "worker_ssm" {
  name   = "${var.cluster_name}-worker-ssm"
  role   = aws_iam_role.worker.id
  policy = data.aws_iam_policy_document.worker_ssm.json
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.cluster_name}-worker-profile"
  role = aws_iam_role.worker.name
  tags = local.common_tags
}
