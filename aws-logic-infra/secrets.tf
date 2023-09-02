resource "aws_ssm_parameter" "github_api_token" {
  name = "/github-secrets/github-token"
  type = "String"
  value = var.github_api_token
}

resource "aws_ssm_parameter" "webhook_secret" {
  name = "/github-secrets/webhook-secret"
  type = "String"
  value = var.github_webhook_secret
}

