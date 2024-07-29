variable "vpc_id" {
  description = "The ID of the VPC where the security group should be created."
  type        = string
}
variable "public_subnet_ids" {
  description = "The IDs of the public subnets"
  type        = list(string)
}
variable "instance_ami_polybot" {
  description = "AMI ID for the instance."
  type        = string
}

variable "instance_type_polybot" {
  description = "Instance type for the instance."
  type        = string
}

variable "key_pair_name_polybot" {
  description = "Key pair name for SSH access."
  type        = string
}

variable "user_data" {
  description = "Path to user data script"
  type        = string
}

variable "iam_role_name" {
  description = "IAM Role name for the instance"
  type = string

}

variable "certificate_arn" {
  default = ""
  type        = string
}
# Route 53 Records
variable "domain_name" {
  description = "domain name for the route 53"
  type        = string
  default = "int-devops.click"
}

variable "region" {
  description = "region for the polybot"
  type = string
  default = ""
}