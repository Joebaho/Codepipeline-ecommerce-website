# AWS CodePipeline E-Commerce Website on ECS

This repository now provisions an AWS-native deployment path for the
[Google microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo)
application.

The old Jenkins on EC2 + EKS + Docker Hub flow has been removed. The project
now uses:

- Amazon ECR for application images
- Amazon ECS on Fargate for runtime
- AWS CodeBuild to build and deploy the containers
- AWS CodePipeline to orchestrate source, build, and deployment
- Terraform to provision the full infrastructure

## Architecture

Terraform creates:

- a VPC with public and private subnets
- an internet gateway and NAT gateway
- an ECS cluster running on Fargate
- Cloud Map service discovery for internal service-to-service traffic
- an application load balancer for the storefront frontend
- one ECR repository per application image
- IAM roles for ECS, CodeBuild, and CodePipeline
- an S3 artifact bucket for CodePipeline
- a CodeStar connection for GitHub source integration
- a CodePipeline pipeline with build and deploy stages

CodePipeline then works like this:

1. pulls this repository from GitHub
2. triggers CodeBuild to clone `microservices-demo`
3. builds the service images
4. pushes those images to Amazon ECR
5. registers fresh ECS task definitions
6. updates the ECS services and waits for them to stabilize

## Repository Structure

```text
.
├── buildspec-build.yml
├── buildspec-deploy.yml
├── README.md
└── terraform/
    ├── backend.tf
    ├── codepipeline.tf
    ├── ecs.tf
    ├── iam.tf
    ├── locals.tf
    ├── outputs.tf
    ├── providers.tf
    ├── variables.tf
    └── vpc.tf
```

## Defaults

- AWS region: `us-west-2`
- project name: `online-boutique`
- GitHub branch: `main`
- upstream application repo: `https://github.com/GoogleCloudPlatform/microservices-demo.git`
- upstream application ref: `v0.6.0`
- private discovery namespace: `boutique.local`
- Terraform backend bucket: `baho-backup-bucket`
- Terraform backend key: `Codepipeline-ecommerce`
- Terraform backend lock table: `Codepipeline-ecommerce-table`

## Before You Apply

You need:

- an AWS account with access to VPC, ECS, ECR, IAM, CodeBuild, CodePipeline, S3, CloudWatch, and CodeStar Connections
- Terraform 1.x or newer
- AWS CLI configured locally
- a GitHub repository connected to this codebase

Check your local AWS access:

```bash
aws sts get-caller-identity
terraform version
```

## Important Variables

The most important values to review are in
[`terraform/variables.tf`](/Users/josephmbatchou/Documents/Codepipeline-ecommerce-website/terraform/variables.tf):

- `project_name`
- `github_full_repository_id`
- `github_branch`
- `codestar_connection_name`
- `microservices_repo`
- `microservices_ref`
- `frontend_desired_count`
- `default_service_desired_count`
- `loadgenerator_desired_count`

Set `github_full_repository_id` to your actual GitHub repository in
`owner/repo` format before applying.

## Deploy the Infrastructure

From the Terraform directory:

```bash
cd /Users/josephmbatchou/Documents/Codepipeline-ecommerce-website/terraform
terraform init \
  -backend-config="bucket=baho-backup-bucket" \
  -backend-config="key=Codepipeline-ecommerce" \
  -backend-config="region=us-west-2" \
  -backend-config="dynamodb_table=Codepipeline-ecommerce-table" \
  -backend-config="encrypt=true"
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

After apply, check:

```bash
terraform output
```

Key outputs:

- `codepipeline_name`
- `codestar_connection_arn`
- `ecs_cluster_name`
- `frontend_url`
- `ecr_repository_urls`

## Complete the GitHub Connection

Terraform creates the CodeStar connection object, but AWS still requires a
manual authorization step in the console.

After `terraform apply`:

1. open AWS Developer Tools
2. go to `Settings` -> `Connections`
3. select the created connection
4. finish the GitHub authorization handshake

Until that is completed, CodePipeline source actions will remain blocked.

## Trigger a Deployment

Once the CodeStar connection is authorized:

1. push a commit to the configured GitHub branch
2. CodePipeline will start automatically
3. CodeBuild will build the microservice images and push them to ECR
4. the deploy stage will update the ECS services

You can also start the pipeline manually from the AWS console or with the AWS
CLI:

```bash
aws codepipeline start-pipeline-execution \
  --name online-boutique-pipeline
```

## Operational Notes

- The frontend is exposed through the ALB output in `frontend_url`.
- Backend services talk to each other through Cloud Map DNS names such as
  `checkoutservice.boutique.local`.
- Redis uses a public ECR Redis image instead of Docker Hub.
- The optional `loadgenerator` service defaults to `0` tasks so it does not
  generate traffic unless you enable it.
- Pipeline-driven task definition updates are intentionally left unmanaged on
  the ECS service resource, so Terraform does not roll deployments backward on
  the next plan.

## Cleanup

To remove the stack:

```bash
cd /Users/josephmbatchou/Documents/Codepipeline-ecommerce-website/terraform
terraform destroy
```

## Files to Review

- [`buildspec-build.yml`](/Users/josephmbatchou/Documents/Codepipeline-ecommerce-website/buildspec-build.yml)
- [`buildspec-deploy.yml`](/Users/josephmbatchou/Documents/Codepipeline-ecommerce-website/buildspec-deploy.yml)
- [`terraform/codepipeline.tf`](/Users/josephmbatchou/Documents/Codepipeline-ecommerce-website/terraform/codepipeline.tf)
- [`terraform/ecs.tf`](/Users/josephmbatchou/Documents/Codepipeline-ecommerce-website/terraform/ecs.tf)
- [`terraform/locals.tf`](/Users/josephmbatchou/Documents/Codepipeline-ecommerce-website/terraform/locals.tf)
