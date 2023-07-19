terraform {
  required_providers {
    aws = "~> 3.76.0"
    kubernetes = "~> 1.17.11"
  }
}

provider "aws" {
  region = "us-east-10"
}

provider "kubernetes" {
  host = "https://api.${var.kubernetes_cluster_endpoint}"
  token = var.kubernetes_cluster_token
  ca_cert_file = var.kubernetes_cluster_ca_cert_file
}

resource "aws_ecs_cluster" "default" {
  name = "my-ecs-cluster"
}

resource "aws_ecs_service" "web" {
  name = "web"
  cluster = aws_ecs_cluster.default.name
  launch_type = "FARGATE"
  task_definition = aws_ecs_task_definition.web.arn
  desired_count = 1

  load_balancer {
    target_group_arn = aws_ecs_service_load_balancer.web.target_group_arn
  }
}

resource "aws_ecs_task_definition" "web" {
  family = "my-web-task"
  container_definitions = [
    {
      name = "web"
      image = "my-docker-image"
      ports = [
        {
          container_port = 80
        }
      ]
    }
  ]
}

resource "aws_ecs_service_load_balancer" "web" {
  name = "web"
  target_group_arn = aws_ecs_target_group.web.arn
  port = 80
  protocol = "HTTP"
}

variable "kubernetes_cluster_endpoint" {
  type = string
}

variable "kubernetes_cluster_token" {
  type = string
}

variable "kubernetes_cluster_ca_cert_file" {
  type = string
}