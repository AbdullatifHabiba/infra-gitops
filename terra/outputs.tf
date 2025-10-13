# EKS Cluster outputs
output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by EKS"
  value       = module.eks.cluster_primary_security_group_id
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

# EKS Node Group outputs
output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks.eks_managed_node_groups
  sensitive   = true
}

output "node_security_group_id" {
  description = "ID of the node shared security group"  
  value       = module.eks.node_security_group_id
}

# VPC outputs
output "vpc_id" {
  description = "ID of the VPC where the cluster and nodes are deployed"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = module.vpc.natgw_ids
}

# EBS CSI Driver outputs
output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = var.enable_ebs_csi_driver ? module.ebs_csi_irsa_role[0].iam_role_arn : null
}

output "ebs_csi_driver_role_name" {
  description = "Name of the EBS CSI driver IAM role"
  value       = var.enable_ebs_csi_driver ? module.ebs_csi_irsa_role[0].iam_role_name : null
}

# Legacy output for backwards compatibility
output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster"
  value       = module.eks.aws_auth_configmap_yaml
}

# Useful connection information
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "cluster_region" {
  description = "AWS region where the cluster is deployed"
  value       = var.region
}