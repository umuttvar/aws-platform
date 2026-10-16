
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.9.4"
  namespace        = "argocd"
  create_namespace = true

  values = [file("${path.module}/values.yaml")]
}