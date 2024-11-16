terraform {
  // This block tells Terraform which providers we need.
  required_providers {
    // We need the AWS provider to create resources in Amazon Web Services.
    aws = {
      source  = "hashicorp/aws" // This is where we get the AWS provider from.
      version = "~> 4.15.0" // We want a version of the AWS provider that's at least 4.15.0 but less than 5.0.0.
    }

    // We also need the random provider to create random names for our resources.
    random = {
      source  = "hashicorp/random" // This is where we get the random provider from.
      version = "3.4.3" // We want exactly version 3.4.3 of the random provider.
    }
  }

  // This tells Terraform which version of itself we need to use.
  required_version = "~> 1.9.0" // We want a version of Terraform that's at least 1.9.0 but less than 2.0.0.
}