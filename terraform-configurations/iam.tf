resource "aws_iam_role" "eks" {
  name = "${local.env}-${local.eks_name}-eks-cluster"
  assume_role_policy = <<POLICY
  {
  "Version": "2012-10-17",
  "Statement": [
  {
  "Effect": "Allow",
  "Action": "sts:AssumeRole",
  "Principal": {
  "Service": "eks.amazonaws.com"
  }
  }
  ]
  }
  POLICY
}

resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.eks.name
}

resource "aws_iam_role" "nodes" {
  name = "${local.env}-${local.eks_name}-eks-nodes"
  assume_role_policy = <<POLICY
  {
  "Version": "2012-10-17",
  "Statement": [
  {
  "Effect": "Allow",
  "Action": "sts:AssumeRole",
  "Principal": {
  "Service": "ec2.amazonaws.com"
  }

  }
  ]
  }
  POLICY
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = aws_iam_role.nodes.name
}
