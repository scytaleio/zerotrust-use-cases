#create a Linux instance in AWS
#set below env variables before terraform plan & apply
#export AWS_ACCESS_KEY_ID="anaccesskey"
#export AWS_SECRET_ACCESS_KEY="asecretkey"
provider "aws" {
        region     = var.region
}

# create an instance
resource "aws_instance" "linux_instance" {
  ami             = lookup(var.amis, var.region) 
  subnet_id       = var.subnet 
  security_groups = var.securityGroups 
  key_name        = var.keyName
  instance_type   = var.instanceType 
  
  # Create and attach an ebs volume 
  # when we create the instance
  root_block_device {
    delete_on_termination = true 
    encrypted             = false 
    volume_size           = 32
    volume_type           = "gp2"
    }
 
  # Name the instance
  tags = {
    Name = var.instanceName
  }
  # Name the volumes; will name all volumes included in the 
  # ami and the ebs block device from above with this instance.
  volume_tags = {
    Name = var.instanceName
  }

  provisioner "file" {
    source      = "files/oidc-discovery-provider.conf"
    destination = "/tmp/oidc-discovery-provider.conf"
  }

  provisioner "file" {
    source      = "files/install-spiffe.sh"
    destination = "/tmp/install-spiffe.sh"
  }

  # Change permissions on bash script and execute from ubuntu user.
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-spiffe.sh",
      "sudo /tmp/install-spiffe.sh ${var.domainName}",
    ]
  }
 
  
  # Login to the machine with ubuntu user with the aws key. keep the pem file in the current directory
  connection {
    type        = "ssh"
    user        = "ubuntu"
    agent       = false 
    private_key = "${file("scytale-oidc.pem")}"
    host        = self.public_ip
  }
  
} 


output "instance_ip" {
  description = "The public ip for ssh access"
  value       = aws_instance.linux_instance.public_ip
}