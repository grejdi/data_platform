
# create an empty lambda function code for deployment purposes
# note: this will be updated by github actions after initial deployment
data "archive_file" "data_platform_process_incoming" {
  type        = "zip"
  output_path = "lambda_packages/data_platform_process_incoming.zip"

  source {
    content  = <<EOF
def run(event, context):
  return {}
EOF
    filename = "process_incoming.py"
  }
}

data "archive_file" "data_platform_process_ingestion" {
  type        = "zip"
  output_path = "lambda_packages/data_platform_process_ingestion.zip"

  source {
    content  = <<EOF
def run(event, context):
  return {}
EOF
    filename = "process_ingestion.py"
  }
}

resource "aws_lambda_function" "data_platform_process_incoming" {
  filename = "${data.archive_file.data_platform_process_incoming.output_path}"
  function_name = "data_platform_process_incoming"
  role = aws_iam_role.data_platform_lambda.arn
  handler = "process_incoming.run"
  runtime = "python3.7"
  timeout = 30

  vpc_config {
    subnet_ids         = [aws_subnet.data_platform.id]
    security_group_ids = [aws_security_group.data_platform.id]
  }

  environment {
    variables = {
      ENV = "main"
      DB_HOST = "${aws_db_proxy.data_platform.endpoint}"
      DB_PORT = "5432"
      DB_USER = "postgres"
      DB_NAME = "dataplatform"
      GLUE_DATABASE_NAME = "${aws_glue_catalog_database.data_platform.name}"
      INGEST_STEP_FUNCTION_ARN = "${aws_sfn_state_machine.data_platform_ingest.arn}"
      S3_BUCKET = "${aws_s3_bucket.data_platform.id}"
    }
  }
}
resource "aws_lambda_permission" "data_platform_process_incoming" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_platform_process_incoming.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_platform_incoming.arn
}
# @todo https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_event_invoke_config

resource "aws_lambda_function" "data_platform_process_ingestion" {
  filename = "${data.archive_file.data_platform_process_ingestion.output_path}"
  function_name = "data_platform_process_ingestion"
  role = aws_iam_role.data_platform_lambda.arn
  handler = "process_ingestion.run"
  runtime = "python3.7"
  timeout = 30

  vpc_config {
    subnet_ids         = [aws_subnet.data_platform.id]
    security_group_ids = [aws_security_group.data_platform.id]
  }

  environment {
    variables = {
      ENV = "main"
      DB_HOST = "${aws_db_proxy.data_platform.endpoint}"
      DB_PORT = "5432"
      DB_USER = "postgres"
      DB_NAME = "dataplatform"
      GLUE_DATABASE_NAME = "${aws_glue_catalog_database.data_platform.name}"
      INGEST_STEP_FUNCTION_ARN = "${aws_sfn_state_machine.data_platform_ingest.arn}"
      S3_BUCKET = "${aws_s3_bucket.data_platform.id}"
    }
  }
}
resource "aws_lambda_permission" "data_platform_process_ingestion" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_platform_process_ingestion.function_name
  principal     = "states.amazonaws.com"
  source_arn    = aws_sfn_state_machine.data_platform_ingest.arn
}
# @todo https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_event_invoke_config
