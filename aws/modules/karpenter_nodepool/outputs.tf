output "ec2nodeclass_name" {
  description = "Name of the created EC2 Node Class alongside the node pool."
  value       = local.ec2nodeclass_name
}

output "ec2nodeclass_yaml" {
  description = "Parsed + Obfuscated version of the constructed YAML for the EC2 Node Class."
  value       = one(kubectl_manifest.ec2nodeclass[*].yaml_body_parsed)
}

output "nodepool_yaml" {
  description = "Parsed + Obfuscated version of the constructed YAML for the Karpenter Node Pool."
  value       = one(kubectl_manifest.nodepool[*].yaml_body_parsed)
}
