terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 4.48"
    }
  }
  required_version = ">= 1.3"
}

provider "aws" {
    region = "us-west-2"
}

