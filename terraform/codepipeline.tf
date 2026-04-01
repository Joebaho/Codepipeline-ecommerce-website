resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "${var.project_name}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-artifacts"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_codestarconnections_connection" "github" {
  name          = var.codestar_connection_name
  provider_type = "GitHub"
}

resource "aws_codebuild_project" "images" {
  name          = "${var.project_name}-images"
  description   = "Builds and pushes the microservices-demo images to ECR."
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 60

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "MICROSERVICES_REPO"
      value = var.microservices_repo
    }

    environment_variable {
      name  = "MICROSERVICES_REF"
      value = var.microservices_ref
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "DOCKERHUB_USERNAME"
      type  = "SECRETS_MANAGER"
      value = "${var.dockerhub_secret_name}:Dockerhub-username"
    }

    environment_variable {
      name  = "DOCKERHUB_PASSWORD"
      type  = "SECRETS_MANAGER"
      value = "${var.dockerhub_secret_name}:Dockerhub-password"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/codebuild/${var.project_name}"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-build.yml"
  }
}

resource "aws_codebuild_project" "deploy" {
  name          = "${var.project_name}-deploy"
  description   = "Registers new task definitions and deploys them to ECS."
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 60

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "ECS_CLUSTER"
      value = aws_ecs_cluster.main.name
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/codebuild/${var.project_name}"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-deploy.yml"
  }
}

resource "aws_codepipeline" "app" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = var.github_full_repository_id
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAndPushImages"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.images.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployToEcs"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output", "build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.deploy.name
      }
    }
  }
}
