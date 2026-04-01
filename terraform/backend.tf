terraform {
  backend "s3" {
    bucket         = "baho-backup-bucket"
    key            = "Codepipeline-ecommerce"
    region         = "us-west-2"
    dynamodb_table = "Codepipeline-ecommerce-table"
    encrypt        = true
  }
}
