variable "project_name" {
    description = "The name of the project"
    type        = string
    default     = "auto-ec2-deploy-test"
}

variable "aws_region" {
  description = "The AWS region to create resources in"
  type        = string
  default = "eu-south-2"
}

