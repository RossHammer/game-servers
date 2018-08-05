provider "aws" {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket = "rosshammer"
    key    = "game_servers.tfstate"
    region = "us-east-1"
  }
}

variable "name" {
  default = "factorio"
}

resource "aws_default_vpc" "default" {}

resource "aws_security_group" "server" {
  name        = "${var.name}"
  description = "Factorio server settings"
  vpc_id      = "${aws_default_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 27015
    to_port     = 27015
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 34197
    to_port     = 34197
    protocol    = "UDP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.name}_profile"
  role = "${aws_iam_role.role.name}"
}

resource "aws_iam_role" "role" {
  name = "${var.name}"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "policy" {
  name = "s3"
  role = "${aws_iam_role.role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::glitch/${var.name}/*"
    },
    {
      "Action": "s3:ListBucket",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::glitch"
    }
  ]
}
EOF
}

resource "aws_launch_template" "server" {
  name     = "${var.name}"
  image_id = "ami-a9d09ed1"

  # instance_initiated_shutdown_behavior = "terminate"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.server.id}"]
  key_name               = "ross"
  user_data              = "${base64encode(file("${path.module}/init.sh"))}"

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
