output "vpc_id" {
  value = aws_vpc.practice.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "test_url" {
  value = "http://${aws_instance.web.public_ip}"
}
