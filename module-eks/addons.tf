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
  depends_on = [aws_eks_node_group.eks_node_group]
}

# Add delay for load balancer creation
resource "time_sleep" "wait_for_lb" {
  depends_on = [helm_release.nginx_ingress]
  create_duration = "120s"
}

# Simple data source with relaxed filtering
data "aws_lb" "nginx_ingress" {
  tags = {
    "kubernetes.io/service-name" = "ingress-nginx/nginx-ingress-ingress-nginx-controller"
  }
  depends_on = [time_sleep.wait_for_lb]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.14.5"
  namespace  = "cert-manager"
  create_namespace = true
  
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
  values = [file("${path.module}/argocd-values.yaml")]
  depends_on = [helm_release.nginx_ingress, helm_release.cert_manager]
}

# Debug output to see what load balancers exist
output "debug_all_load_balancers" {
  value = [for lb in data.aws_lbs.all.lbs : {
    name = lb.name
    tags = lb.tags
    dns_name = lb.dns_name
  }]
}

output "nginx_lb_found" {
  value = local.nginx_lb != null ? "Found: ${local.nginx_lb.dns_name}" : "No nginx load balancer found"
}