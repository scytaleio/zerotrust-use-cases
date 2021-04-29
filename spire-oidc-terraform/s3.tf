resource "aws_s3_bucket" "scytale-bucket" {
  bucket = "scytale-oidc"
  acl    = "private"
  region = var.region

  tags = {
    Name        = "scytale-oidc"
  }
}

resource "aws_s3_bucket_object" "scytale_object" {
  key                    = "scytale_object"
  bucket                 = aws_s3_bucket.scytale-bucket.id
  source                 = "files/test.txt"
  server_side_encryption = "AES256"
}