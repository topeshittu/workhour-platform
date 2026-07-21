resource "aws_s3_bucket" "practice" {
  bucket_prefix = "workhour-postifyhq-tf-practice-"

  force_destroy = true

  tags = {
    Name = "workhour-postifyhq-terraform-practice"
  }
}
