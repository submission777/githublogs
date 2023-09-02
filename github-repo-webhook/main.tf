terraform {
  required_providers {
    github = {
      source = "integrations/github"
      version = "~> 5.0"
    }
  }
}

resource "github_repository" "new_repository" {
  name = var.repo_name
  description = "New repo ,created by terraform"
}

resource "github_repository_webhook" "new_hook" {
  repository = github_repository.new_repository.name
  configuration {
    url = var.webhook_url
    content_type = "json"
    secret = var.webhook_secret
  }
  events = ["pull_request"]
}