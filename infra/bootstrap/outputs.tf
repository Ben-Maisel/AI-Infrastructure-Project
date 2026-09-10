output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "Reference this in the main config's backend \"s3\" block"
}

output "lock_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "Reference this in the main config's backend \"s3\" block"
}
