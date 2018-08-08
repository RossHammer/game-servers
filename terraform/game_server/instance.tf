locals {
  script = <<EOF
#!/bin/bash
DISCORD_WEBHOOK=${var.discord_webhook}
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
