variable "thing_name" {
  default = "ESP32_DHT11"
  type = string
}

#variable "thing_type" {
#  default = "Arduino"
#  type = string
#}

variable "iot_policy" {
  default = "ESP32_Policy"
  type    = string
}

variable "aws_info" {
  type = object({
    aws_region     = string
    aws_account_id = string
  })

  default = {
    aws_region     = "us-east-1"
    aws_account_id = "402664395967"
  }

  description = <<EOF
  Group variables of aws account
  ```
  aws_info = {
   aws_region = "us-east-1"
    aws_account_id = "402664395967"
  }
  EOF
}

variable "sns_name" {
        description = "Name of the SNS Topic to be created"
        default = "high_temp_notice"
}

variable "account_id" {
        description = "My Accout Number"
        default = "402664395967"
}