provider "aws" {
  region = var.aws_region // This tells AWS where to create our resources.

  default_tags {
    tags = {
      hashicorp-learn = "lambda-api-gateway" // This tag helps identify resources created for this project.
    }
  }

}

resource "random_pet" "lambda_bucket_name" {
  prefix = "learn-terraform-functions" // This is the prefix for our random bucket name.
  length = 4 // The name will have four random words.
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id // This creates an S3 bucket with a random name.
}

resource "aws_s3_bucket_ownership_controls" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id // This sets ownership controls for our bucket.
  rule {
    object_ownership = "BucketOwnerPreferred" // The bucket owner has control over objects.
  }
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket] // This ensures ownership controls are set first.

  bucket = aws_s3_bucket.lambda_bucket.id // This sets the access control list for our bucket.
  acl    = "private" // The bucket is private, meaning only the owner can access it.
}

data "archive_file" "lambda_hello_world" {
  type = "zip" // We are creating a zip file.

  source_dir  = "${path.module}/hello-world" // This is the directory we want to zip.
  output_path = "${path.module}/hello-world.zip" // This is where the zip file will be saved.
}

resource "aws_s3_object" "lambda_hello_world" {
  bucket = aws_s3_bucket.lambda_bucket.id // This uploads our zip file to the S3 bucket.

  key    = "hello-world.zip" // This is the name of the file in the bucket.
  source = data.archive_file.lambda_hello_world.output_path // This is the path to the zip file.

  etag = filemd5(data.archive_file.lambda_hello_world.output_path) // This ensures the file hasn't changed.
}

# Configures the Lambda function to use the bucket object containing your function code. 
# It also sets the runtime to NodeJS, and assigns the handler to the handler function defined in hello.js. 
# The source_code_hash attribute will change whenever you update the code contained in the archive, 
# which lets Lambda know that there is a new version of your code available. 
# Finally, the resource specifies a role which grants the function permission to access AWS services and resources in your account.
resource "aws_lambda_function" "hello_world" {
  function_name = "HelloWorld" // This is the name of our Lambda function.

  s3_bucket = aws_s3_bucket.lambda_bucket.id // This is the bucket where our function code is stored.
  s3_key    = aws_s3_object.lambda_hello_world.key // This is the key for our function code in the bucket.

  runtime = "nodejs20.x" // This is the runtime environment for our function.
  handler = "hello.handler" // This is the function in our code that AWS Lambda calls.

  source_code_hash = data.archive_file.lambda_hello_world.output_base64sha256 // This tells Lambda if the code has changed.

  role = aws_iam_role.lambda_exec.arn // This is the role that gives our function permissions.
}

# Defines a log group to store log messages from your Lambda function for 30 days. 
# By convention, Lambda stores logs in a group with the name /aws/lambda/<Function Name>.
resource "aws_cloudwatch_log_group" "hello_world" {
  name = "/aws/lambda/${aws_lambda_function.hello_world.function_name}" // This is where our function logs will be stored.

  retention_in_days = 30 // Logs will be kept for 30 days.
}

# Defines an IAM role that grants the Lambda function permission to access AWS services and resources in your account.
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda" // This is the name of our IAM role.

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com" // This allows Lambda to assume this role.
      }
      }
    ]
  })
}

# Attaches the AWSLambdaBasicExecutionRole policy to the Lambda execution role. 
# This policy grants the Lambda function permission to write logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name // This attaches a policy to our IAM role.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" // This policy allows writing logs to CloudWatch.
}


# Defines a name for the API Gateway and sets its protocol to HTTP.
resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw" // This is the name of our API Gateway.
  protocol_type = "HTTP" // This sets the protocol to HTTP.
}

# Sets up application stages for the API Gateway - such as "Test", "Staging", and "Production". The example configuration defines a single stage, with access logging enabled.
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id // This is the API Gateway we are setting up.

  name        = "serverless_lambda_stage" // This is the name of our stage.
  auto_deploy = true // This automatically deploys changes.

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn // This is where access logs will be stored.

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

# Configures the API Gateway to use your Lambda function.
resource "aws_apigatewayv2_integration" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id // This is the API Gateway we are integrating with.

  integration_uri    = aws_lambda_function.hello_world.invoke_arn // This is the URI for our Lambda function.
  integration_type   = "AWS_PROXY" // This sets the integration type to AWS_PROXY.
  integration_method = "POST" // This is the method used for integration.
}

# Defines a route for the API Gateway that matches HTTP requests to the Lambda function.
resource "aws_apigatewayv2_route" "hello_world" {
  api_id = aws_apigatewayv2_api.lambda.id // This is the API Gateway we are setting a route for.

  route_key = "GET /hello" // This is the route key for our API.
  target    = "integrations/${aws_apigatewayv2_integration.hello_world.id}" // This is the target integration.
}

# Defines a log group to store access logs for the aws_apigatewayv2_stage.lambda API Gateway stage.
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}" // This is where API Gateway logs will be stored.

  retention_in_days = 30 // Logs will be kept for 30 days.
}

# Defines a Lambda permission that allows the API Gateway to invoke the Lambda function.
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway" // This is the ID for our permission statement.
  action        = "lambda:InvokeFunction" // This allows the API Gateway to invoke our Lambda function.
  function_name = aws_lambda_function.hello_world.function_name // This is the function that can be invoked.
  principal     = "apigateway.amazonaws.com" // This is the service that can invoke the function.

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*" // This is the source ARN for the permission.
}

