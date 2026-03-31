output "master_public_ip" {
  description = "Public IP of the control-plane node"
  value       = aws_instance.master.public_ip
}

output "master_private_ip" {
  description = "Private IP of the control-plane node"
  value       = aws_instance.master.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of all worker nodes"
  value       = aws_instance.workers[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of all worker nodes"
  value       = aws_instance.workers[*].private_ip
}

output "ssh_master" {
  description = "SSH into the master node"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.master.public_ip}"
}

output "ssh_workers" {
  description = "SSH commands for each worker node"
  value = [
    for w in aws_instance.workers :
    "ssh -i <your-key.pem> ubuntu@${w.public_ip}"
  ]
}

output "ssm_join_command_path" {
  description = "SSM parameter that holds the worker join command"
  value       = aws_ssm_parameter.join_command.name
}

output "fetch_join_command" {
  description = "Retrieve the worker join command from SSM"
  value       = "aws ssm get-parameter --name '${aws_ssm_parameter.join_command.name}' --with-decryption --query Parameter.Value --output text --region ${var.aws_region}"
}

output "view_master_log" {
  description = "Tail the master setup log over SSH"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.master.public_ip} 'sudo tail -f /var/log/k8s-master-setup.log'"
}

output "verify_cluster" {
  description = "Verify cluster after setup is complete"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.master.public_ip} 'kubectl get nodes -o wide'"
}
