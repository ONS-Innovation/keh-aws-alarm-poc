terraform {
  backend "s3" {
    # Backend is selected using terraform init -backend-config=path/to/backend-<env>.tfbackend
    # bucket         = "sdp-dev-tf-state"
    # key            = "sdp-dev-tech-audit-tool-api-lambda/terraform.tfstate"
    # region         = "eu-west-2"
    # dynamodb_table = "terraform-state-lock"
  }

}

resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.domain}-${var.service_subdomain}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  depends_on = [aws_iam_role.lambda_execution_role]
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_logs" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  depends_on = [aws_iam_role.lambda_execution_role]
}

resource "aws_security_group" "lambda_sg" {
  name = "${var.domain}-${var.service_subdomain}-lambda-sg"
  description = "Security group for ${var.domain}-${var.service_subdomain}-lambda Lambda function"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] // Allow HTTPS traffic within VPC
  }  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.domain}-${var.service_subdomain}-lambda-sg"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  depends_on = [aws_iam_role.lambda_execution_role]
} 

resource "aws_lambda_function" "slack_notifications" {
  function_name = "${var.domain}-${var.service_subdomain}-lambda"
  role          = aws_iam_role.lambda_execution_role.arn
  package_type  = "Image"
  image_uri     = "${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repository}:${var.container_ver}"

  vpc_config {
    subnet_ids          = data.terraform_remote_state.vpc.outputs.private_subnets
    security_group_ids  = [aws_security_group.lambda_sg.id] // Dedicated security group for Lambda function
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_cloudwatch_logs,
    aws_iam_role_policy_attachment.lambda_vpc_access
  ]

  memory_size = 128
  timeout     = 30

  architectures = ["x86_64"]
}

resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifications.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.service_notifications.arn
}

resource "aws_sns_topic_subscription" "lambda_sub" {
    topic_arn = aws_sns_topic.service_notifications.arn
    protocol  = "lambda"
    endpoint = aws_lambda_function.slack_notifications.arn
}

resource "aws_sns_topic" "service_notifications" {
    name = "${var.domain}-service-notifications"
}
