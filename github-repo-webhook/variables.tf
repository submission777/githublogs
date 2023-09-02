
variable "webhook_secret" {
  type = string
  sensitive = true
}

variable "repo_name" {
  type = string
}

variable "webhook_url" {
  type = string
}