output "codepipeline_name" {
  value = aws_codepipeline.app.name
}

output "codestar_connection_arn" {
  value = aws_codestarconnections_connection.github.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "frontend_url" {
  value = "http://${aws_lb.frontend.dns_name}"
}

output "ecr_repository_urls" {
  value = {
    for service, repo in aws_ecr_repository.services : service => repo.repository_url
  }
}
