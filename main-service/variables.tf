variable "git_token" {
  type = string
  description = "Enter git token for api"
  sensitive = true
}
variable "git_secret" {
  type = string
  description = "Enter git secret for webhook usage"
  sensitive = true
}

variable "aws_region" {
  type = string
  default = "us-east-2"
}

variable "repo_names" {
  type = list(string)
  default = ["justname1", "justname2"]
}