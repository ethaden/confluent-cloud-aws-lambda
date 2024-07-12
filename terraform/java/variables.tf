
# Recommendation: Overwrite the default in tfvars or stick with the automatic default
variable "tf_last_updated" {
    type = string
    default = ""
    description = "Set this (e.g. in terraform.tfvars) to set the value of the tf_last_updated tag for all resources. If unset, the current date/time is used automatically."
}
# Recommendation: Overwrite the default in tfvars or by specify an environment variable TF_VAR_aws_region
variable "aws_region" {
    type = string
    default = "eu-central-1"
    description = "The AWS region to be used"
}

variable "purpose" {
    type = string
    default = "Testing"
    description = "The purpose of this configuration, used e.g. as tags for AWS resources"
}

variable "username" {
    type = string
    default = ""
    description = "Username, used to define local.username if set here. Otherwise, the logged in username is used."
}

variable "owner" {
    type = string
    default = ""
    description = "All resources are tagged with an owner tag. If none is provided in this variable, a useful value is derived from the environment"
}

# The validator uses a regular expression for valid email addresses (but NOT complete with respect to RFC 5322)
variable "owner_email" {
    type = string
    default = ""
    description = "All resources are tagged with an owner_email tag. If none is provided in this variable, a useful value is derived from the environment"
    validation {
        condition = anytrue([
            var.owner_email=="",
            can(regex("^[a-zA-Z0-9_.+-]+@([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9]+)*\\.)+[a-zA-Z]+$", var.owner_email))
        ])
        error_message = "Please specify a valid email address for variable owner_email or leave it empty"
    }
}

variable "owner_fullname" {
    type = string
    default = ""
    description = "All resources are tagged with an owner_fullname tag. If none is provided in this variable, a useful value is derived from the environment"
}

variable "resource_prefix" {
    type = string
    default = ""
    description = "This string will be used as prefix for generated resources. Default is to use the username"
}

variable "public_ssh_key" {
    type = string
    default = ""
    description = "Public SSH key to use. If not specified, use either $HOME/.ssh/id_ed25519.pub or if that does not exist: $HOME/.ssh/id_rsa.pub"
}

variable "ccloud_environment_id" {
    type = string
    description = "ID of the Confluent Cloud environment to use"
}

variable "ccloud_cluster_region" {
    type = string
    default = "us-east-2"
    description = "The region used to deploy the Confluent Cloud Kafka cluster"
}
