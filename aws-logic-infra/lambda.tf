data "archive_file" "func_zip" {
  type = "zip"
  source_file = "../function-python/function.py"
  output_path = "function.zip"
}

data "aws_iam_policy_document" "policy_for_execution" {
  statement {
    sid = ""
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "policy_dynamodb_access" {
  statement {
    sid = ""
    effect = "Allow"
    actions = ["dynamodb:*"]
    resources =[aws_dynamodb_table.saved_logs.arn]
  }
}

data "aws_iam_policy_document" "policy_parameter_store_access" {
  statement {
    sid = ""
    effect = "Allow"
    actions = ["ssm:Describe*", "ssm:Get*", "ssm:List*"]
    resources = [aws_ssm_parameter.github_api_token.arn,aws_ssm_parameter.webhook_secret.arn]
  }
}

data "aws_iam_policy_document" "policy_cloudwatch_access" {
  statement {
    sid = ""
    effect = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "lambda_cloudwatch_policy" {
  name = "cloudwatch_for_lambda_policy"
  policy = data.aws_iam_policy_document.policy_cloudwatch_access.json
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "dynamodb_for_lambda_policy"
  policy = data.aws_iam_policy_document.policy_dynamodb_access.json
}

resource "aws_iam_policy" "lambda_store_policy" {
  name = "ssm_for_lambda_policy"
  policy = data.aws_iam_policy_document.policy_parameter_store_access.json
}

resource "aws_iam_role" "lambda_role" {
  name = "files_logger_lambda_role"
  description = "role for the lambda with all permissions"
  assume_role_policy = data.aws_iam_policy_document.policy_for_execution.json
}

resource "aws_iam_role_policy_attachment" "dynamodb_attachment" {
  role = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}
resource "aws_iam_role_policy_attachment" "cloudwatch_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_policy.arn
}
resource "aws_iam_role_policy_attachment" "store_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_store_policy.arn
}

resource "aws_lambda_function" "lambda" {
  environment {
    variables = {
      dynamodb_table_name = aws_dynamodb_table.saved_logs.name
      github_api_token_path = aws_ssm_parameter.github_api_token.name
      github_secret_path = aws_ssm_parameter.webhook_secret.name
      dynamodb_region_name = var.aws_region
      secret_manager_region_name = var.aws_region
    }
  }
  function_name = "github_log_creator"
  role = aws_iam_role.lambda_role.arn
  handler = "function.lambda_handler"
  architectures = ["x86_64"]
  runtime = "python3.9"
  filename = data.archive_file.func_zip.output_path
  source_code_hash = data.archive_file.func_zip.output_base64sha256
  layers = [aws_lambda_layer_version.github_trigger_layer.arn]
}

resource "aws_lambda_layer_version" "github_trigger_layer" {
  layer_name = "github_trigger_layer"
  filename = "../function-python/requests.zip"
}

resource "aws_cloudwatch_log_group" "handler_lambda"{
  name = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
}

