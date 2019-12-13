data "aws_ami" "hashistack" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = [var.ami]
  }
}

resource "aws_key_pair" "usw2_ec2_key" {
  key_name   = "${var.prefix}-${var.env}-usw2-ec2-key"
  public_key = var.public_key
  # public_key = "${file("~/.ssh/id_rsa.pub")}"    # running locally
}

