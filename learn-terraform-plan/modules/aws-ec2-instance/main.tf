resource "aws_instance" "main" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name  = var.instance_name
    Owner = "${var.project_name}-tutorial"
  }
}