provider "aws" {
    #version = "~> 3.0"
    #Connection to AWS account
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
    region     = var.aws_region

}

#S3 state file
terraform {
  backend "s3" {
    bucket = "chris-k8-state-file-20200303"
    key    = "statefile/terraform.tfstate"
    region = "us-east-1"
  }
}

#K8 VPC
resource "aws_vpc" "k8-vpc" {
  cidr_block  = "10.0.0.0/16"

  tags = {
    Name = "K8-VPC"
  }
}

resource "aws_internet_gateway" "k8-ig" {
  vpc_id = aws_vpc.k8-vpc.id

  tags = {
    Name = "k8-IG"
  }
}

resource "aws_route_table" "k8-route" {
  vpc_id = aws_vpc.k8-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8-ig.id
  }

  tags = {
    Name = "main",
    Deloyment = "Terraform"
  }
}

resource "aws_route_table_association" "k8-route-assoc-a" {
  subnet_id      = aws_subnet.k8-sub-1.id
  route_table_id = aws_route_table.k8-route.id
}

resource "aws_route_table_association" "k8-route-assoc-b" {
  subnet_id      = aws_subnet.k8-sub-2.id
  route_table_id = aws_route_table.k8-route.id
}

# AZ1 Subnet 
resource "aws_subnet" "k8-sub-1" {
  vpc_id     = aws_vpc.k8-vpc.id
  cidr_block = var.k8_sub_1
  availability_zone = var.aws_az1

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# AZ2 Subnet 
resource "aws_subnet" "k8-sub-2" {
  vpc_id     = aws_vpc.k8-vpc.id
  cidr_block = var.k8_sub_2
  availability_zone = var.aws_az2

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "k8-cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.k8-iam.arn

  vpc_config {
    subnet_ids = [aws_subnet.k8-sub-1.id, aws_subnet.k8-sub-2.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.k8-iam-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.k8-iam-AmazonEKSServicePolicy,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.k8-cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.k8-cluster.certificate_authority.0.data
}

# EKS IAM Roles
resource "aws_iam_role" "k8-iam" {
  name = "chris-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "k8-iam-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.k8-iam.name
}

resource "aws_iam_role_policy_attachment" "k8-iam-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.k8-iam.name
}

resource "aws_eks_node_group" "k8-nodegroup" {
  cluster_name    = var.cluster_name
  node_group_name = "k8-nodegroup"
  node_role_arn   = aws_iam_role.k8-ng-iam.arn
  subnet_ids      = [aws_subnet.k8-sub-1.id, aws_subnet.k8-sub-2.id]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.k8-ng-iam-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.k8-ng-iam-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.k8-ng-iam-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_iam_role" "k8-ng-iam" {
  name = "eks-node-group-iam"

  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "k8-ng-iam-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.k8-ng-iam.name
}

resource "aws_iam_role_policy_attachment" "k8-ng-iam-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.k8-ng-iam.name
}

resource "aws_iam_role_policy_attachment" "k8-ng-iam-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.k8-ng-iam.name
}

resource "aws_efs_file_system" "k8-efs" {
  creation_token = "k8"

  tags = {
    Name = "K8-EFS"
  }
}