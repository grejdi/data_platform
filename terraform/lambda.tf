
# create an empty lambda function code for deployment purposes
# note: this will be updated by github actions after initial deployment
data "archive_file" "data_platform" {
  type        = "zip"
  output_path = "files/data_platform.zip"

  source {
    content  = <<EOF
def run(event, context):
  return {}
EOF
    filename = "process_incoming.py"
  }
}

resource "aws_lambda_function" "data_platform_process_incoming" {
  filename = "${data.archive_file.data_platform.output_path}"
  function_name = "data_platform_process_incoming"
  role = aws_iam_role.data_platform_lambda.arn
  handler = "process_incoming.run"

  runtime = "python3.7"

  environment {
    variables = {
      ENV = "main"
      DB_HOST = "${aws_db_proxy.data_platform.endpoint}"
      DB_PORT = "5432"
      DB_USER = "postgres"
      DB_NAME = "dataplatform"
      INGEST_STEP_FUNCTION_ARN = "${aws_sfn_state_machine.data_platform_ingest.arn}"
    }
  }
}

resource "aws_lambda_permission" "data_platform_process_incoming" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_platform_process_incoming.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_platform_incoming.arn
}
