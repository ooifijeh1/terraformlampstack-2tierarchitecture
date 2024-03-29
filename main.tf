#Define the provider within Terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }
  }
}

#Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

#Create the VPC
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    name = "vpc"
  }
}

#Create the Public Subnets
resource "aws_subnet" "publicsub-1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    name = "public_1"
  }

}

resource "aws_subnet" "publicsub-2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    name = "public_2"
  }
}

#Create the Private Subnets
resource "aws_subnet" "privatesub-1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    name = "privates_1"
  }
}
resource "aws_subnet" "privatesub-2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    name = "privates_2"

  }
}

#Create Internet Gateway
resource "aws_internet_gateway" "Internet-gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    name = "Internet_gateway"
  }
}

#Create the Route Table to the Internet Gateway
resource "aws_route_table" "project-rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Internet-gateway.id
  }

  tags = {
    name = "project-rt"
  }
}

#Connect the Public Subnets to the Route Table
resource "aws_route_table_association" "public_route_1" {
  subnet_id      = aws_subnet.publicsub-1.id
  route_table_id = aws_route_table.project-rt.id
}

resource "aws_route_table_association" "public_route_2" {
  subnet_id      = aws_subnet.publicsub-2.id
  route_table_id = aws_route_table.project-rt.id
}

#Create the Security Group for the Public and Private
resource "aws_security_group" "ifijehpublic-sg" {
  name        = "ifijehpublic-sg"
  description = "Allow web and ssh traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

resource "aws_security_group" "ifijehprivate-sg" {
  name        = "ifijehprivate-sg"
  description = "Allow web tier and ssh traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/16"]
    security_groups = [aws_security_group.ifijehpublic-sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}
#Configure the Security Group for ALB
resource "aws_security_group" "ifijehlbalancer-sg" {
  name        = "ifijehlbalancer-sg"
  description = "security group for ifijehlbalancer"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create the ALB
resource "aws_lb" "project-ifijehlbalancer" {
  name               = "ifijehlbalancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ifijehlbalancer-sg.id]
  subnets            = [aws_subnet.publicsub-1.id, aws_subnet.publicsub-2.id]
}

#Create the ALB target group
resource "aws_lb_target_group" "project-tg" {
  name     = "project-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  depends_on = [aws_vpc.vpc]
}

# Create the target attachments
resource "aws_lb_target_group_attachment" "tg_attach1" {
  target_group_arn = aws_lb_target_group.project-tg.arn
  target_id        = aws_instance.web1.id
  port             = 80

  depends_on = [aws_instance.web1]
}

resource "aws_lb_target_group_attachment" "tg_attach2" {
  target_group_arn = aws_lb_target_group.project-tg.arn
  target_id        = aws_instance.web2.id
  port             = 80

  depends_on = [aws_instance.web2]
}

# Create the listener
resource "aws_lb_listener" "listener_lb" {
  load_balancer_arn = aws_lb.project-ifijehlbalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.project-tg.arn
  }
}
#Create the EC2 Instances
resource "aws_instance" "web1" {
  ami                         = "ami-0093a6022697a73aa"
  instance_type               = "t2.micro"
  availability_zone           = "us-east-1a"
  vpc_security_group_ids      = [aws_security_group.ifijehpublic-sg.id]
  subnet_id                   = aws_subnet.publicsub-1.id
  associate_public_ip_address = true
  user_data                   = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Hey lets get our hands dirty on terraform, All the way from frisco city</h1></body></html>" > /var/www/html/index.html
        EOF

  tags = {
    Name = "instance-1"
  }
}
resource "aws_instance" "web2" {
  ami                         = "ami-0093a6022697a73aa"
  instance_type               = "t2.micro"
  availability_zone           = "us-east-1b"
  vpc_security_group_ids      = [aws_security_group.ifijehpublic-sg.id]
  subnet_id                   = aws_subnet.publicsub-2.id
  associate_public_ip_address = true
  user_data                   = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>hello from frisco city!</h1></body></html>" > /var/www/html/index.html
        EOF

  tags = {
    Name = "instance-2"
  }
}
#Configure the Data Base Private Subnet Group
resource "aws_db_subnet_group" "db-subnet" {
  name       = "db-subnet"
  subnet_ids = [aws_subnet.privatesub-1.id, aws_subnet.privatesub-2.id]
}

# Create the Data Base Instance
resource "aws_db_instance" "project-db" {
  allocated_storage      = 5
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  identifier             = "db-instance"
  db_name                = "project_db"
  username               = "admin"
  password               = "password"
  db_subnet_group_name   = aws_db_subnet_group.db-subnet.id
  vpc_security_group_ids = [aws_security_group.ifijehprivate-sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}