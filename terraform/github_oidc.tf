# 1. GitHub OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # Standard thumbprint for GitHub Actions OIDC
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c582ced5f0c8dd8220f12c1b85f269a888c3a1e"]
}

# 2. IAM Role Assumed by GitHub Actions
resource "aws_iam_role" "github_actions_deployer" {
  name = "github-actions-deployer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Matches any branch or action run in this specific repository
            "token.actions.githubusercontent.com:sub" = "repo:Anyah11/production-platform-blueprint:*"
          }
        }
      }
    ]
  })
}

# 3. Policy for ECR Push & EKS Describe Access
resource "aws_iam_policy" "github_actions_policy" {
  name        = "github-actions-deployer-policy"
  description = "Allows pushing to ECR and updating kubeconfig for EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:us-east-1:444301975580:repository/sre-demo-api"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = "arn:aws:eks:us-east-1:444301975580:cluster/platform-eks-cluster"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions_deployer.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_deployer.arn
  description = "ARN of IAM Role for GitHub Actions"
}