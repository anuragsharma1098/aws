output "principal_arns" {
  description = "Principal ARNs that were granted access entries"
  value       = [for e in aws_eks_access_entry.this : e.principal_arn]
}
