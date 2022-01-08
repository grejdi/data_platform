
# create an empty lambda function code for deployment purposes
# note: this will be updated by github actions after initial deployment
data "archive_file" "data_platform" {
  type        = "zip"
  output_path = "files/data_platform.zip"

  source {
    content  = <<EOF
def lambda_handler(event, context):
  return {}
EOF
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "data_platform" {
  filename = "${data.archive_file.data_platform.output_path}"
  function_name = "data_platform"
  role = aws_iam_role.data_platform_lambda.arn
  handler = "lambda_function.lambda_handler"

  runtime = "python3.7"
}

resource "aws_lambda_permission" "data_platform_incoming" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_platform.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_platform_incoming.arn
}
