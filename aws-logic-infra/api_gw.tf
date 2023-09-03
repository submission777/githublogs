resource "aws_api_gateway_rest_api" "gw_proxy" {
  name = "lambdaProxy"
  description = "Proxy to handle requests to lambda function"
}

resource "aws_api_gateway_resource" "resource" {
  parent_id   = aws_api_gateway_rest_api.gw_proxy.root_resource_id
  path_part   = aws_lambda_function.lambda.function_name
  rest_api_id = aws_api_gateway_rest_api.gw_proxy.id
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.gw_proxy.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  http_method = aws_api_gateway_method.proxy.http_method
  resource_id = aws_api_gateway_method.proxy.resource_id
  rest_api_id = aws_api_gateway_rest_api.gw_proxy.id
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri = aws_lambda_function.lambda.invoke_arn
}

data "aws_iam_policy_document" "gw_policy" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.gw_proxy.execution_arn}/*"]
  }
  statement {
    effect = "Deny"
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.gw_proxy.execution_arn}/*"]
    condition {
      test     = "NotIpAddress"
      values   = ["192.30.252.0/22", "185.199.108.0/22", "140.82.112.0/20", "143.55.64.0/20"]
      variable = "aws:SourceIp"
    }
  }
}

resource "aws_api_gateway_rest_api_policy" "github_only" {
  policy      = data.aws_iam_policy_document.gw_policy.json
  rest_api_id = aws_api_gateway_rest_api.gw_proxy.id
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_rest_api_policy.github_only]
  rest_api_id = aws_api_gateway_rest_api.gw_proxy.id
  stage_name = "prod"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.gw_proxy.execution_arn}/*/*"
}
