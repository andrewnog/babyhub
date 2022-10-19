import boto3
#
#   expects event parameter to contain:
#   {
#       "celular_id": "32",
#       "temperatura_reportada": 38,
#       "temperatura_max": 36,
#       "notify_topic_arn": "arn:aws:sns:us-east-1:402664395967:high_temp_notice"
#   }
# 
#   sends a plain text string to be used in a text message
#
#      "Device {0} reports a temperature of {1}, which exceeds the limit of {2}."
#   
#   where:
#       {0} is the device_id value
#       {1} is the reported_temperature value
#       {2} is the max_temperature value
#
def lambda_handler(event, context):

    # Create an SNS client to send notification
    sns = boto3.client('sns')

    # Format text message from data
    message_text = "Celular {0} esta reportando a temperatura de {1}, que está acima do limite de {2}.".format(
            str(event['celular_id']),
            str(event['temperatura_reportada']),
            str(event['temperatura_max'])
        )

    # Publish the formatted message
    response = sns.publish(
            TopicArn = event['notify_topic_arn'],
            Message = message_text
        )

    return response