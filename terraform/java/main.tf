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

resource "aws_cloudwatch_log_group" "aws_s3_example_kafka_lambda_bucket_loggroup" {
  name              = "example_kafka_lambda"
  retention_in_days = 90
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
        "arn:aws:logs:${var.aws_region}:*:example_kafka_lambda_iam"
    ]
  }
}

resource "aws_iam_policy" "write_to_cloudwatch_policy" {
    name = "example_kafka_lambda_write_to_cloudwatch_policy"

    policy = data.aws_iam_policy_document.write_to_cloudwatch_policy_document.json
}


resource "aws_iam_role" "example_kafka_lambda_iam" {
  name               = "example_kafka_lambda_iam"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = [
    aws_iam_policy.write_to_cloudwatch_policy.arn
  ]
}

resource "aws_cloudwatch_log_group" "example_kafka_lambda_log_group" {
  name              = "/aws/lambda/example_kafka_lambda"
  retention_in_days = 2
}

resource "aws_lambda_function" "example_kafka_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "${path.module}/../../java/app/build/distributions/app.zip"
  function_name = "example_kafka_lambda"
  role          = aws_iam_role.example_kafka_lambda_iam.arn
  handler       = "io.confluent.example.aws.lambda.App"

  source_code_hash = local_file.example_kafka_lambda_archive.content_base64sha256

  runtime = "java21"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

# Confluent Cloud Kafka Cluster
resource "confluent_kafka_cluster" "example_kafka_lambda_cluster" {
  display_name = "${local.resource_prefix}_example_aws_kafka_lambda"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.ccloud_cluster_region
  # Use standard if you want to have the ability to grant role bindings on topic scope
  # standard {}
  # For cost reasons, we use a basic cluster
  basic {}

  environment {
    id = var.ccloud_environment_id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Topic "test"
resource "confluent_kafka_topic" "example_kafka_lambda_topic_test" {
  kafka_cluster {
    id = confluent_kafka_cluster.example_kafka_lambda_cluster.id
  }
  topic_name         = "test"
  rest_endpoint      = confluent_kafka_cluster.example_kafka_lambda_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.example_kafka_lambda_api_key_cluster_admin.id
    secret = confluent_api_key.example_kafka_lambda_api_key_cluster_admin.secret
  }

  # Required to make sure the role binding is created before trying to create a topic using these credentials
  depends_on = [ confluent_role_binding.example_kafka_lambda_role_binding_cluster_admin ]

  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the cluster admin
resource "confluent_service_account" "example_kafka_lambda_sa_cluster_admin" {
  display_name = "${local.resource_prefix}_example_kafka_lambda_sa_cluster_admin"
  description  = "Service Account AWS Kafka Lambda Example Cluster Admin"
}

resource "confluent_api_key" "example_kafka_lambda_api_key_cluster_admin" {
  display_name = "${local.resource_prefix}_example_kafka_lambda_api_key_cluster_admin"
  description  = "Kafka API Key that is owned by '${local.resource_prefix}_example_kafka_lambda_sa' service account"
  owner {
    id          = confluent_service_account.example_kafka_lambda_sa_cluster_admin.id
    api_version = confluent_service_account.example_kafka_lambda_sa_cluster_admin.api_version
    kind        = confluent_service_account.example_kafka_lambda_sa_cluster_admin.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.example_kafka_lambda_cluster.id
    api_version = confluent_kafka_cluster.example_kafka_lambda_cluster.api_version
    kind        = confluent_kafka_cluster.example_kafka_lambda_cluster.kind

    environment {
      id = var.ccloud_environment_id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "example_kafka_lambda_role_binding_cluster_admin" {
  principal   = "User:${confluent_service_account.example_kafka_lambda_sa_cluster_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.example_kafka_lambda_cluster.rbac_crn
  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the producer
resource "confluent_service_account" "example_kafka_lambda_sa_producer" {
  display_name = "${local.resource_prefix}_example_kafka_lambda_sa_producer"
  description  = "Service Account AWS Kafka Lambda Example Producer"
}

resource "confluent_api_key" "example_kafka_lambda_api_key_producer" {
  display_name = "${local.resource_prefix}_example_kafka_lambda_api_key_producer"
  description  = "Kafka API Key that is owned by '${local.resource_prefix}_example_kafka_lambda_sa' service account"
  owner {
    id          = confluent_service_account.example_kafka_lambda_sa_producer.id
    api_version = confluent_service_account.example_kafka_lambda_sa_producer.api_version
    kind        = confluent_service_account.example_kafka_lambda_sa_producer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.example_kafka_lambda_cluster.id
    api_version = confluent_kafka_cluster.example_kafka_lambda_cluster.api_version
    kind        = confluent_kafka_cluster.example_kafka_lambda_cluster.kind

    environment {
      id = var.ccloud_environment_id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# For role bindings such as DeveloperRead and DeveloperWrite at least a standard cluster type would be required. Let's use ACLs instead
# resource "confluent_role_binding" "example_kafka_lambda_role_binding_producer" {
#   principal   = "User:${confluent_service_account.example_kafka_lambda_sa_producer.id}"
#   role_name   = "DeveloperWrite"
#   # Role binding on topic level would require a standard cluster, but we want to use a basic cluster
#   # crn_pattern = "${confluent_kafka_cluster.example_kafka_lambda_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_kafka_lambda_cluster.id}/topic=${confluent_kafka_topic.example_kafka_lambda_topic_test.topic_name}"
#   # Grant access to all topics instead
#   crn_pattern = confluent_kafka_cluster.example_kafka_lambda_cluster.rbac_crn
#   lifecycle {
#     prevent_destroy = false
#   }
# }
resource "confluent_kafka_acl" "example_kafka_lambda_acl_producer" {
 kafka_cluster {
    id = confluent_kafka_cluster.example_kafka_lambda_cluster.id
  }
  rest_endpoint  = confluent_kafka_cluster.example_kafka_lambda_cluster.rest_endpoint
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.example_kafka_lambda_topic_test.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.example_kafka_lambda_sa_producer.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  credentials {
    key    = confluent_api_key.example_kafka_lambda_api_key_cluster_admin.id
    secret = confluent_api_key.example_kafka_lambda_api_key_cluster_admin.secret
  }
  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the consumer
resource "confluent_service_account" "example_kafka_lambda_sa_consumer" {
  display_name = "${local.resource_prefix}_example_kafka_lambda_sa_consumer"
  description  = "Service Account AWS Kafka Lambda Example Consumer"
}


resource "confluent_api_key" "example_kafka_lambda_api_key_consumer" {
  display_name = "${local.resource_prefix}_example_kafka_lambda_api_key_consumer"
  description  = "Kafka API Key that is owned by '${local.resource_prefix}_example_kafka_lambda_sa' service account"
  owner {
    id          = confluent_service_account.example_kafka_lambda_sa_consumer.id
    api_version = confluent_service_account.example_kafka_lambda_sa_consumer.api_version
    kind        = confluent_service_account.example_kafka_lambda_sa_consumer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.example_kafka_lambda_cluster.id
    api_version = confluent_kafka_cluster.example_kafka_lambda_cluster.api_version
    kind        = confluent_kafka_cluster.example_kafka_lambda_cluster.kind

    environment {
      id = var.ccloud_environment_id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_acl" "example_kafka_lambda_acl_consumer" {
 kafka_cluster {
    id = confluent_kafka_cluster.example_kafka_lambda_cluster.id
  }
  rest_endpoint  = confluent_kafka_cluster.example_kafka_lambda_cluster.rest_endpoint
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.example_kafka_lambda_topic_test.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.example_kafka_lambda_sa_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  credentials {
    key    = confluent_api_key.example_kafka_lambda_api_key_cluster_admin.id
    secret = confluent_api_key.example_kafka_lambda_api_key_cluster_admin.secret
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_acl" "example_kafka_lambda_acl_consumer_group" {
 kafka_cluster {
    id = confluent_kafka_cluster.example_kafka_lambda_cluster.id
  }
  rest_endpoint  = confluent_kafka_cluster.example_kafka_lambda_cluster.rest_endpoint
  resource_type = "GROUP"
  resource_name = "consumer"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.example_kafka_lambda_sa_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  credentials {
    key    = confluent_api_key.example_kafka_lambda_api_key_cluster_admin.id
    secret = confluent_api_key.example_kafka_lambda_api_key_cluster_admin.secret
  }
  lifecycle {
    prevent_destroy = false
  }
}


# For role bindings such as DeveloperRead and DeveloperWrite at least a standard cluster type would be required. Let's use ACLs instead
# resource "confluent_role_binding" "example_kafka_lambda_role_binding_consumer" {
#   principal   = "User:${confluent_service_account.example_kafka_lambda_sa_consumer.id}"
#   role_name   = "DeveloperRead"
#   # Role binding on topic level would require a standard cluster, but we want to use a basic cluster
#   # crn_pattern = "${confluent_kafka_cluster.example_kafka_lambda_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_kafka_lambda_cluster.id}/topic=${confluent_kafka_topic.example_kafka_lambda_topic_test.topic_name}"
#   # Grant access to all topics instead
#   crn_pattern = confluent_kafka_cluster.example_kafka_lambda_cluster.rbac_crn
#   lifecycle {
#     prevent_destroy = false
#   }
# }
output "cluster_bootstrap_server" {
   value = confluent_kafka_cluster.example_kafka_lambda_cluster.bootstrap_endpoint
}
output "cluster_rest_endpoint" {
    value = confluent_kafka_cluster.example_kafka_lambda_cluster.rest_endpoint
}

output "cluster_api_key_admin" {
    value = nonsensitive("Key: ${confluent_api_key.example_kafka_lambda_api_key_cluster_admin.id}\nSecret: ${confluent_api_key.example_kafka_lambda_api_key_cluster_admin.secret}")
}

output "cluster_api_key_producer" {
    value = nonsensitive("Key: ${confluent_api_key.example_kafka_lambda_api_key_producer.id}\nSecret: ${confluent_api_key.example_kafka_lambda_api_key_producer.secret}")
}

output "cluster_api_key_consumer" {
    value = nonsensitive("Key: ${confluent_api_key.example_kafka_lambda_api_key_consumer.id}\nSecret: ${confluent_api_key.example_kafka_lambda_api_key_consumer.secret}")
}

# Generate console client configuration files for testing
resource "local_sensitive_file" "client_config_files" {
  for_each = {
    "admin" = confluent_api_key.example_kafka_lambda_api_key_cluster_admin,
    "producer" = confluent_api_key.example_kafka_lambda_api_key_producer,
    "consumer" = confluent_api_key.example_kafka_lambda_api_key_consumer}

  content = templatefile("${path.module}/templates/client.conf.tpl",
  {
    client_name = "${each.key}"
    cluster_bootstrap_server = trimprefix("${confluent_kafka_cluster.example_kafka_lambda_cluster.bootstrap_endpoint}", "SASL_SSL://")
    api_key = "${each.value.id}"
    api_secret = "${each.value.secret}"
  }
  )
  filename = "${path.module}/generated/client-configs/client-${each.key}.conf"
}
