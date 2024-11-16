resource "aws_instance" "blue" {
  count = var.enable_blue_env ? var.blue_instance_count : 0 // This decides how many blue instances we want.

  ami                    = data.aws_ami.amazon_linux.id // This is the image we use for the instance.
  instance_type          = "t2.micro" // This is the type of instance we want.
  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)] // This is the subnet where the instance will be.
  vpc_security_group_ids = [module.app_security_group.security_group_id] // This is the security group for the instance.
  user_data = templatefile("${path.module}/init-script.sh", {
    file_content = "version 1.0 - #${count.index}" // This is the script that runs when the instance starts.
  })

  tags = {
    Name = "blue-${count.index}" // This is the name tag for the instance.
  }
}

resource "aws_lb_target_group" "blue" {
  name     = "blue-tg-${random_pet.app.id}-lb" // This is the name of the blue target group.
  port     = 80 // This is the port the target group listens on.
  protocol = "HTTP" // This is the protocol the target group uses.
  vpc_id   = module.vpc.vpc_id // This is the VPC where the target group is.

  health_check {
    port     = 80 // This is the port for health checks.
    protocol = "HTTP" // This is the protocol for health checks.
    timeout  = 5 // This is how long we wait for a health check to respond.
    interval = 10 // This is how often we do health checks.
  }
}

resource "aws_lb_target_group_attachment" "blue" {
  count            = length(aws_instance.blue) // This is how many attachments we need.
  target_group_arn = aws_lb_target_group.blue.arn // This is the target group we attach to.
  target_id        = aws_instance.blue[count.index].id // This is the instance we attach.
  port             = 80 // This is the port we use for the attachment.
}