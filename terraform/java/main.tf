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

resource "local_file" "example_kafka_lambda_archive" {
    filename = "files/app.zip"
    source = "${path.module}/../../java/app/build/distributions/app.zip"
}

resource "aws_s3_object" "lambda_app" {
  bucket = aws_s3_bucket.aws_s3_example_kafka_lambda_bucket.id

  key    = "app.zip"
  source = local_file.example_kafka_lambda_archive.content

  etag = local_file.example_kafka_lambda_archive.content_base64sha256
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

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_lambda_function" "example_kafka_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "${path.module}/../../java/app/build/distributions/app.zip"
  function_name = "example_kafka_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "io.confluent.example.aws.lambda.App.handleRequest"

  source_code_hash = local_file.example_kafka_lambda_archive.content_base64sha256

  runtime = "java21"

  environment {
    variables = {
      foo = "bar"
    }
  }
}


resource "confluent_kafka_cluster" "basic" {
  display_name = "${local.resource_prefix}-example-aws-kafka-lambda"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.ccloud_cluster_region
  basic {}

  environment {
    id = var.ccloud_environment_id
  }

  lifecycle {
    prevent_destroy = false
  }
}
