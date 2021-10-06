variable "aws_region" {
  default     = "us-east-2"
  description = "The AWS region to create things in."
}

variable "app_count" {
  type = number
  default = 2
  description = "Number of docker containers to run."
}

variable "environment" {
  type = string
  default     = "development"
  description = "The enviroment name where that app will be deployed."
}

variable "number_sub" {
  type = number
  default     = 2
  description = "Count subnets, gateway, routetable,"
}