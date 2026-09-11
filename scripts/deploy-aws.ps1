<#
.SYNOPSIS
    Automated build, tag, and push script for AWS App Runner deployment.
.DESCRIPTION
    Builds the MarketPrism multi-stage container and pushes it to Amazon ECR.
.PARAMETER Region
    The AWS region (defaults to us-east-1).
.PARAMETER RepositoryName
    The ECR repository name (defaults to marketprism).
.PARAMETER ImageTag
    The image tag (defaults to latest).
#>
param(
    [string]$Region = "us-east-1",
    [string]$RepositoryName = "marketprism",
    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Continue"

Write-Host "=== MarketPrism AWS Deployment Script ===" -ForegroundColor Cyan

# 1. Check AWS CLI and credentials
Write-Host "`n[1/5] Checking AWS credentials..." -ForegroundColor Yellow
$Account = (aws sts get-caller-identity --query Account --output text)
if ($LASTEXITCODE -ne 0 -or -not $Account) {
    Write-Error "Failed to authenticate with AWS CLI. Run 'aws login' or 'aws configure' first."
    exit 1
}
Write-Host "Authenticated with AWS Account: $Account (Region: $Region)" -ForegroundColor Green

$RegistryUrl = "$Account.dkr.ecr.$Region.amazonaws.com"
$ImageUri = "$RegistryUrl/$RepositoryName`:$ImageTag"

# 2. Ensure ECR repository exists
Write-Host "`n[2/5] Checking ECR repository '$RepositoryName'..." -ForegroundColor Yellow
$null = aws ecr describe-repositories --repository-names $RepositoryName --region $Region 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Repository not found. Creating ECR repository '$RepositoryName'..." -ForegroundColor Yellow
    aws ecr create-repository --repository-name $RepositoryName --region $Region --image-scanning-configuration scanOnPush=true | Out-Null
    Write-Host "Created ECR repository." -ForegroundColor Green
} else {
    Write-Host "ECR repository exists." -ForegroundColor Green
}

# 3. Authenticate Docker with ECR
Write-Host "`n[3/5] Authenticating Docker with ECR..." -ForegroundColor Yellow
cmd /c "aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $RegistryUrl"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker login failed."
}
Write-Host "Docker login succeeded." -ForegroundColor Green

# 4. Build Docker image
Write-Host "`n[4/5] Building Docker image '$RepositoryName`:latest'..." -ForegroundColor Yellow
docker build -t "$RepositoryName`:latest" .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed."
}

Write-Host "Tagging image for ECR: $ImageUri" -ForegroundColor Yellow
docker tag "$RepositoryName`:latest" $ImageUri

# 5. Push to ECR
Write-Host "`n[5/5] Pushing image to ECR..." -ForegroundColor Yellow
docker push $ImageUri
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker push failed."
}

Write-Host "`nSuccessfully pushed image to ECR: $ImageUri" -ForegroundColor Green
Write-Host "If automatic deployment is enabled on your App Runner service, a new deployment has started." -ForegroundColor Cyan
Write-Host "Otherwise, trigger deployment in the AWS App Runner console or run:" -ForegroundColor Cyan
Write-Host "aws apprunner start-deployment --service-arn <your-service-arn> --region $Region" -ForegroundColor Gray
