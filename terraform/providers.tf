terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      "Project" = "cloud-native-sre-platform"
      ManagedBy     = "Terraform"
      "Environment" = var.environment
    }
  }
}
