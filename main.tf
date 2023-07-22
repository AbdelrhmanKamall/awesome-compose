provider "aws" {
  region = "us-west-2"
}

# VPC for the ECS cluster
resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a new subnet within the VPC
resource "aws_subnet" "ecs_subnet" {
  vpc_id            = aws_vpc.ecs_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
}

# Create a security group to allow inbound traffic to ECS instances
resource "aws_security_group" "ecs_sg" {
  name_prefix = "ecs-sg-"

  # Rules to allow necessary inbound traffic to the ECS instances
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

# Create an ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

# Create a task definition for your Dockerized .NET project
resource "aws_ecs_task_definition" "ecs_task_definition" {
family = "my-ecs-task"

  # Use your Docker image for the .NET project
  container_definitions = jsonencode([
    {
      name  = "widebot"
      image = "docker.io/abdelrhmankamal23/aspnetapp:latest"  # Replace with your Docker image URL
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

# Create an ECS service to run the task in the cluster
resource "aws_ecs_service" "ecs_service" {
  name            = "my-ecs-service"  # Change this to your desired ECS service name
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 1
  launch_type     = "EC2"

  # Configure the ECS service to use the specified subnet and security group
  network_configuration {
    subnets         = [aws_subnet.ecs_subnet.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }
}

# Create an Amazon Route 53 hosted zone for your domain
resource "aws_route53_zone" "my_domain_zone" {
  name = "widebotintern.com"
}

# Create an Amazon Certificate Manager (ACM) certificate for your domain
resource "aws_acm_certificate" "my_domain_cert" {
  domain_name       = "widebotintern.com"  # Replace with your domain name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  # Use DNS validation to obtain the SSL certificate
  tags = {
    Name = "my-domain-certificate"
  }
}

# Validate the ACM certificate using DNS records in Route 53
resource "aws_route53_record" "validation_record" {
  name    = aws_acm_certificate.my_domain_cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.my_domain_cert.domain_validation_options.0.resource_record_type
  zone_id = aws_route53_zone.my_domain_zone.zone_id
  records = [aws_acm_certificate.my_domain_cert.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

# Wait for the ACM certificate to be issued
resource "aws_acm_certificate_validation" "my_domain_validation" {
  certificate_arn         = aws_acm_certificate.my_domain_cert.arn
  validation_record_fqdns = [aws_route53_record.validation_record.fqdn]
}

# Create an Elastic Load Balancer (ELB) to terminate SSL
resource "aws_lb" "my_load_balancer" {
  name               = "my-ecs-lb"
  subnets            = [aws_subnet.ecs_subnet.id]
  security_groups    = [aws_security_group.ecs_sg.id]
  load_balancer_type = "network"
}

# Create a listener for the ELB to handle HTTPS traffic
resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = 443
  protocol          = "TLS"
  certificate_arn   = aws_acm_certificate.my_domain_cert.arn
}

# Add the ECS service to the target group of the ELB
resource "aws_lb_target_group" "ecs_target_group" {
  name     = "my-ecs-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.ecs_vpc.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }
}

# Add a Launch Configuration for Auto Scaling
resource "aws_launch_configuration" "ecs_launch_configuration" {
  name_prefix          = "ecs-launch-configuration-"
  image_id             = "ami-xxxxxxxxxxxxxxxxx"  # Replace with the AMI ID for your EC2 instances
  instance_type        = "t2.micro"  # Replace with your desired instance type
  security_groups      = [aws_security_group.ecs_sg.id]
  iam_instance_profile = "ecs-instance-profile"  # Replace with the IAM instance profile with necessary permissions for ECS

  lifecycle {
    create_before_destroy = true
  }
}

# Add an Auto Scaling Group to manage the number of instances
resource "aws_autoscaling_group" "ecs_autoscaling_group" {
  name                 = "my-ecs-autoscaling-group"
  launch_configuration = aws_launch_configuration.ecs_launch_configuration.name
  vpc_zone_identifier  = [aws_subnet.ecs_subnet.id]
  min_size             = 1
  desired_capacity     = 2  # Replace with your desired capacity
  max_size             = 5  # Replace with your maximum capacity
}

# Provision an Amazon RDS instance for SQL Server
resource "aws_db_instance" "sql_server_db_instance" {
  identifier            = "my-sql-server-db"
  engine                = "sqlserver-se"
  instance_class        = "db.t2.micro"  # Replace with your desired instance type
  allocated_storage     = 20  # Replace with your desired storage size (in GB)
  engine_version        = "14.00.3429.8.v1"  # Replace with the SQL Server version
  name                  = "my_database_name"  # Replace with your database name
  username              = "db_admin"  # Replace with your database username
  password              = "db_admin_password"  # Replace with your database password
  publicly_accessible  = false  # Change to true if you need external access
  multi_az             = false
}

# Provision an Amazon DocumentDB (MongoDB) instance
resource "aws_docdb_cluster_instance" "mongodb_instance" {
  count                = 1
  cluster_identifier   = "my-mongodb-cluster"
  instance_class       = "db.t2.micro"  # Replace with your desired instance type
  identifier_suffix    = "1"  # Increment for each additional instance
}

# Provision an Amazon ElastiCache Redis cluster
resource "aws_elasticache_cluster" "redis_cluster" {
  cluster_id           = "my-redis-cluster"
  engine_version       = "5.0.6"
  node_type            = "cache.t2.micro"  # Replace with your desired instance type
  num_cache_nodes      = 1  # Replace with your desired number of nodes
}


# Attach the Load Balancer to the Auto Scaling Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.ecs_autoscaling_group.name
  alb_target_group_arn   = aws_lb_target_group.ecs_target_group.arn
}

# Define DNS records for your domain
resource "aws_route53_record" "domain_record" {
  zone_id = aws_route53_zone.my_domain_zone.zone_id
  name    = "widebotintern.com"  # Replace with your domain name
  type    = "A"
  alias {
    name                   = aws_lb.my_load_balancer.dns_name
    zone_id                = aws_lb.my_load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_listener_rule" "ecs_listener_rule" {
  listener_arn = aws_lb_listener.my_lb_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
  }

  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}
