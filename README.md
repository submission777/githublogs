## Execution
Inside main-service folder,
run the following commands
```
terraform init
terraform apply --auto-approve
```
first enter a git token that has read/write on repository.
second enter a git secret to be used by github webhook.
(optional third) 

## Assumptions:
1. GitHub repos doesn't exist
2. No GitHub Enterprise
3. Code is run locally

## Directories
1. `function-python` contains a function.py file and a zip of requirements to be used by AWS lambda. 
2. `github-repo-webhook` contains TF module to create a repo and a webhook.
3. `aws-logic-infra` contains TF module to create AWS infrastructure.
4. `main-service` contains TF root, to be executed.

## Architecture design
The service consists of a lambda function that is triggered by a GitHub webhook.
The frontend is a lambda function with an api gw in-front of it.
The backed(where the logs are saved) is a dynamodb table.
SSM parameter-store stores all the sensitive data.



An example of use to query the db that contains the logs -

```aws dynamodb execute-statement --statement 'SELECT "modified" FROM "Github_PR_Files_logs" where contains("modified","LICENSE")'```