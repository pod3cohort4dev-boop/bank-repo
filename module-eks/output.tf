output "nginx_ingress_lb_dns" {
  value = try(data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "nginx_lb_ip" {
  value = try(data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "nginx_ingress_load_balancer_hostname" {
  value = try(data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname, null)
}