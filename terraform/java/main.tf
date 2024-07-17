resource "aws_s3_bucket" "aws_s3_example_kafka_lambda_bucket" {
  bucket = "${local.resource_prefix}-aws-s3-bucket-example-kafka-lambda"

  tags = {
    Name        = "${local.resource_prefix}-aws-s3-bucket-example-kafka-lambda"
    Environment = "Common"
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_ownership_controls" "aws_s3_example_kafka_lambda_bucket_acl_ownership" {
  bucket = aws_s3_bucket.aws_s3_example_kafka_lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

#data "archive_file" "example_kafka_lambda_archive" {
#  type = "zip"

#  source_dir  = "${path.module}/../../java"
#  output_path = "${path.module}/../../java/app/build/distributions/app.zip"
#}

data "local_file" "example_kafka_lambda_archive" {
    #filename = "${path.module}/../../java/app/build/distributions/app.txt"
    filename = "${path.module}/../../java/app/build/distributions/app.zip"
}

#resource "local_file" "example_kafka_lambda_archive" {
#    #filename = "files/app.zip"
#    #source = "${path.module}/../../java/app/build/distributions/app.zip"
#    filename = "${path.module}/../../java/app/build/distributions/app.zip"
#}

resource "aws_s3_object" "lambda_app" {
  bucket = aws_s3_bucket.aws_s3_example_kafka_lambda_bucket.id
  key    = "app.zip"
  source = data.local_file.example_kafka_lambda_archive.filename

  etag = data.local_file.example_kafka_lambda_archive.content_base64sha256
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "write_to_cloudwatch_policy_document" {
  // Allow lambda to write logs
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
        "${aws_cloudwatch_log_group.example_kafka_lambda_log_group.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "write_to_cloudwatch_policy" {
    name = "example_kafka_lambda_write_to_cloudwatch_policy"

    policy = data.aws_iam_policy_document.write_to_cloudwatch_policy_document.json
}

data "aws_iam_policy_document" "get_kafka_secret_from_secret_manager_policy_document" {
  // Allow lambda to write logs
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
        aws_secretsmanager_secret.example_kafka_lambda_secret_consumer.arn
    ]
  }
}

resource "aws_iam_policy" "get_kafka_secret_from_secret_manager_policy" {
    name = "get_kafka_secret_from_secret_manager_policy"

    policy = data.aws_iam_policy_document.get_kafka_secret_from_secret_manager_policy_document.json
}

resource "aws_iam_role" "example_kafka_lambda_iam" {
  name               = "example_kafka_lambda_iam"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = [
    aws_iam_policy.write_to_cloudwatch_policy.arn,
    aws_iam_policy.get_kafka_secret_from_secret_manager_policy.arn
  ]
}

resource "aws_cloudwatch_log_group" "example_kafka_lambda_log_group" {
  name              = "/aws/lambda/example_kafka_lambda"
  retention_in_days = 7
}

resource "aws_lambda_function" "example_kafka_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  #filename      = "${path.module}/../../java/app/build/distributions/app.zip"
  s3_bucket =  aws_s3_bucket.aws_s3_example_kafka_lambda_bucket.id
  s3_key = aws_s3_object.lambda_app.key
  function_name = "example_kafka_lambda"
  role          = aws_iam_role.example_kafka_lambda_iam.arn
  handler       = "io.confluent.example.aws.lambda.App"

  source_code_hash = data.local_file.example_kafka_lambda_archive.content_base64sha256

  runtime = "java21"

  depends_on = [ 
    aws_cloudwatch_log_group.example_kafka_lambda_log_group, 
    aws_iam_policy.write_to_cloudwatch_policy
  ]

  environment {
    variables = {
      foo = "bar"
    }
  }
}

# We want the lambda to be called each time an event is received via Kafka
resource "aws_lambda_event_source_mapping" "example_kafka_lambda_trigger" {
  function_name     = aws_lambda_function.example_kafka_lambda.arn
  topics            = [var.ccloud_cluster_topic]
  starting_position = "TRIM_HORIZON"

  self_managed_event_source {
    endpoints = {
      KAFKA_BOOTSTRAP_SERVERS = trimprefix("${confluent_kafka_cluster.example_kafka_lambda_cluster.bootstrap_endpoint}", "SASL_SSL://")
    }
  }
  self_managed_kafka_event_source_config {
    consumer_group_id = "consumer-aws"
  }
  source_access_configuration {
    type = "BASIC_AUTH"
    uri = aws_secretsmanager_secret.example_kafka_lambda_secret_consumer.arn
  }
}

# Store the Kafka API keys in AWS secret manager
resource "aws_secretsmanager_secret" "example_kafka_lambda_secret_consumer" {
  name = "example_kafka_lambda_secret"
}
resource "aws_secretsmanager_secret_version" "example_kafka_lambda_secret_consumer_value" {
  secret_id     = aws_secretsmanager_secret.example_kafka_lambda_secret_consumer.id
  secret_string = jsonencode(
    {
      "username": "${confluent_api_key.example_kafka_lambda_api_key_consumer.id}",
      "password": "${confluent_api_key.example_kafka_lambda_api_key_consumer.secret}"
    }
  )
}

