resource "aws_ssm_parameter" "smoke_test" {
  name  = "/${var.project_name}/smoke-test"
  type  = "String"
  value = "hello from terraform with github CICD t1"
}

output "smoke_test_parameter" {
  value = aws_ssm_parameter.smoke_test.name
}
