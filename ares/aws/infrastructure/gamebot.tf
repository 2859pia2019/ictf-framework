data "aws_ami" "gamebot" {
  most_recent = true

  filter {
    name   = "name"
    values = ["harden_gamebot_16.04_*"]
  }

  owners = ["self"]
}

resource "aws_instance" "gamebot" {
    ami = data.aws_ami.gamebot.id
    instance_type = var.gamebot_instance_type
    subnet_id = aws_subnet.master_and_db_range_subnet.id
    vpc_security_group_ids = [aws_security_group.master_subnet_secgrp.id]
    key_name = aws_key_pair.gamebot-key.key_name

    tags = {
        Name = "gamebot"
        Type = "Infrastructure"
    }

    root_block_device {
        volume_size = 100
    }

    volume_tags = {
        Name = "gamebot-disk"
    }

    connection {
        user = "hacker"
        private_key = file("./sshkeys/gamebot-key.key")
        host = self.public_ip
        agent = false
    }

    provisioner "remote-exec" {
        inline = [
            "sudo pip install -q ansible",
            "/usr/local/bin/ansible-playbook /opt/ictf/gamebot/provisioning/terraform_provisioning.yml --extra-vars ICTF_API_ADDRESS=${aws_instance.database.private_ip} --extra-vars ICTF_API_SECRET=${file("../../secrets/database-api/secret")}",
            "echo 'hacker' | sudo sed -i '/^#PasswordAuthentication[[:space:]]yes/c\\PasswordAuthentication no' /etc/ssh/sshd_config",
            "sudo service ssh restart"
        ]
    }
}
