terraform {
  required_providers {
    confluent = {
      source = "confluentinc/confluent"
      version = "1.80.0"
    }
  }
}
provider "aws" {
    region = var.aws_region

    default_tags {
      tags = local.confluent_tags
    }
}
