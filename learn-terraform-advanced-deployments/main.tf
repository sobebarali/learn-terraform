provider "aws" {
  region = var.region // This tells AWS where to create our resources.
}

data "aws_availability_zones" "available" {
  state = "available" // We want to find all the zones that are ready to use.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"] // We only want zones that don't need special permission.
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws" // This is a pre-made module to create a VPC.
  version = "3.19.0" // We want this specific version of the module.

  name = "main-vpc" // This is the name of our VPC.
  cidr = var.vpc_cidr_block // This is the address space for our VPC.

  azs             = data.aws_availability_zones.available.names // These are the zones where our VPC will be.
  private_subnets = slice(var.private_subnet_cidr_blocks, 0, var.private_subnet_count) // These are the private sub-networks.
  public_subnets  = slice(var.public_subnet_cidr_blocks, 0, var.public_subnet_count) // These are the public sub-networks.

  enable_nat_gateway = true // We want a NAT gateway to allow private subnets to access the internet.
  enable_vpn_gateway = var.enable_vpn_gateway // This decides if we want a VPN gateway.
}

module "app_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web" // This is a pre-made module for security groups.
  version = "4.17.1" // We want this specific version of the module.

  name        = "web-sg" // This is the name of our security group.
  description = "Security group for web-servers with HTTP ports open within VPC" // This group allows web traffic.
  vpc_id      = module.vpc.vpc_id // This is the ID of the VPC where the security group will be.

  ingress_cidr_blocks = [module.vpc.vpc_cidr_block] // This allows traffic from within the VPC.
}

module "lb_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web" // This is a pre-made module for security groups.
  version = "4.17.1" // We want this specific version of the module.

  name        = "lb-sg" // This is the name of our security group for the load balancer.
  description = "Security group for load balancer with HTTP ports open to world" // This group allows web traffic from anywhere.
  vpc_id      = module.vpc.vpc_id // This is the ID of the VPC where the security group will be.

  ingress_cidr_blocks = ["0.0.0.0/0"] // This allows traffic from anywhere in the world.
}

data "aws_ami" "amazon_linux" {
  most_recent = true // We want the latest version of the Amazon Linux image.
  owners      = ["amazon"] // We only want images owned by Amazon.

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] // This is the type of image we want.
  }
}

resource "random_pet" "app" {
  length    = 2 // We want a name with two words.
  separator = "-" // The words will be separated by a dash.
}

resource "aws_lb" "app" {
  name               = "main-app-${random_pet.app.id}-lb" // This is the name of our load balancer.
  internal           = false // This means the load balancer is public.
  load_balancer_type = "application" // This is the type of load balancer.
  subnets            = module.vpc.public_subnets // These are the subnets where the load balancer will be.
  security_groups    = [module.lb_security_group.security_group_id] // This is the security group for the load balancer.
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn // This is the load balancer we want to listen to.
  port              = "80" // This is the port we want to listen on.
  protocol          = "HTTP" // This is the protocol we want to use.

  default_action {
    type             = "forward" // We want to forward traffic to target groups.
    forward {
        target_group {
          arn    = aws_lb_target_group.blue.arn // This is the blue target group.
          weight = lookup(local.traffic_dist_map[var.traffic_distribution], "blue", 100) // This is how much traffic goes to blue.
        }

        target_group {
          arn    = aws_lb_target_group.green.arn // This is the green target group.
          weight = lookup(local.traffic_dist_map[var.traffic_distribution], "green", 0) // This is how much traffic goes to green.
        }

        stickiness {
          enabled  = false // We don't want sticky sessions.
          duration = 1 // This is the duration for stickiness if it were enabled.
        }
      }
  }
}