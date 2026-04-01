resource "aws_cloudwatch_log_group" "services" {
  for_each          = local.ecs_workloads
  name              = "/ecs/${var.project_name}/${each.key}"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = var.service_discovery_namespace
  vpc  = aws_vpc.main.id
}

resource "aws_service_discovery_service" "services" {
  for_each = {
    for service, config in local.ecs_workloads : service => config if config.service_discovery
  }

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow public traffic to the storefront ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow ALB and east-west traffic to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Storefront traffic from the ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Service-to-service traffic within the VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "frontend" {
  name               = substr("${var.project_name}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "frontend" {
  name        = substr("${var.project_name}-fe-tg", 0, 32)
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/_healthz"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_ecr_repository" "services" {
  for_each             = local.ecr_services
  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_task_definition" "services" {
  for_each = local.ecs_workloads

  family                   = "${var.project_name}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(each.value.cpu)
  memory                   = tostring(each.value.memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    merge(
      {
        name      = each.key
        image     = contains(keys(local.public_images), each.key) ? local.public_images[each.key] : "${aws_ecr_repository.services[each.key].repository_url}:latest"
        essential = true
        environment = [
          for env_name, env_value in each.value.environment : {
            name  = env_name
            value = env_value
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.services[each.key].name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = each.key
          }
        }
      },
      each.value.port == null ? {} : {
        portMappings = [
          {
            containerPort = each.value.port
            hostPort      = each.value.port
            protocol      = "tcp"
          }
        ]
      }
    )
  ])
}

resource "aws_ecs_service" "services" {
  for_each = local.ecs_workloads

  name            = "${var.project_name}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  dynamic "service_registries" {
    for_each = each.value.service_discovery ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.services[each.key].arn
    }
  }

  dynamic "load_balancer" {
    for_each = each.value.load_balanced ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.frontend.arn
      container_name   = each.key
      container_port   = each.value.port
    }
  }

  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition]
  }
}
