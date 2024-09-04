provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Name = "Adilet"
      Tool = "Terraform"
    }
  }
}
#--------------------------------------------------------------

data "aws_availability_zones" "working" {}

data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}
#----------------------------------------------------------------

resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.working.names[0]
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.working.names[1]
}
#----------------------------------------------------------------

resource "aws_security_group" "my_webserver" {
  name   = "My New Security Group"
  vpc_id = aws_default_vpc.default.id

  dynamic "ingress" {

    for_each = ["80", "443"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web Security Group"
  }
}
#-----------------------------------------------------------------

resource "aws_launch_template" "web" {
  name                   = "WebServer-Highly-Available-LC"
  image_id               = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_webserver.id]
  user_data              = filebase64("user_data.sh")
}
#-----------------------------------------------------------------

resource "aws_autoscaling_group" "web" {
  name                = "WebServer-Highly-Available-ASG-Ver-${aws_launch_template.web.latest_version}"
  max_size            = 3
  min_size            = 2
  min_elb_capacity    = 2
  health_check_type   = "ELB"
  vpc_zone_identifier = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  target_group_arns   = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  dynamic "tag" {
    for_each = {
      Name    = "WebServer in ASG-v${aws_launch_template.web.latest_version}"
      Project = "DevOps"
      TAGKEY  = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
#--------------------------------------------------------------------------------------

resource "aws_lb" "web" {
  name               = "WebServer-HA-LB"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_webserver.id]
  subnets            = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
}

resource "aws_lb_target_group" "web" {
  name                 = "WebServer-HighlyAvailable-TG"
  vpc_id               = aws_default_vpc.default.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 10 # seconds
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
#------------------------------------------------------------------------------------

output "web_alb_url" {
  value = aws_lb.web.dns_name
}
