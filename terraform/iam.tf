
resource "aws_iam_role" "data_platform_rds_proxy" {
  name = "data_platform_rds_proxy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "data_platform_rds_proxy_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"

      Statement = [
        {
          Action   = "secretsmanager:GetSecretValue"
          Effect   = "Allow"
          Resource = aws_secretsmanager_secret.data_platform_db.arn
        }
      ]
    })
  }
}

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
          Action   = "lambda:InvokeFunction"
          Effect   = "Allow"
          Resource = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:data_platform"
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

resource "aws_iam_role" "data_platform_glue" {
  name = "data_platform_glue"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "data_platform_glue_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"

      Statement = [
        {
          Action   = [
            "glue:*"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = [
            "s3:ListBucket"
          ]
          Effect   = "Allow"
          Resource = aws_s3_bucket.data_platform.arn
        },
        {
          Action   = [
            "s3:GetObject"
          ]
          Effect   = "Allow"
          Resource = [
            "${aws_s3_bucket.data_platform.arn}/incoming/*",
            "${aws_s3_bucket.data_platform.arn}/operations/*"
          ]
        },
        {
          Action   = [
            "s3:PutObject",
            "s3:PutObjectAcl"
          ]
          Effect   = "Allow"
          Resource = "${aws_s3_bucket.data_platform.arn}/output/*"
        },
        {
          Action   = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Effect   = "Allow"
          Resource = [
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*"
          ]
        }
      ]
    })
  }
}

resource "aws_iam_role" "data_platform_ecs_execution" {
  name = "data_platform_ecs_execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "data_platform_ecs_execution_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"

      Statement = [
        {
          Action   = "rds-db:connect"
          Effect   = "Allow"
          Resource = "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:prx-0294a7e8e8a2755e4/*"
        },
        {
          Action   = [
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer"
          ]
          Effect   = "Allow"
          Resource = aws_ecr_repository.data_platform.arn
        },
        {
          Action   = [
            "ecr:GetAuthorizationToken"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Effect   = "Allow"
          Resource = [
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/*"
          ]
        }
      ]
    })
  }
}

resource "aws_iam_role" "data_platform_ecs_task" {
  name = "data_platform_ecs_task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "data_platform_ecs_task_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"

      Statement = [
        {
          Action   = "rds-db:connect"
          Effect   = "Allow"
          Resource = "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:prx-0294a7e8e8a2755e4/*"
        },
        {
          Action   = "states:StartExecution"
          Effect   = "Allow"
          Resource = "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:data_platform_incoming"
        },
        {
          Action   = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Effect   = "Allow"
          Resource = [
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/*"
          ]
        },
        {
          Action   = [
            "sqs:DeleteMessage",
            "sqs:ReceiveMessage",
          ]
          Effect   = "Allow"
          Resource = "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:data_platform_incoming"
        }
      ]
    })
  }
}

resource "aws_iam_role" "data_platform_lambda" {
  name = "data_platform_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "data_platform_lambda_inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"

      Statement = [
        {
          Action   = "rds-db:connect"
          Effect   = "Allow"
          Resource = "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:prx-0294a7e8e8a2755e4/*"
        },
        {
          Action   = [
            "logs:CreateLogStream",
            "logs:DescribeLogStreams",
            "logs:PutLogEvents"
          ]
          Effect   = "Allow"
          Resource = [
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/data_platform*"
          ]
        },
        {
          Action   = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface"
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
        Resource = aws_ecr_repository.data_platform.arn
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
        Resource = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task-definition/dataplatform"
      },
      {
        Effect   = "Allow",
        Action   = [
          "ecs:DescribeTasks"
        ],
        Resource = "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:task/dataplatform/*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "iam:PassRole"
        ],
        Resource = [
          aws_iam_role.data_platform_ecs_execution.arn,
          aws_iam_role.data_platform_ecs_task.arn
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:ListBucket"
        ],
        Resource = aws_s3_bucket.data_platform.arn
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = "${aws_s3_bucket.data_platform.arn}/operations/*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "lambda:UpdateFunctionCode"
        ],
        Resource = aws_lambda_function.data_platform_process_incoming.arn
      }
    ]
  })
}

