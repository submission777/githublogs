output "api_base_url" {
  #value = "${aws_apigatewayv2_stage.lambda.invoke_url}/"
  value = "${aws_api_gateway_deployment.deployment.invoke_url}/${aws_api_gateway_resource.resource.path_part}"
}

output "db_name" {
  value =  aws_dynamodb_table.saved_logs.name
}
