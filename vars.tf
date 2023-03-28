variable "default_tags" {
  type = map(string)
  default = {
    "env" = "brian"
  }
  description = "brian variables description"
}

variable "public_subnet_count" {
  type        = number
  description = "public subnet count description"
  default     = 2
}