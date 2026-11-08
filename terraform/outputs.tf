output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "cluster_endpoint" {
  description = "Endpoint URL for the Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Name of the provisioned EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  value       = module.eks.cluster_security_group_id
}