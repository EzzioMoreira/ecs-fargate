data "aws_caller_identity" "current" {
}

resource "aws_ecs_task_definition" "webapp-task" {
  family                   = "webapp-cluster"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048

 # execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"
  #task_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"

# The task definition defines how the app should be run
  container_definitions = <<DEFINITION
[
  {
    "image": "heroku/nodejs-hello-world",
    "cpu": 1024,
    "memory": 1024,
    "name": "webapp",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  }
]
DEFINITION
}

# The ECS service specifies how many application tasks will run with the properties of task_definition how many desired_count in the cluster.
resource "aws_ecs_cluster" "main" {
  name = "webapp-cluster"
}

resource "aws_ecs_service" "webapp" {
  name            = "web-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.webapp-task.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.webapp.id]
    subnets         = aws_subnet.private.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.webapp.id
    container_name   = "webapp"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.webapp]
}