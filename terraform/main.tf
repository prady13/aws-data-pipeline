terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Change to your preferred region
}

variable "project_name" {
  default = "data-pipeline-demo"
}

# --- 1. ECR Repository (To store Docker Images) ---
resource "aws_ecr_repository" "repo" {
  name = "${var.project_name}-repo"
  force_delete = true # Allows destroying repo even if it has images
}

# Lifecycle policy to keep only last 3 images (Saves storage for Free Tier)
resource "aws_ecr_lifecycle_policy" "repo_policy" {
  repository = aws_ecr_repository.repo.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 3 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 3
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

# --- 2. S3 Bucket (To store Data) ---
resource "aws_s3_bucket" "data_bucket" {
  bucket_prefix = "${var.project_name}-storage-"
  force_destroy = true
}

# Block public access (Security Best Practice)
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.data_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- 3. IAM Role (Permissions for Lambda) ---
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach Basic Lambda Execution Policy (Logs)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom Policy for S3 Access
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-policy"
  description = "Allow Lambda to write to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Effect   = "Allow"
      Resource = [
        aws_s3_bucket.data_bucket.arn,
        "${aws_s3_bucket.data_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# --- 4. Lambda Function ---
# NOTE: For the first run, we use a placeholder variable or manual apply steps
# because the image won't exist in ECR yet.

resource "aws_lambda_function" "pipeline_function" {
  function_name = "${var.project_name}-function"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  
  # We point to the repo we created. 
  # IMPORTANT: You must push an image tagged 'latest' before applying this resource!
  image_uri     = "${aws_ecr_repository.repo.repository_url}:latest"
  
  timeout       = 60 # 1 minute timeout
  memory_size   = 128

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.data_bucket.id
    }
  }
}

# --- 5. EventBridge Scheduler (Cron Job) ---
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "${var.project_name}-daily"
  description         = "Triggers data pipeline daily"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.pipeline_function.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pipeline_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

# --- Outputs ---
output "ecr_repository_url" {
  value = aws_ecr_repository.repo.repository_url
}

output "s3_bucket_name" {
  value = aws_s3_bucket.data_bucket.id
}
