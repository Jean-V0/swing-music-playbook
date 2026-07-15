variable "aws_region" {
  description = "Região da AWS onde os recursos serão criados"
  type        = string
  default     = "sa-east-1"
}

variable "s3_bucket_name" {
  description = "Nome do bucket S3"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR para permitir acesso SSH"
  type        = string
  default     = ""
}

variable "allowed_swingmusic_cidr" {
  description = "CIDR autorizado a acessar o SwingMusic na porta 1970"
  type        = string
  default     = "0.0.0.0/0"
}
