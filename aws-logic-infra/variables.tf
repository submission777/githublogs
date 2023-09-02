variable "github_api_token" {
  type = string
  description = "The token to github api"
  sensitive = true
}

variable "github_webhook_secret" {
  type = string
  description = "The secret to github webhook"
  sensitive = true
}

variable "aws_region" {
  type = string
}

variable "db_name" {
  type = string
  default = "Github_PR_Files_logs"
}

variable "db_unique_key" {
  type = string
  default = "sha"
}