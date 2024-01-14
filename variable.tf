variable "region" {
  type        = string
  description = "The AWS Region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "The VPC CIDR block range"
  default     = "10.0.0.0/16"
}

variable "public_sbn_cidr_ranges" {
  type        = list(string)
  description = "Public subnet CIDR block ranges"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "db_username" {
  type        = string
  description = "MySQL database admin username"
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "MySQL database admin password"
  sensitive   = true
}