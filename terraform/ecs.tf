
resource "aws_vpc" "data_platform" {
  cidr_block = "20.0.0.0/16"

  tags = {
    Name = "data_platform"
  }
}

resource "aws_subnet" "data_platform" {
  vpc_id            = aws_vpc.data_platform.id
  cidr_block        = "20.0.0.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "data_platform"
  }
}

resource "aws_subnet" "data_platform_d" {
  vpc_id     = aws_vpc.data_platform.id
  cidr_block = "20.0.1.0/24"
  availability_zone = "us-east-1d"

  tags = {
    Name = "data_platform"
  }
}

resource "aws_internet_gateway" "data_platform" {
  vpc_id = aws_vpc.data_platform.id

  tags = {
    Name = "data_platform"
  }
}

resource "aws_route_table" "data_platform" {
  vpc_id = aws_vpc.data_platform.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.data_platform.id
  }

  tags = {
    Name = "data_platform"
  }
}

resource "aws_route_table_association" "data_platform" {
  subnet_id      = aws_subnet.data_platform.id
  route_table_id = aws_route_table.data_platform.id
}

resource "aws_default_security_group" "data_platform_default" {
  vpc_id      = aws_vpc.data_platform.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol  = "tcp"
    from_port = 5432
    to_port   = 5432
  }

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "data_platform_default"
  }
}

resource "aws_security_group" "data_platform" {
  name        = "data_platform"
  vpc_id      = aws_vpc.data_platform.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "data_platform"
  }
}

resource "aws_vpc_endpoint" "data_platform_s3" {
  vpc_id       = aws_vpc.data_platform.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
}
resource "aws_vpc_endpoint_route_table_association" "data_platform_s3" {
  route_table_id  = aws_route_table.data_platform.id
  vpc_endpoint_id = aws_vpc_endpoint.data_platform_s3.id
}

resource "aws_ecr_repository" "data_platform" {
  name = "dataplatform"
}

resource "aws_ecs_cluster" "data_platform" {
  name = "dataplatform"
  capacity_providers = ["FARGATE"]
}

resource "aws_ecs_task_definition" "data_platform" {
  family                   = "dataplatform"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.data_platform_ecs_execution.arn
  task_role_arn            = aws_iam_role.data_platform_ecs_task.arn

  container_definitions    = <<TASK_DEFINITION
[
  {
    "name": "dataplatform",
    "image": "${aws_ecr_repository.data_platform.repository_url}:main-latest",
    "cpu": 256,
    "memory": 512,
    "essential": true,
    "environment": [
      {"name": "ENV", "value": "main"},
      {"name": "DB_HOST", "value": "${aws_db_proxy.data_platform.endpoint}"},
      {"name": "DB_PORT", "value": "5432"},
      {"name": "DB_USER", "value": "postgres"},
      {"name": "DB_NAME", "value": "dataplatform"},
      {"name": "GLUE_DATABASE_NAME", "value": "${aws_glue_catalog_database.data_platform.name}"},
      {"name": "S3_BUCKET", "value": "${aws_s3_bucket.data_platform.id}"},
      {"name": "STEP_FUNCTION_INGEST_ARN", "value": "${aws_sfn_state_machine.data_platform_ingest.arn}"}
    ],
    "logConfiguration" : {
      "logDriver" :"awslogs",
      "options" : {
          "awslogs-region"        : "${data.aws_region.current.name}",
          "awslogs-group"         : "/ecs/data_platform",
          "awslogs-stream-prefix" : "ecs"
      }
    }
  }
]
TASK_DEFINITION

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}
