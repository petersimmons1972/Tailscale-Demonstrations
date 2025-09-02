output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

# The EKS module does not output kubeconfig directly. Use the AWS CLI to generate kubeconfig after apply:
# aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
