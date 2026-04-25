# Step Functions per docs/05-aws-services.md §9
# State machine: tng-model-release

resource "aws_iam_role" "step_functions" {
  name = "tng-step-functions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "states.${var.aws_region}.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "step_functions" {
  name = "tng-step-functions-policy"
  role = aws_iam_role.step_functions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow"; Action = ["lambda:InvokeFunction"]; Resource = "*" },
      { Effect = "Allow"; Action = ["s3:GetObject", "s3:PutObject"]; Resource = "${aws_s3_bucket.models.arn}/*" },
    ]
  })
}

resource "aws_sfn_state_machine" "model_release" {
  name     = "tng-model-release"
  role_arn = aws_iam_role.step_functions.arn
  tags     = local.common_tags

  definition = jsonencode({
    Comment = "TNG Model Release Pipeline"
    StartAt = "ConvertToTFLite"
    States = {
      ConvertToTFLite = {
        Type       = "Task"
        Resource   = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.model_publish_bridge.function_name }
        Next       = "SignArtifact"
      }
      SignArtifact = {
        Type       = "Task"
        Resource   = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.model_publish_bridge.function_name }
        Next       = "CopyToAlibabaOSS"
      }
      CopyToAlibabaOSS = {
        Type       = "Task"
        Resource   = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.model_publish_bridge.function_name }
        Next       = "BumpPolicyVersion"
      }
      BumpPolicyVersion = {
        Type       = "Task"
        Resource   = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.model_publish_bridge.function_name }
        Next       = "NotifyMobilePush"
      }
      NotifyMobilePush = {
        Type = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.model_publish_bridge.function_name }
        End  = true
      }
    }
  })
}

output "state_machine_arn" { value = aws_sfn_state_machine.model_release.arn }
