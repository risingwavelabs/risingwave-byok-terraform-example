output "iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the controller IAM role"
  value       = try(aws_iam_role.controller.arn, null)
}

output "node_iam_role_name" {
  description = "The name of the node IAM role"
  value       = try(aws_iam_role.node.name, null)
}

output "node_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the node IAM role"
  value       = try(aws_iam_role.node.arn, null)
}

output "queue_name" {
  description = "The name of the created Amazon SQS queue"
  value       = try(aws_sqs_queue.this.name, null)
}
