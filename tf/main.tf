terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.30.0"
    }
  }

  backend "s3" {
    bucket = "loay-tfstat-file"
    key    = "tfstate.json"
    region = "eu-west-1"
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "loay-PolybotServiceVPC-tf"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "loay-PolybotServiceIGW-tf"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "loay-PolybotServiceRT-tf"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.main.id
  depends_on     = [aws_internet_gateway.main]
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.main.id
  depends_on     = [aws_internet_gateway.main]
}

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[0]
  availability_zone       = var.availability_zone[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "loay-public-subnet1-tf"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[1]
  availability_zone       = var.availability_zone[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "loay-public-subnet2-tf"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "polybot_bucket" {
  bucket = "loayk-bucket-tf"

  tags = {
    Name      = "loayk-bucket-tf"
    Terraform = "true"
  }
}

resource "aws_secretsmanager_secret" "telegram_token" {
  name = "loay2_telegram_token_tf"  # Replace with your desired secret name
  description = "Telegram bot token"

  # Optionally specify tags for your secret
  tags = {
    Environment = "DevOps Learning"
    Owner       = "loay_kewan"
    Project     = "Terraform Project"
  }
}
resource "aws_secretsmanager_secret_version" "example_secret_version" {
  secret_id     = aws_secretsmanager_secret.telegram_token.id
  secret_string = jsonencode({
    loay2_telegram_token_tf = var.telegram_token
  })
}


module "polybot" {
  source               = "./modules/polybot"
  vpc_id               = aws_vpc.main.id
  public_subnet_ids    = [aws_subnet.public1.id, aws_subnet.public2.id]
  instance_ami_polybot = var.instance_ami_polybot
  instance_type_polybot = var.instance_type_polybot
  key_pair_name_polybot = var.key_pair_name_polybot
  iam_role_name         = var.iam_role_name_polybot
  certificate_arn       = var.certificate_arn
}


module "yolo5" {
  source = "./modules/yolo5"

  instance_ami_yolo5     = var.instance_ami_yolo5
  instance_type_yolo5    = var.instance_type_yolo5
  key_pair_name_yolo5    = var.key_pair_name_yolo5
  vpc_id                 = aws_vpc.main.id
  public_subnet_ids      = [aws_subnet.public1.id, aws_subnet.public2.id]
  asg_min_size           = 1
  asg_max_size           = 2
  asg_desired_capacity   = 1
 cpu_utilization_high_threshold = 60  # Example: Set your desired thresholds
  cpu_utilization_low_threshold  = 30  # Example: Set your desired thresholds
  scale_out_cooldown         = 300  # Example: Set your cooldown periods
  scale_in_cooldown          = 300  # Example: Set your cooldown periods
}