resource "aws_dynamodb_table" "saved_logs" {
  hash_key = "sha"
  name     = var.db_name
  attribute {
    name = var.db_unique_key
    type = "S"
  }
  read_capacity = 2
  write_capacity = 10
}
