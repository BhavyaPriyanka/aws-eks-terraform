output "argocd_namespace" {
  description = "Namespace where Argo CD is installed"
  value       = helm_release.argocd.namespace
}

output "argocd_release_name" {
  description = "Argo CD Helm release name"
  value       = helm_release.argocd.name
}

output "eks_cluster_name" {
  description = "EKS cluster targeted by this module"
  value       = data.aws_eks_cluster.this.name
}