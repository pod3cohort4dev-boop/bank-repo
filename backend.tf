terraform {
  backend "s3" {
    bucket = "pod3-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}