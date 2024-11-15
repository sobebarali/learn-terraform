variable "region" {
  type        = string
  description = "AWS region for all resources."

  default = "ap-south-1"
}

variable "project_name" {
  type        = string
  description = "Name of the example project."

  default = "terraform-plan"
}

variable "secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key for hello module"

// No default value, so it will be taken from terraform.tfvars
}
