
# --------------------------------------------------
# DEFAULT VPC AND SUBNETS
# --------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# --------------------------------------------------
# SECURITY GROUPS
# --------------------------------------------------

# Public security group: ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP access only from my public IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from my public IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Separate rule resource avoids a dependency cycle between the two groups
resource "aws_vpc_security_group_egress_rule" "ec2_toalb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "Application traffic to EC2"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}


# Separate rule resource avoids a dependency cycle between the two groups
resource "aws_vpc_security_group_egress_rule" "alb_to_ec2" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Application traffic to EC2"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2.id
}

# Private security group: EC2
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow application traffic only from ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Application traffic from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description     = "Application traffic from SSH"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    description = "HTTPS (S3, SSM, package repos)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP (package repos)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}
# --------------------------------------------------
# EC2 LAUNCH TEMPLATE
# --------------------------------------------------


resource "aws_key_pair" "app" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type
  key_name      = aws_key_pair.app.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  # Default VPC subnets have no NAT: a public IP is needed for outbound access
  # (dnf, S3). Inbound is still restricted to the ALB by the security group.
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    artifacts_bucket = aws_s3_bucket.artifacts.bucket
    app_port         = var.app_port
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-ec2"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------------
# APPLICATION LOAD BALANCER
# --------------------------------------------------

resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]
  subnets         = data.aws_subnets.default.ids

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# --------------------------------------------------
# TARGET GROUP
# --------------------------------------------------

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# --------------------------------------------------
# ALB LISTENER
# --------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --------------------------------------------------
# AUTO SCALING GROUP
# --------------------------------------------------

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.app.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ec2"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.http]
}

# --------------------------------------------------
# OUTPUTS
# --------------------------------------------------

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "Application URL"
  value       = "http://${aws_lb.app.dns_name}"
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  value = aws_security_group.ec2.id
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.app.name
}
