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

# Install nginx ingress
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.0"
  namespace  = "ingress-nginx"
  create_namespace = true

  values = [file("${path.module}/nginx-ingress-values.yaml")]
  depends_on = [aws_eks_node_group.eks_node_group]
}

# Wait for ingress to be ready
resource "time_sleep" "wait_for_ingress" {
  depends_on = [helm_release.nginx_ingress]
  create_duration = "120s"
}

# Get the load balancer info from the Kubernetes service
data "kubernetes_service" "nginx_ingress" {
  provider = kubernetes.eks
  
  metadata {
    name      = "nginx-ingress-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [time_sleep.wait_for_ingress]
}

# Install cert-manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.14.5"
  namespace  = "cert-manager"
  create_namespace = true
  
  values = [file("${path.module}/cert-manager-values.yaml")]
  
  timeout = 600
  wait    = true
  
  # Add these to handle the existing resources
  force_update = true
  replace      = true
  
  depends_on = [
    helm_release.nginx_ingress,
    time_sleep.wait_for_ingress
  ]
}

# Wait for cert-manager to be ready
resource "time_sleep" "wait_for_cert_manager" {
  depends_on = [helm_release.cert_manager]
  create_duration = "30s"
}

# Install ArgoCD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true
  values = [file("${path.module}/argocd-values.yaml")]
  
  depends_on = [
    helm_release.nginx_ingress,
    time_sleep.wait_for_cert_manager
  ]
}

# Output the load balancer hostname
output "nginx_ingress_lb_hostname" {
  value = try(data.kubernetes_service.nginx_ingress.status.0.load_balancer.0.ingress.0.hostname, "Load balancer not ready yet")
}