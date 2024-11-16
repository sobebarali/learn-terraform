output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code." // This tells us the name of the bucket where our code is stored.

  value = aws_s3_bucket.lambda_bucket.id // This is the actual name of the bucket.
}

output "function_name" {
  description = "Name of the Lambda function." // This tells us the name of our Lambda function.

  value = aws_lambda_function.hello_world.function_name // This is the actual name of the function.
}

output "api_gateway_url" {
  description = "URL of the API Gateway." // This tells us the web address of our API Gateway.

  value = aws_apigatewayv2_stage.lambda.invoke_url // This is the actual URL of the API Gateway.
}