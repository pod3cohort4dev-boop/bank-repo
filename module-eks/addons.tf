provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.0"
  namespace  = "ingress-nginx"
  create_namespace = true

  values = [file("${path.module}/nginx-ingress-values.yaml")]
  depends_on = [
  aws_eks_node_group.eks_node_group
  aws_eks_cluster.eks
  ]
}

# Add delay for load balancer creation
resource "time_sleep" "wait_for_lb" {
  depends_on = [helm_release.nginx_ingress]
  create_duration = "120s"
}

# Get the load balancer info from the Kubernetes service
data "kubernetes_service" "nginx_ingress" {
  provider = kubernetes.eks 
  
  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.nginx_ingress, time_sleep.wait_for_lb]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.14.5"
  namespace  = "cert-manager"
  create_namespace = true
  replace    = true
  
  values = [file("${path.module}/cert-manager-values.yaml")]
  depends_on = [helm_release.nginx_ingress]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true
  replace          = true
  values = [file("${path.module}/argocd-values.yaml")]
  depends_on = [helm_release.nginx_ingress, helm_release.cert_manager]
}