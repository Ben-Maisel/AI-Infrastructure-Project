output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "Reference this in the main config's backend \"s3\" block"
}
