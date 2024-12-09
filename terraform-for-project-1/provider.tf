provider "aws" {
  region = local.region
}

terraform {
  # backend "s3" {
  #   bucket         = "url-prod-s3"
  #   region         = "us-east-1"
  #   key            = "mystate"
  #  // dynamodb_table = "Lock-Files"
  #   dynamodb_table = "Lock-Files"
  #   encrypt        = true
  # }
  required_version = ">=1.0"
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.49"
    }
  }
}