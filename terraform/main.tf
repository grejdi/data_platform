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

# resource "aws_sqs_queue" "data_platform_incoming" {
#   name                      = "data_platform_incoming"
#   message_retention_seconds = 604800 # 7 days
# }
# resource "aws_sqs_queue_policy" "data_platform_incoming" {
#   queue_url = aws_sqs_queue.data_platform_incoming.id

#   policy = <<POLICY
# {
#   "Id": "sqspolicy",
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "first",
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "events.amazonaws.com"
#       },
#       "Action": "sqs:SendMessage",
#       "Resource": "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:data_platform_incoming",
#       "Condition": {
#         "ArnEquals": {
#           "aws:SourceArn": "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/data_platform_incoming"
#         }
#       }
#     }
#   ]
# }
# POLICY
# }

resource "aws_cloudwatch_event_target" "data_platform_incoming" {
  target_id = "data_platform_incoming"
  rule      = aws_cloudwatch_event_rule.data_platform_incoming.name
  arn       = aws_lambda_function.data_platform_process_incoming.arn
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

resource "aws_sfn_state_machine" "data_platform_ingest" {
  name     = "data_platform_ingest"
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

resource "aws_cloudwatch_log_group" "data_platform_ecs" {
  name              = "/ecs/data_platform"
  retention_in_days = 30
  tags              = {}
}

resource "aws_cloudwatch_log_group" "data_platform_lambda_processing_incoming" {
  name              = "/aws/lambda/data_platform_process_incoming"
  retention_in_days = 30
  tags              = {}
}

resource "aws_cloudwatch_log_group" "data_platform_glue_job_error" {
  name              = "/aws-glue/jobs/error"
  retention_in_days = 30
  tags              = {}
}

resource "aws_cloudwatch_log_group" "data_platform_glue_job_output" {
  name              = "/aws-glue/jobs/output"
  retention_in_days = 30
  tags              = {}
}

resource "aws_cloudwatch_log_group" "data_platform_glue_job_output_v2" {
  name              = "/aws-glue/jobs/logs-v2"
  retention_in_days = 30
  tags              = {}
}





resource "aws_glue_catalog_database" "data_platform" {
  name = "data_platform"
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













