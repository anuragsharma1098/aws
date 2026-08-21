output "node_group_arn" {
  description = "ARN of the node group"
  value       = aws_eks_node_group.this.arn
}

output "node_role_arn" {
  description = "ARN of the node IAM role"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Name of the node IAM role"
  value       = aws_iam_role.node.name
}
