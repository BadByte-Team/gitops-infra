variable "region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-2"
}

variable "ami_id" {
  description = "AMI de Ubuntu 22.04 LTS (us-east-2)"
  type        = string
  default     = "ami-0d6d5a1f326b57cb0"
}

variable "instance_type" {
  description = "Tipo de instancia — t2.micro es Free Tier"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Nombre del Key Pair en AWS (el archivo .pem debe existir localmente)"
  type        = string
  # Sin default — se pasa con: terraform apply -var="key_name=aws-key"
}

variable "allowed_cidr" {
  description = "CIDR permitido para SSH (0.0.0.0/0 = cualquier IP)"
  type        = string
  default     = "0.0.0.0/0"
}
