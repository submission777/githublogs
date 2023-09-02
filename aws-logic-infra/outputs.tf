output "api_base_url" {
  value = "${aws_apigatewayv2_stage.lambda.invoke_url}/"
}

output "db_name" {
  value =  aws_dynamodb_table.saved_logs.name
}
