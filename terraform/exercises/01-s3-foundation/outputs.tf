output "bucket_name" {
  description = "Name of the disposable Terraform practice bucket"
  value       = aws_s3_bucket.practice.id
}
