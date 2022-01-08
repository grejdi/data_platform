
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
