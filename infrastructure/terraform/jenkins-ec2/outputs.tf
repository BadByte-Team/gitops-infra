output "prod_public_ip" {
  description = "IP pública de la instancia EC2 K3s"
  value       = aws_instance.prod_server.public_ip
}

output "prod_public_dns" {
  description = "DNS público de la instancia EC2 K3s"
  value       = aws_instance.prod_server.public_dns
}

output "instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.prod_server.id
}

output "security_group_id" {
  description = "ID del Security Group"
  value       = aws_security_group.prod_sg.id
}

output "argocd_url" {
  description = "URL del dashboard de ArgoCD"
  value       = "http://${aws_instance.prod_server.public_ip}:30080"
}

output "app_url" {
  description = "URL de la app Go"
  value       = "http://${aws_instance.prod_server.public_ip}:30081"
}
