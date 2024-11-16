output "lb_dns_name" {
  value = aws_lb.app.dns_name // This gives us the web address of our load balancer.
}