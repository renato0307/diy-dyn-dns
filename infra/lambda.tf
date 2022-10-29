resource "aws_ssm_parameter" "api_key" {
  name  = "${local.app_id}-api-key"
  type  = "SecureString"
  value = var.api_key
}

resource "aws_lambda_function" "lambda_func" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.app_id
  handler          = "app"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "go1.x"
  source_code_hash = base64sha256(data.archive_file.lambda_zip.output_path)

  environment {
    variables = {
      API_KEY_PARAM_NAME = aws_ssm_parameter.api_key.name
      DNS_DYN_RECORD_NAME = var.dns_dyn_record_name
      DNS_HOSTED_ZONE = var.dns_hosted_zone
    }
  }
}

# Assume role setup
resource "aws_iam_role" "lambda_exec" {
  name_prefix = local.app_id

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

# Attach role to Managed Policy
variable "iam_policy_arn" {
  description = "IAM Policy to be attached to role"
  type        = list(string)

  default = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

resource "aws_iam_policy_attachment" "role_attach" {
  name       = "policy-${local.app_id}"
  roles      = [aws_iam_role.lambda_exec.id]
  count      = length(var.iam_policy_arn)
  policy_arn = element(var.iam_policy_arn, count.index)
}


# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_other_permission" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "${aws_ssm_parameter.api_key.arn}",
      "Effect": "Allow"
    },
    {
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/${var.dns_hosted_zone}",
      "Effect": "Allow"
    }    
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_other_permission.arn
}


resource "aws_lambda_function_url" "test_live" {
  function_name      = aws_lambda_function.lambda_func.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["date", "keep-alive", "authorization"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}