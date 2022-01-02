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

# globals.tf
resource "aws_ecr_repository" "data_platform" {
  name = "data_platform"
}

# iam.tf
resource "aws_iam_role" "data_platform_eventbridge" {
  name = "data_platform_eventbridge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "data_platform_eventbridge_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"

      Statement = [
        {
          Action   = "states:StartExecution"
          Effect   = "Allow"
          Resource = "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:data_platform_incoming"
        }
      ]
    })
  }
}

resource "aws_iam_role" "data_platform_stepfunctions" {
  name = "data_platform_stepfunctions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "data_platform_stepfunctions_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"

      Statement = [
        {
          Action   = [
            "ecs:RunTask",
            "ecs:DescribeTasks",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = [
            "glue:StartJobRun",
            "glue:GetJobRun",
            "glue:GetJobRuns",
            "glue:BatchStopJobRun"
          ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_iam_user" "data_platform_github_actions" {
  name = "data_platform_github_actions"
}
resource "aws_iam_user_policy" "data_platform_github_actions_policy" {
  name = "data_platform_github_actions_policy"
  user = aws_iam_user.data_platform_github_actions.name

  policy = jsonencode({
    Version    = "2012-10-17",
    Statement = [
        {
            Effect = "Allow",
            Action = [
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:CompleteLayerUpload",
                "ecr:GetDownloadUrlForLayer",
                "ecr:InitiateLayerUpload",
                "ecr:PutImage",
                "ecr:UploadLayerPart"
            ],
            Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/data_platform"
        },
        {
            Effect   = "Allow",
            Action   = "ecr:GetAuthorizationToken",
            Resource = "*"
        },
        {
            Effect   = "Allow",
            Action   = [
                "ecs:RunTask"
            ],
            Resource = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task-definition/data_platform"
        },
        {
            Effect   = "Allow",
            Action   = [
                "iam:PassRole"
            ],
            Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/data_platform_ecs"
        },
        {
            Effect   = "Allow",
            Action   = [
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            Resource = "${aws_s3_bucket.data_platform.arn}/operations/*"
        }
    ]
  })
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
  arn       = "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:data_platform_incoming"
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
          "--OBJECT_KEY.$": "$.detail.requestParameters.key"
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

# s3.tf
resource "aws_s3_account_public_access_block" "data_platform_block" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

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
          "AWS:SourceArn": "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/data_platform_incoming"
        }
      }
    }
  ]
}
POLICY
}


