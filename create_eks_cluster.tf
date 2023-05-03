# Configure the AWS provider
provider "aws" {
  region = "us-west-2"
}

# Create an EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = aws_subnet.private.*.id
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

# Create an IAM role for the EKS cluster
resource "aws_iam_role" "eks_cluster" {
  name = "my-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach an IAM policy to the EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Create the VPC and subnets for the EKS cluster
module "eks_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "eks"
  cidr = "10.0.0.0/16"

  azs = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Create the worker node group for the EKS cluster
module "eks_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/node_group"

  cluster_name = aws_eks_cluster.eks_cluster.name
  subnets      = aws_subnet.private.*.id

  node_group_name = "eks-workers"
  instance_type   = "t2.micro"
  desired_capacity = 2

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Output the EKS cluster endpoint and worker node group info
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_node_group_info" {
  value = module.eks_node_group
}
