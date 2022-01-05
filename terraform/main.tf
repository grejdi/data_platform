# init
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

# data
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_s3_bucket" "data_platform" {
  bucket = "grejdi.data-platform"
}

# ecs.tf
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

# glue.tf
resource "aws_cloudtrail" "data_platform_incoming" {
  name = "data_platform_incoming"

  s3_bucket_name = data.aws_s3_bucket.data_platform.id
  s3_key_prefix  = "cloudtrail/incoming"

  advanced_event_selector {
    name = "Log all object PUTs in 'incoming/'"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    field_selector {
      field       = "resources.ARN"
      starts_with = ["${data.aws_s3_bucket.data_platform.arn}/incoming/"]
    }

    field_selector {
      field  = "eventName"
      equals = ["PutObject"]
    }
  }
}

resource "aws_cloudwatch_event_target" "data_platform_incoming" {
  target_id = "data_platform_incoming"
  rule      = aws_cloudwatch_event_rule.data_platform_incoming.name
  arn       = aws_sfn_state_machine.data_platform_incoming.arn
  role_arn  = aws_iam_role.data_platform_eventbridge.arn
}
resource "aws_cloudwatch_event_rule" "data_platform_incoming" {
  name = "data_platform_incoming"
  description = "Capture S3 events on object keys starting with 'incoming/' in bucket."

  event_pattern = <<PATTERN
{
  "source": ["aws.s3"],
  "detail": {
    "requestParameters": {
      "key": [{
        "prefix": "incoming/"
      }]
    }
  }
}
PATTERN
}

resource "aws_sfn_state_machine" "data_platform_incoming" {
  name     = "data_platform_incoming"
  role_arn = aws_iam_role.data_platform_stepfunctions.arn

  definition = <<EOF
{
  "StartAt": "Glue StartJobRun",
  "States": {
    "Glue StartJobRun": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startJobRun.sync",
      "Parameters": {
        "JobName": "data_platform_incoming",
        "Arguments": {
          "--OBJECT_KEY.$": "$.detail.requestParameters.key",
          "--extra-py-files": "s3://grejdi.data-platform/operations/packages/data_platform.zip",
          "--additional-python-modules": "logging_tree==1.9"
        }
      },
      "End": true,
      "Retry": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "BackoffRate": 1,
          "IntervalSeconds": 5,
          "MaxAttempts": 3
        }
      ]
    }
  }
}
EOF
}

resource "aws_cloudwatch_log_group" "data_platform_incoming_ecs" {
  name              = "/ecs/data_platform"
  retention_in_days = 30
  tags              = {}
}

resource "aws_cloudwatch_log_group" "data_platform_incoming_glue_job_error" {
  name              = "/aws-glue/jobs/error"
  retention_in_days = 30
  tags              = {}
}

resource "aws_cloudwatch_log_group" "data_platform_incoming_glue_job_output" {
  name              = "/aws-glue/jobs/output"
  retention_in_days = 30
  tags              = {}
}

resource "aws_glue_job" "data_platform_incoming" {
  name              = "data_platform_incoming"
  role_arn          = aws_iam_role.data_platform_glue.arn
  glue_version      = "2.0"
  number_of_workers = 10
  worker_type       = "G.1X"

  command {
    script_location = "s3://${aws_s3_bucket.data_platform.id}/operations/jobs/incoming.py"
  }
}

# s3.tf
resource "aws_s3_bucket" "data_platform" {
  bucket = "grejdi.data-platform"
  acl    = "private"
  tags   = {}

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck20150319",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "${data.aws_s3_bucket.data_platform.arn}"
    },
    {
      "Sid": "AWSCloudTrailWrite20150319",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "${data.aws_s3_bucket.data_platform.arn}/cloudtrail/incoming/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control",
          "AWS:SourceArn": "${aws_cloudtrail.data_platform_incoming.arn}"
        }
      }
    }
  ]
}
POLICY
}


