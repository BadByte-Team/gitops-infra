terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "curso-gitops-terraform-state"
    key            = "ec2-prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "curso-gitops-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

# ── Security Group ─────────────────────────────────────────────────────────────
resource "aws_security_group" "prod_sg" {
  name        = "prod-sg"
  description = "Security group para servidor de produccion K3s"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "ArgoCD Web UI (NodePort)"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App Go HTTP (NodePort)"
    from_port   = 30081
    to_port     = 30081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "K3s API Server (kubectl remoto)"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Todo el trafico saliente"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "prod-sg"
    Project = "curso-gitops"
  }
}

# ── EC2 Instance ───────────────────────────────────────────────────────────────
resource "aws_instance" "prod_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name

  vpc_security_group_ids = [aws_security_group.prod_sg.id]

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name    = "Produccion-K3s"
    Project = "curso-gitops"
  }
}
