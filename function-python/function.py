import json
import boto3
import requests
import hashlib
import hmac
import os


class CustomError(Exception):
    def __init__(self, message, num):
        self.message = message
        self.statusCode = num


def get_secret() -> (str, str):
    """
    Get specific secret from SSM parameter store.

    Raise and return 500 problem with retrieving secret.

    return:
        A tuple, that holds 2 secrets.
    """
    ssm_client = boto3.client('ssm')
    try:
        github_token = ssm_client.get_parameter(Name=os.environ["github_api_token_path"])["Parameter"]["Value"]
        webhook_secret = ssm_client.get_parameter(Name=os.environ["github_secret_path"])["Parameter"]["Value"]
    except Exception as e:
        print("Error retrieving secret:", str(e))
        raise CustomError("Error retrieving secrets", 400)

    ssm_client.close()
    return github_token, webhook_secret


def verify_signature(payload_body, secret_token, signature_header):
    """Verify that the payload was sent from GitHub by validating SHA256.

    Raise and return 403 if not authorized or missing signature.

    Args:
        payload_body: original request body to verify (request.body())
        secret_token: GitHub app webhook token (WEBHOOK_SECRET)
        signature_header: header received from GitHub (x-hub-signature-256)
    """
    if not signature_header:
        print("This is an unauthorized webhook - x-hub-signature-256 header is missing!")
        raise CustomError("This is an unauthorized webhook", 403)

    hash_object = hmac.new(secret_token.encode('utf-8'), msg=payload_body.encode('utf-8'), digestmod=hashlib.sha256)
    expected_signature = "sha256=" + hash_object.hexdigest()
    if not hmac.compare_digest(expected_signature, signature_header):
        print("This is an unauthorized webhook - signature doesn't match")
        raise CustomError("This is an unauthorized webhook", 403)


def insert_logs_to_db(commit_sha: str, merge_time: str, updated_files: list,
                      removed_files: list, added_files: list, repository_name: list):
    """
    Insert new log to dynamodb.

    In-order to find something use this exmaple of a query:
    SELECT "modified" FROM "savedlogs" where contains("modified",'<Filename>')

    Args:
        commit_sha: The sha of the commit that was merged.
        merge_time: The time of the merge.
        updated_files: A list of names of files that was updated during merge.
        removed_files: A list of names of files that was removed during merge.
        added_files: A list of names of files that was added during merge.
        repository_name: Repository name for the merge.
    """
    json_data = {
        "sha": {
            "S": commit_sha
        },
        "Timestamp": {
            "S": merge_time
        },
        "Modified_Files": {
            "L": updated_files
        },
        "Removed_Files": {
            "L": removed_files
        },
        "Added_Files": {
            "L": added_files
        },
        "Repository_Name": {
            "S": repository_name
        }
    }
    # DynamoDB table name
    dynamodb_region_name = os.environ['dynamodb_region_name']
    table_name = os.environ['dynamodb_table_name']

    # Insert JSON data into DynamoDB
    dynamodb = boto3.client('dynamodb', region_name=dynamodb_region_name)
    try:
        dynamodb.put_item(
            TableName=table_name,
            Item=json_data
        )
    except Exception as e:
        print("Error inserting data into DB:", str(e))
        raise CustomError("Error inserting data into DB", 400)


def get_files_list_from_github(api_url: str, github_token: str) -> (list, list, list):
    """
    Get all files that was changed using a rest request.

    Args:
        api_url: A github url to address to.
        github_token: A token to use github's api.
    Return:
        updated_files: A list of names of files that was updated during merge.
        removed_files: A list of names of files that was removed during merge.
        added_files: A list of names of files that was added during merge.
    """
    # call github api to extract files list
    headers = {
        "Authorization": f"Bearer {github_token}",
        "User-Agent": "I want all files that changed"
    }
    try:
        response = requests.get(api_url, headers=headers)

        updated_files = []
        removed_files = []
        added_files = []

        if response.status_code == 200:
            for file in response.json()["files"]:
                if file['status'] == "updated":
                    updated_files.append({"S": f"{file['filename']}"})
                elif file['status'] == "removed":
                    removed_files.append({"S": f"{file['filename']}"})
                else:
                    added_files.append({"S": f"{file['filename']}"})
            print("Changed Files:", updated_files, removed_files, added_files)
        else:
            print("GitHub Request Failed:", response.text)
            return {
                'statusCode': response.status_code,
                'body': json.dumps("GitHub Request Failed:")
            }

        return updated_files, removed_files, added_files

    except Exception as e:
        print("Error res:", str(e))
        raise Exception(str(e))


def lambda_handler(event, context):
    try:
        github_token, secret_github_signature_token = get_secret()
        json_body = json.loads(event['body'])
        sha256 = event['headers']['X-Hub-Signature-256']
        verify_signature(event['body'], secret_github_signature_token, sha256)

        # continue, only if the pull request was merged.
        if json_body.get('action', None) != 'closed' or not json_body['pull_request']['merged']:
            print("I only execute, PR that is merged, this is not the case")
            return {
                'statusCode': 200,
                'body': json.dumps("I only execute, PR that is merged, this is not the case")
            }

        # extract parameters
        repository_name = json_body['repository']['name']
        merge_time = json_body['pull_request']["merged_at"]
        commit_sha = json_body['pull_request']['merge_commit_sha']
        commits_url = json_body['repository']['commits_url']
        api_url = commits_url.replace("{/sha}", "/" + commit_sha)

        updated_files, removed_files, added_files = get_files_list_from_github(api_url, github_token)

        insert_logs_to_db(commit_sha, merge_time, updated_files, removed_files, added_files, repository_name)

        print('Log was added successfully')
        return {
            'statusCode': 200,
            'body': json.dumps('Log was added successfully')
        }
    except CustomError as e:
        return {
            "statusCode": e.statusCode,
            "body": e.message
        }
    except Exception as e:
        print("Error res:", str(e))
        return {
            "statusCode": 500,
            "body": str(e)
        }
