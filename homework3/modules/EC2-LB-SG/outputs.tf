##################################################################################
# OUTPUT
##################################################################################

output "elb" {
  value = aws_lb.web.dns_name
}

output "dns_nginx-1" {
  value = aws_instance.nginx[0].public_dns
}

output "dns_nginx-2" {
  value = aws_instance.nginx[1].public_dns
}