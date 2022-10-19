#########################################################################    
                  #CONFIGURAÇÃO PROVIDER/REGIÃO#
#########################################################################

/*
Autor: CloudHub  
*/ 

#####################
#Config Provider AWS#
#####################


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

#############################
#Config Região e Credenciais#
#############################

provider "aws" {
    region                  = "us-east-1"
    shared_credentials_file = ".aws/credentials"
}


############################################
#Criação do Certificado e Policy IOT Things#
############################################


resource "aws_iot_thing" "ESP32_DHT11_iot_thing" {
  name            = "${var.thing_name}"
}

resource "aws_iot_policy" "ESP32_DHT11_iot_policy" {
  name   = var.iot_policy
  policy = data.template_file.tf_iot_policy.rendered
}

resource "aws_iot_certificate" "this" {
  active = true
}

resource "aws_iot_policy_attachment" "att_policy" {
  policy = aws_iot_policy.ESP32_DHT11_iot_policy.name
  target = aws_iot_certificate.this.arn
}

resource "aws_iot_thing_principal_attachment" "att_thing" {
  principal = aws_iot_certificate.this.arn
  thing     = aws_iot_thing.ESP32_DHT11_iot_thing.name
}


##########################
#Rules IOT Core Republish#
##########################


resource "aws_iot_topic_rule" "republish_temp_rule" {
  name        = "republish_temp"
  description = "Quando a regra recebe uma mensagem de um tópico correspondente, ela republica os valores device_ide temperaturecomo uma nova mensagem MQTT com o device/data/temptópico."
  enabled     = true
  sql         = "SELECT topic(2) as celular_id, temperatura_bb FROM 'device/+/data'"
  sql_version = "2016-03-23"

republish {
    
   role_arn       = "arn:aws:iam::402664395967:role/service-role/republish_role"
   topic          = "device/data/temp"
  }
}

#####################
#Topico SNS para SMS#
#####################


locals {
  phone_numbers = ["+5511"]
}

resource "aws_sns_topic" "high_temp_notice_topic" {
  name            = "high_temp_notice"
  delivery_policy = jsonencode({
    "http" : {
      "defaultHealthyRetryPolicy" : {
        "minDelayTarget" : 20,
        "maxDelayTarget" : 20,
        "numRetries" : 3,
        "numMaxDelayRetries" : 0,
        "numNoDelayRetries" : 0,
        "numMinDelayRetries" : 0,
        "backoffFunction" : "linear"
      },
      "disableSubscriptionOverrides" : false,
      "defaultThrottlePolicy" : {
        "maxReceivesPerSecond" : 1
      }
    }
  })
}

resource "aws_sns_topic_subscription" "topic_sms_subscription" {
  count     = length(local.phone_numbers)
  topic_arn = aws_sns_topic.high_temp_notice_topic.arn
  protocol  = "sms"
  endpoint  = local.phone_numbers[count.index]
}

resource "aws_sns_topic_policy" "high_temp_notice_policy" {
  arn = aws_sns_topic.high_temp_notice_topic.arn
  policy = data.aws_iam_policy_document.my_custom_sns_policy_document.json
}

data "aws_iam_policy_document" "my_custom_sns_policy_document" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        var.account_id,
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.high_temp_notice_topic.arn,
    ]

    sid = "__default_statement_ID"
  }
}

######################################
#Rules IOT Core SNS para envio de SMS#
######################################

resource "aws_iot_topic_rule" "temp_limit_notify_rule" {
  name        = "temp_limit_notify"
  description = ""
  enabled     = true
  sql         = "SELECT topic(2) as celular_id, temperaturaBB as temperatura_reportada, 36 as max_temperatura FROM 'device/+/data' WHERE temperaturaBB > 36"
  sql_version = "2016-03-23"

 sns {
    message_format = "RAW"
    role_arn       = "arn:aws:iam::402664395967:role/service-role/sns_rule_role"
    target_arn     = "arn:aws:sns:us-east-1:402664395967:high_temp_notice"
  }
}

#####################
#Criação do DynamoDB#
#####################



resource "aws_dynamodb_table" "wx_data_table" {
 name = "wx_data"
 billing_mode = "PROVISIONED"
 read_capacity= "10"
 write_capacity= "10"
 hash_key = "tempo" //Partition Key
 range_key = "celular_id" //Sort key

 attribute {
  name = "tempo"
  type = "S"
 }

attribute {
  name = "celular_id"
  type = "S"
 }
}

#######################
#Criação do TimeStream#
#######################

resource "aws_timestreamwrite_database" "iot_database" {
  database_name = "IOT"
}


resource "aws_timestreamwrite_table" "iot_table" {
  database_name = aws_timestreamwrite_database.iot_database.database_name
  table_name    = "sensorData"

  retention_properties {
    magnetic_store_retention_period_in_days = 1
    memory_store_retention_period_in_hours  = 8
  }
}

##################################
#Rules IOT Core Insert no DynamoDB#
###################################

resource "aws_iot_topic_rule" "wx_data_ddb_rule" {
  name        = "wx_ddata_db"
  description = ""
  enabled     = true
  sql         = "SELECT temperaturaBB, celular_id, temperaturaBB.min as temperatura_minima, temperaturaBB.max as temperatura_maxima, FROM 'device/+/data'"
  sql_version = "2016-03-23"

  # timestream {
  #      database_name = "IOT"
  #      table_name = "sensorData"
  #      #dimension_name  = "temperaturaBB"
  #      #dimension_value = "${temperaturaBB}"  
  #      role_arn       = "arn:aws:iam::402664395967:role/service-role/timestream_role"
  #}

 dynamodb {
    table_name       = "wx_data"
    hash_key_field  = "tempo"
    hash_key_type   = "STRING"
    hash_key_value  = "${timestamp()}"
    range_key_field = "celular_id"
    range_key_type  = "STRING"
    payload_field   = "device_data"
    // = "${topic(2)}"
    role_arn       = "arn:aws:iam::402664395967:role/service-role/wx_ddb_role"
  }
}  
#
#resource "aws_iam_role" "format-high-temp-notification_role" {
#name   = "format-high-temp-notification"
#assume_role_policy = <<EOF
#{
# "Version": "2012-10-17",
# "Statement": [
#   {
#     "Action": "sts:AssumeRole",
#     "Principal": {
#       "Service": "lambda.amazonaws.com"
#     },
#     "Effect": "Allow",
#     "Sid": ""
#   }
# ]
#}
#EOF
#}
#

###################
#Criação do Lambda#
###################

resource "aws_iam_policy" "iam_policy_for_lambda" {
 
 name         = "aws_iam_policy_for_terraform_aws_lambda_role"
 path         = "/"
 description  = "AWS IAM Policy for managing aws lambda role"
 policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents",
       "SNS:Subscribe",
       "SNS:SetTopicAttributes",
       "SNS:RemovePermission",
       "SNS:Receive",
       "SNS:Publish",
       "SNS:ListSubscriptionsByTopic",
       "SNS:GetTopicAttributes",
       "SNS:DeleteTopic",
       "SNS:AddPermission"
     ],
     "Resource": [ 
      "arn:aws:logs:*:*:*", "arn:aws:sns:*:*:*"
      ],
     "Effect": "Allow"
   }
 ]
}
EOF
}
 
data "archive_file" "zip_the_python_code" {
type        = "zip"
source_dir  = "${path.module}/python/"
output_path = "${path.module}/python/hello-python.zip"
}
 
resource "aws_lambda_function" "terraform_lambda_func" {
filename                       = "${path.module}/python/hello-python.zip"
function_name                  = "format-high-temp-notification"
role                           = "arn:aws:iam::402664395967:role/service-role/format-high-temp-notification-role"
handler                        = "hello-python.lambda_handler"
runtime                        = "python3.7"
#depends_on                     = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

##############################
#Rules IOT Core Identação SMS#
##############################

resource "aws_iot_topic_rule" "wx_friendly_text_rule" {
  name        = "wx_friendly_text"
  description = "Quando a regra recebe uma mensagem de um tópico correspondente, ela republica os valores device_ide temperaturecomo uma nova mensagem MQTT com o device/data/temptópico."
  enabled     = true
  sql         = "SELECT celular_id, temperaturaBB as temperatura_reportada,36 as temperatura_max,'arn:aws:sns:us-east-1:402664395967:high_temp_notice' as notify_topic_arn FROM 'device/+/data' WHERE temperaturaBB > 36"
  sql_version = "2016-03-23"

lambda {
    
   function_arn     = "arn:aws:lambda:us-east-1:402664395967:function:format-high-temp-notification"
   //starting_position = "LATEST"
  }
}