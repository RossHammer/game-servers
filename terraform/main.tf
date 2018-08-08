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

variable "discord_webhook" {
  type = "string"
}

module "factorio" {
  source           = "./game_server"
  name             = "factorio"
  init_script_path = "${path.module}/factorio.sh"
  discord_webhook  = "${var.discord_webhook}"

  ports = [
    {
      description = "game"
      port        = 34197
      protocol    = "UDP"
    },
    {
      description = "rcon"
      port        = 27015
    },
  ]
}
