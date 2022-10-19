#output "iot_thing_arn" {
#  value = aws_iot_thing.thing.arn
#}
#output "iot_certificate_arn" {
#  value = aws_iot_certificate.cert.arn
#}
#output "iot_certificate_pem" {
#  value = aws_iot_certificate.cert.certificate_pem
#}
#output "iot_certificate_public_key" {
#  value = aws_iot_certificate.cert.public_key
#}
#output "iot_certificate_private_key" {
#  value = aws_iot_certificate.cert.private_key
#}

#output "arn" {
#  description = "returns a string"
#  value       = aws_iot_certificate.this.arn
#}

output "certificate_pem" {
  description = "returns a string"
  value       = nonsensitive(aws_iot_certificate.this.certificate_pem)
}

output "csr" {
  description = "returns a string"
  value       = nonsensitive(aws_iot_certificate.this.certificate_pem)
}

#output "id" {
#  description = "returns a string"
#  value       = aws_iot_certificate.this.id
#}

output "private_key" {
  description = "returns a string"
  value       = nonsensitive(aws_iot_certificate.this.private_key)
}

output "public_key" {
  description = "returns a string"
  value       = nonsensitive(aws_iot_certificate.this.public_key)
}

output "this" {
  value = aws_iot_certificate.this
  sensitive = true
}