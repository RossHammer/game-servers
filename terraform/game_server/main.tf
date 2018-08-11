variable "name" {
  type = "string"
}

variable "init_script_path" {
  type = "string"
}

variable "discord_webhook" {
  type = "string"
}

variable "ports" {
  type = "list"
}

variable "image_id" {
  default = "ami-a9d09ed1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  default = "ross"
}

resource "aws_default_vpc" "default" {}

data "aws_route53_zone" "rosshammer" {
  name = "rosshammer.com."
}
