resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

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

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner = "ebs.csi.aws.com"

  volume_binding_mode = "WaitForFirstConsumer"

  reclaim_policy = "Delete"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  allow_volume_expansion = true
}

resource "kubernetes_manifest" "prometheus_target_group_binding" {
  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"

    metadata = {
      name      = "prometheus"
      namespace = "monitoring"
    }

    spec = {
      targetGroupARN = data.terraform_remote_state.ingress.outputs.prometheus_target_group_arn
      targetType     = "ip"

      serviceRef = {
        name = "kube-prometheus-stack-prometheus"
        port = 9090
      }
    }
  }
}

resource "kubernetes_manifest" "grafana_target_group_binding" {
  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"

    metadata = {
      name      = "grafana"
      namespace = "monitoring"
    }

    spec = {
      targetGroupARN = data.terraform_remote_state.ingress.outputs.grafana_target_group_arn
      targetType     = "ip"

      serviceRef = {
        name = "kube-prometheus-stack-grafana"
        port = 80
      }
    }
  }
}
