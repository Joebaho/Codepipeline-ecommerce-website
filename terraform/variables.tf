variable "aws_region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name prefix for the AWS resources that back the application."
  type        = string
  default     = "online-boutique"
}

variable "service_discovery_namespace" {
  description = "Private DNS namespace used by ECS services for internal service-to-service traffic."
  type        = string
  default     = "boutique.local"
}

variable "github_full_repository_id" {
  description = "GitHub repository in owner/repo format used as the CodePipeline source."
  type        = string
  default     = "Joebaho/Codepipeline-ecommerce-website"
}

variable "github_branch" {
  description = "Git branch tracked by CodePipeline."
  type        = string
  default     = "main"
}

variable "codestar_connection_name" {
  description = "Name of the CodeStar connection used by CodePipeline to read GitHub."
  type        = string
  default     = "online-boutique-github"
}

variable "dockerhub_secret_name" {
  description = "Secrets Manager secret that stores Docker Hub credentials as JSON keys Dockerhub-username and Dockerhub-password."
  type        = string
  default     = "Dockerhub-creds"
}

variable "microservices_repo" {
  description = "Upstream microservices-demo repository cloned by CodeBuild."
  type        = string
  default     = "https://github.com/GoogleCloudPlatform/microservices-demo.git"
}

variable "microservices_ref" {
  description = "Branch or tag in the upstream microservices-demo repository."
  type        = string
  default     = "v0.6.0"
}

variable "frontend_desired_count" {
  description = "Number of frontend tasks to keep running."
  type        = number
  default     = 2
}

variable "default_service_desired_count" {
  description = "Default desired task count for internal backend services."
  type        = number
  default     = 1
}

variable "loadgenerator_desired_count" {
  description = "Desired count for the optional loadgenerator service. Set to 0 to disable it."
  type        = number
  default     = 0
}

variable "enable_container_insights" {
  description = "Enable ECS Container Insights on the cluster."
  type        = bool
  default     = true
}
