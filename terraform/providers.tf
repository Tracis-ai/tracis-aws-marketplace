provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Service   = "Tracis"
      ManagedBy = "Terraform"
    }
  }
}
