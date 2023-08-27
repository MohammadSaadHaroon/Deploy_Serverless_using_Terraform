data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_apigatewayv2_api" "MyApiGatewayHTTPApi" {
    name = var.api_name
    protocol_type = "HTTP"
    body = jsonencode(
        {
            "openapi" : "3.0.1",
            "info" : {
                "title" : "API Gateway HTTP API to Eventbridge"
            
            },
            "paths" : {
                "/" : {
                    "post" : {
                        "responses" : {
                            "default" : {
                                "description" : "EventBridge response "
                            }
                        },
                        "x-amazon-apigateway-integration" : {
                            "integrationSubtype" : "EventBridge-PutEvents",
                            "credentials" : "${aws_iam_role.APIGWRole.arn}",
                            "reuestParameters" : {
                                "Details" : "request.body.Detail"
                                "DetailType" : "MyDetailType"
                                "Source" : "demo.apigw"
                            },
                            "payloadFormatVersion" : "1.0",
                            "type" : "aws_proxy",
                            "connectionType" : INTERNET

                        }
                    }
                }
            }
        }

    )
}

#API Gateway Stage 
resource "aws_apigatewayv2_stage" "MyApiGatewayHTTPStage" {
    api_id = aws_apigatewayv2_api.MyApiGatewayHTTPApi.id
    name = "$default"
    auto_deploy = true
}

#IAM role for API Gateway
resource "aws_iam_role" "APIGWRole" {
    assume_role_policy = file("C:/Deploy Serverless with Terraform/iam_role_for_APIG.json")
}
#IAM policy for API Gateway
resource "aws_iam_policy" "APIGWPolicy" {
    policy = file("C:/Deploy Serverless with Terraform/iam_policy_for_APIG.json")
}

#Attach the IAM policies
resource "aws_iam_role_policy_attachment" "APIGWPolicyAttachment" {
    role = aws_iam_role.APIGWRole.name
    policy_arn = aws_iam_policy.APIGWPolicy.arn
  
}

# Event Rule
resource "aws_cloudwatch_event_rule" "MyEventRule" {
    event_pattern = file("C:/Deploy Serverless with Terraform/eventpattern.json")
}

#Lambda Function as a Cloudwatch event target
resource "aws_cloudwatch_event_target" "MyRuleTarget" {
    arn = aws_lambda_function.MyLambdaFunction.arn
    rule = aws_cloudwatch_event_rule.MyEventRule.id
}

#zip file from lambda code
data "archieve_file" "LambdaZipFile" {
    type = "zip"
    source_file = "${path.module}/src/LambdaFunction.py"
    output_path = "${path.module}/LambdaFunction.zip"

}

#Lambda function that creates zip file of a code
resource "aws_lambda_function" "MyLambdaFunction" {
    function_name = "apigw-http-eventbridge-terraform-demo-${data.aws_caller_identity.current.account_id}"
    filename = data.archieve_file.LambdaZipFile.output_path
    source_code_hash = filebase64sha256(data.archieve_file.LambdaZipFile.output_path)
    role = aws_iam_role.LambdaRole.arn
    handler = "LambdaFunction.lambda_handler"
    runtime = "python3.9"
    layers = ["arn:aws:lambda:${data.aws_region.current.name}:017000801446:layer:AWSLambdaPowertoolsPython:15"]
}

#Allow the eventbridge rule to invoke lambda function
resource "aws_lambda_permission" "EventBridgeLambdaPermission" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    funtion_name = aws_lambda_function.MyLambdaFunction.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.MyEventRule.arn
}

resource "aws_iam_role" "LambdaRole" {
    assume_role_policy = file("C:/Deploy Serverless with Terraform/iam_role_for_lambda.json")

}

resource "aws_iam_policy" "LambdaPolicy" {
    policy = file("C:/Deploy Serverless with Terraform/iam_policy_for_lambda.json")
}

resource "aws_iam_role_policy_attachment" "LambdaPolicyAttachment"{
    role = aws_iam_role.LambdaRole.name
    # policy_arn = aws_iam_policy.LambdaPolicy.arn
}

#log group for Lambdda Function
resource "aws_cloudwatch_log_group" "MyLogGroup" {
    name = "/aws/lambda/${aws_lambda_function.MyLambdaFunction.function_name}"
    retention_in_days = 60
}

output "APIGW-URL" {
    value = aws_apigatewayv2_stage.MyApiGatewayHTTPApiStage.invoke_url
    description = "The API GAteway Invocation URL Queue URL"
}

output "LambdaFunctionName" {
    value = aws_lambdafunction.MyLambdaFunction.function_name
    description = "The Lambda Function name"
}

output "CloudWatchLogName" {
    value = "/aws/lambda/${aws_lambda_function.MyLambdaFunction.function_name}"
    description = "The Lambda function Log Group"
}