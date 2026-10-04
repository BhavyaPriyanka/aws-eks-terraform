resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "oci://${var.ecr_registry}/localhelp-monitoring"
  chart      = "kube-prometheus-stack"
  version    = "91.8.2"

  values = [
    file("${path.module}/values-monitoring.yaml")
  ]

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    kubernetes_storage_class_v1.gp3
  ]
}