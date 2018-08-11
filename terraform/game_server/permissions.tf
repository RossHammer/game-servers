resource "aws_security_group" "server" {
  name        = "${var.name}"
  description = "${var.name} server settings"
  vpc_id      = "${aws_default_vpc.default.id}"
}

resource "aws_security_group_rule" "game_ingress" {
  type              = "ingress"
  count             = "${length(var.ports)}"
  from_port         = "${lookup(var.ports[count.index], "port")}"
  to_port           = "${lookup(var.ports[count.index], "port")}"
  protocol          = "${lookup(var.ports[count.index], "protocol", "TCP")}"
  description       = "${lookup(var.ports[count.index], "description", "")}"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.server.id}"
}

resource "aws_security_group_rule" "ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.server.id}"
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.server.id}"
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
  name = "instance"
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
    },
    {
      "Action": "route53:ChangeResourceRecordSets",
      "Effect": "Allow",
      "Resource": "arn:aws:route53:::hostedzone/${data.aws_route53_zone.rosshammer.id}"
    }
  ]
}
EOF
}
