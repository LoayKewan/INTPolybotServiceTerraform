# EC2 Instances
resource "aws_instance" "polybot_instance1" {
  ami                    = var.instance_ami_polybot
  instance_type          = var.instance_type_polybot
  key_name               = var.key_pair_name_polybot
  subnet_id              = var.public_subnet_ids[0]
  security_groups        = [aws_security_group.polybot_sg.id]
  associate_public_ip_address = true
  user_data              = base64encode(file("${path.module}/user_data_polybot.sh"))
  iam_instance_profile   = aws_iam_instance_profile.polybot_instance_profile.name

  tags = {
    Name      = "loay-PolybotService1-tf"
    Terraform = "true"
  }
}

resource "aws_instance" "polybot_instance2" {
  ami                    = var.instance_ami_polybot
  instance_type          = var.instance_type_polybot
  key_name               = var.key_pair_name_polybot
  subnet_id              = var.public_subnet_ids[1]
  security_groups        = [aws_security_group.polybot_sg.id]
  associate_public_ip_address = true
  user_data              = base64encode(file("${path.module}/user_data_polybot.sh"))
  iam_instance_profile   = aws_iam_instance_profile.polybot_instance_profile.name

  tags = {
    Name      = "loay-PolybotService2-tf"
    Terraform = "true"
  }
}

# IAM Role and Policies
resource "aws_iam_role" "polybot_service_role" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_full_access" {
  role       = aws_iam_role.polybot_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.polybot_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "sqs_full_access" {
  role       = aws_iam_role.polybot_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "secrets_manager_rw" {
  role       = aws_iam_role.polybot_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}


resource "aws_iam_instance_profile" "polybot_instance_profile" {
  name = var.iam_role_name
  role = aws_iam_role.polybot_service_role.name
}

# Security Group
resource "aws_security_group" "polybot_sg" {
  name        = "loay_polybot_sg-tf"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access from anywhere"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from anywhere"
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow application-specific traffic"
  }


  ingress {
   from_port   = 8443
   to_port     = 8443
   protocol    = "tcp"
   security_groups = [aws_security_group.polybot_sg.id] # this may vary; adjust as necessary.
   description = "Allow traffic from load balancer"
}


  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic from anywhere"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
}


# Load Balancer
resource "aws_lb" "polybot_alb" {
  name               = "loay-PolybotServiceLB-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.polybot_sg.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name      = "loay-PolybotServiceLB-tf"
    Terraform = "true"
  }
}

# Target Group
resource "aws_lb_target_group" "polybot_tg" {
  name     = "loay-polybot-target-group-tf"
  port     = 8443
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name      = "loay-polybot-target-group-tf"
    Terraform = "true"
  }
}


resource "aws_lb_listener" "polybot_listener_8443" {
  load_balancer_arn = aws_lb.polybot_alb.arn
  port              = 8443
  protocol          = "HTTP"
  #certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.polybot_tg.arn
  }
}

resource "aws_lb_listener" "polybot_listener_443" {
  load_balancer_arn = aws_lb.polybot_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.polybot_tg.arn
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "polybot_instance1_attachment" {
  target_group_arn = aws_lb_target_group.polybot_tg.arn
  target_id        = aws_instance.polybot_instance1.id
  port             = 8443
}

resource "aws_lb_target_group_attachment" "polybot_instance2_attachment" {
  target_group_arn = aws_lb_target_group.polybot_tg.arn
  target_id        = aws_instance.polybot_instance2.id
  port             = 8443
}

# SQS Queue and Policy
resource "aws_sqs_queue" "polybot_queue" {
  name = "loay-PolybotServiceQueue-tf"
  tags = {
    Name      = "loay-PolybotServiceQueue-tf"
    Terraform = "true"
  }
}

resource "aws_sqs_queue_policy" "polybot_queue_policy" {
  queue_url = aws_sqs_queue.polybot_queue.id


  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "__default_policy_ID"
    Statement = [
      {
        Sid       = "__owner_statement"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::019273956931:root"
        }
        Action   = "SQS:*"
        Resource = aws_sqs_queue.polybot_queue.arn
      }
    ]
  })
}