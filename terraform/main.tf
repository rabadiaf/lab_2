#These are the values manadatory for Localstack

terraform {
  # Requerir Terraform 1.9.x (o superior menor a 2.0)
  required_version = ">= 1.5.0, < 2.0.0" # alternativa: ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.75.0"
    }
  }
}

# ✅ Provider para LocalStack
provider "aws" {
  region                      = var.aws_region
  access_key                  = "test" # Credenciales ficticias para LocalStack
  secret_key                  = "test" # Credenciales ficticias para LocalStack
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true # Omitir la obtención del ID de la cuenta
  s3_force_path_style         = true
  endpoints {
    s3         = "http://localhost:4566"
    ec2        = "http://localhost:4566"
    lambda     = "http://localhost:4566"
    iam        = "http://localhost:4566"
    dynamodb   = "http://localhost:4566"
    apigateway = "http://localhost:4566"
  }
}
