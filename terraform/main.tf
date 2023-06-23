# Define AWS provider
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA2RE5C3UYDUZ5OU5C"
  secret_key = "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"
}

# Create AWS Lambda function
resource "aws_lambda_function" "my_lambda_function" {
  function_name = "my-lambda-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "org.springframework.cloud.function.adapter.aws.FunctionInvoker::handleRequest"
  runtime       = "java17"
  timeout       = 10
  memory_size   = 512
  filename      = "../target/spring-boot-aws-functional-routing-with-lambda-0.0.1-SNAPSHOT-aws.jar"
}

# Create IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# This policy allows the Lambda function to write logs to CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create API Gateway
resource "aws_api_gateway_rest_api" "my_api" {
  name        = "my-api"
  description = "My API"
}

# Add a resource(my-resource) to the API Gateway
resource "aws_api_gateway_resource" "my_resource" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "my-resource"
}

# Add a method(POST) to the resource(my-resource)
resource "aws_api_gateway_method" "my_method" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.my_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Linked the method(POST) to the Lambda function
resource "aws_api_gateway_integration" "my_integration" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.my_resource.id
  http_method             = aws_api_gateway_method.my_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_lambda_function.invoke_arn
}


# Allow API Gateway(my-api) to invoke the Lambda function(my-lambda-function)
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.my_api.execution_arn}/*"
}

# Deploy the API Gateway to the dev stage
resource "aws_api_gateway_deployment" "my_deployment" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  stage_name  = "dev"
  depends_on = [
    aws_api_gateway_integration.my_integration]
}

output "api_gateway_url" {
  value = "${aws_api_gateway_deployment.my_deployment.invoke_url}/${aws_api_gateway_resource.my_resource.path_part}"
}