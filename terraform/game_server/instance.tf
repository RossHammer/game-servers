locals {
  script = <<EOF
#!/bin/bash
PUBLIC_IP=$$(curl -sS http://169.254.169.254/latest/meta-data/public-ipv4)
CHANGE_BATCH=$$(cat <<DATA
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${var.name}.${data.aws_route53_zone.rosshammer.name}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [ { "Value": "$$PUBLIC_IP" } ]
      }
    }
  ]
}
DATA)
aws route53 change-resource-record-sets --hosted-zone-id "${data.aws_route53_zone.rosshammer.id}" --change-batch "$$CHANGE_BATCH"

discord() {
  curl -sSf -X POST -F "content=$1" "${var.discord_webhook}"
}
LOCATION="${var.name}.${replace(data.aws_route53_zone.rosshammer.name, "/\\.$$/", "")} ($$PUBLIC_IP)"

yum upgrade -y

${trimspace(file("${var.init_script_path}"))}
EOF
}

resource "aws_launch_template" "server" {
  name     = "${var.name}"
  image_id = "${var.image_id}"

  instance_type          = "${var.instance_type}"
  vpc_security_group_ids = ["${aws_security_group.server.id}"]
  key_name               = "${var.key_name}"
  user_data              = "${base64gzip(local.script)}"

  tag_specifications {
    resource_type = "instance"

    tags {
      Name = "${var.name}"
    }
  }

  iam_instance_profile {
    arn = "${aws_iam_instance_profile.instance_profile.arn}"
  }
}
