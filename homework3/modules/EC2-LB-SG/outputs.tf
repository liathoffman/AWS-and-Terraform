##################################################################################
# OUTPUT
##################################################################################

output "elb" {
  value = aws_lb.web.dns_name
}

output "dns_nginx_servers" {
  value = ["${aws_instance.nginx.*.public_dns}"]
}
