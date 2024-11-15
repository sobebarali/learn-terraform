terraform {
  required_version = "~> 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
  }

  cloud {
    organization = "sobebar"
    workspaces {
      name = "learn-terraform-aws"
    }
  }
}