#Keys
variable "aws_access_key" {
  default = "__TerraformAccessKey__"
}

variable "aws_secret_key" {
  default = "__TerraformSecretKey__"
}

# Regions
variable "aws_region" {
  default = "us-east-1"
}

variable "aws_az1"{
  default = "us-east-1a"
}

variable "aws_az2"{
  default = "us-east-1b"
}

# Subnets
variable "k8_sub_1" {
  default = "10.0.1.0/24"
}
variable "k8_sub_2" {
  default = "10.0.21.0/24"
}

# EKS Cluster
variable "cluster_name" {
    default = "k8-cluster"
}