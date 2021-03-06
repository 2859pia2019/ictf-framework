//  This module defines all the settings needed by the database
data "aws_ami" "router" {
  most_recent = true

  filter {
    name   = "name"
    values = ["harden_router_16.04_*"]
  }

  owners = ["self"]
}

data "aws_eip" "router_ip" {
  tags = {
    Name = "ictf-router-ip"
  }
}

data "aws_s3_bucket" "router_bucket" {
  bucket = "ictf-router-bucket-${var.region}"
}

resource "aws_eip_association" "router_ip" {
    instance_id = aws_instance.router.id
    allocation_id = data.aws_eip.router_ip.id
}

resource "aws_route" "vpn" {
    route_table_id = aws_vpc.ictf.main_route_table_id
    destination_cidr_block = "10.9.0.0/16"
    instance_id = aws_instance.router.id
}

resource "aws_instance" "router" {
    ami = data.aws_ami.router.id
    instance_type = var.router_instance_type
    subnet_id = aws_subnet.war_range_subnet.id
    vpc_security_group_ids = [aws_security_group.router_secgrp.id]
    private_ip = "172.31.172.1"

    tags = {
        Name = "router"
        Type = "Infrastructure"
    }

    key_name = aws_key_pair.router-key.key_name
    source_dest_check = false

    root_block_device {
        volume_size = 15000
    }

    volume_tags = {
        Name = "router-disk"
    }

    connection {
        user = "hacker"
        private_key = file("./sshkeys/router-key.key")
        host = self.public_ip
        agent = false
    }

    provisioner "file" {
        source = "../../router/provisioning/terraform_provisioning.yml"
        destination = "/opt/ictf/router/provisioning/terraform_provisioning.yml"
    }

    provisioner "file" {
        source = "./vpnkeys/openvpn.zip"
        destination = "/opt/ictf/openvpn.zip"
    }

    provisioner "remote-exec" {
        inline =  [
            "sudo pip install -q ansible",
            "/usr/local/bin/ansible-playbook /opt/ictf/router/provisioning/terraform_provisioning.yml --extra-vars AWS_BUCKET_NAME=${data.aws_s3_bucket.router_bucket.id} --extra-vars AWS_REGION=${var.region} --extra-vars AWS_ACCESS_KEY=${var.access_key} --extra-vars AWS_SECRET_KEY=${var.secret_key} --extra-vars ICTF_API_SECRET=${file("../../secrets/database-api/secret")}",
            "echo 'hacker' | sudo sed -i '/^#PasswordAuthentication[[:space:]]yes/c\\PasswordAuthentication no' /etc/ssh/sshd_config",
            "sudo service ssh restart"
        ]
    }
}
