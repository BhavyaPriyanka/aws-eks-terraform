resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.26"

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  wait    = true
  timeout = 600
}

resource "kubernetes_manifest" "localhelp_backend" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "localhelp-backend"
      namespace = "argocd"
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/BhavyaPriyanka/Gitops-ArgoCD.git"
        targetRevision = "main"
        path           = "apps/backend/helm"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "localhelp"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }

        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "localhelp_frontend" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "localhelp-frontend"
      namespace = "argocd"
    }

    spec = {
      project = "default"

      source = {
        repoURL        = "https://github.com/BhavyaPriyanka/Gitops-ArgoCD.git"
        targetRevision = "main"
        path           = "apps/frontend/helm"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "localhelp"
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }

        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}