terraform {
  required_providers {
    github = {
      source = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
  token = var.git_token
  alias = "git_token"
}

output "dynamo_db_name" {
  value = module.infra_region_one.db_name
}

module "infra_region_one" {
  source = "../aws-logic-infra"
  github_webhook_secret = var.git_secret
  github_api_token = var.git_token
  aws_region = var.aws_region
}

module "git_reposeto" {
  source = "../github-repo-webhook"

  for_each = toset(var.repo_names)

  webhook_secret = var.git_secret
  webhook_url = module.infra_region_one.api_base_url
  repo_name = each.key

  providers = {
    github = github.git_token
  }
}