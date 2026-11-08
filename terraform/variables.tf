variable "aws_region" {
    description = "Target AWS region"
    type        = string
    default     = "us-east-1"
}

variable "environment" {
    description = "Deployment environment name"
    type        = string
    default     = "dev"
}

variable "cluster_name" {
    description = "Name of the EKS cluster"
    type        = string
    default     = "platform-eks-cluster"
}

variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type        = string
    default     = "10.0.0.0/16"
}