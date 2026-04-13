variable "region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-2"
}

variable "bucket_name" {
  description = "Nombre del bucket S3 para el estado de Terraform"
  type        = string
  default     = "curso-gitops-pruebas-state"
}

variable "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB para el locking"
  type        = string
  default     = "curso-gitops-pruebas-locks"
}
