resource "aws_ssm_parameter" "smoke_test" {
  name  = "/${var.project_name}/smoke-test"
  type  = "String"
  value = "hello from terraform"
}

output "smoke_test_parameter" {
  value = aws_ssm_parameter.smoke_test.name
}
