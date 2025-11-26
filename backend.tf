terraform {
  backend "s3" {
    bucket = "pod3-terraform-state-pod3-terraform-state "  # Your new bucket name
    key    = "terraform.tfstate"              # Simplified path
    region = "us-east-1"
  }
}