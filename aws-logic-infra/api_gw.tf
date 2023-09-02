resource "aws_apigatewayv2_api" "lambda" {
  name = "lambdaProxy"
  description = "Proxy to handle requests to lambda function"
  protocol_type = "HTTP"

  depends_on = [aws_lambda_function.lambda]
}

resource "aws_cloudwatch_log_group" "main_api_gw" {
  name = "/aws/api-gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 30
}

resource "aws_apigatewayv2_stage" "lambda" {
  name          = "lambdaProxy_stage"
  api_id        = aws_apigatewayv2_api.lambda.id
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.main_api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    }
    )
  }
}

resource "aws_apigatewayv2_integration" "integration" {
  api_id = aws_apigatewayv2_api.lambda.id
  integration_uri = aws_lambda_function.lambda.invoke_arn
  integration_type = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "route" {
  api_id      = aws_apigatewayv2_api.lambda.id
  route_key   = "POST /"
  target = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
