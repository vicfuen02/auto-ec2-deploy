variable "project_name" {
    description = "The name of the project"
    type        = string
    default     = "auto-ec2-deploy-test"
}

variable "aws_region" {
  description = "The AWS region to create resources in"
  type        = string
  default = "eu-north-1"
}





variable "allowed_cidr" {
  description = "Your public IPv4 address in CIDR notation"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 2
}

variable "desired_capacity" {
  type    = number
  default = 2
}

