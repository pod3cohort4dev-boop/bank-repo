output "nginx_ingress_lb_dns" {
  value = local.nginx_lb != null ? local.nginx_lb.dns_name : null
}

output "nginx_lb_ip" {
  value = local.nginx_lb != null ? local.nginx_lb.dns_name : null
}

output "nginx_ingress_load_balancer_hostname" {
  value = local.nginx_lb != null ? local.nginx_lb.dns_name : null
}