<#
.SYNOPSIS
    Ultra Cost-Effective Serverless AWS Deployment Script for MarketPrism
.DESCRIPTION
    Deploys MarketPrism to AWS Lambda Container with AWS Lambda Web Adapter and Function URL.
    - $0.00 / month idle cost (zero requests = zero billing).
    - Permanent AWS Lambda Free Tier (1M requests & 400,000 GB-seconds free every month).
    - Native real-time SSE token streaming from the NVIDIA Nemotron agent via RESPONSE_STREAM.
    - Single unified container serving both FastAPI backend and React frontend.
.PARAMETER Region
    The AWS region (defaults to ap-south-1).
.PARAMETER FunctionName
    The Lambda function name (defaults to marketprism).
#>
param(
    [string]$Region = "ap-south-1",
    [string]$FunctionName = "marketprism"
)

$ErrorActionPreference = "Continue"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   MarketPrism Cost-Effective AWS Serverless Deployment   " -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

# 1. Check AWS credentials
Write-Host "[1/7] Checking AWS credentials..." -ForegroundColor Yellow
$Account = (aws sts get-caller-identity --query Account --output text)
if ($LASTEXITCODE -ne 0 -or -not $Account) {
    Write-Error "Failed to authenticate with AWS CLI. Please run 'aws login' or 'aws configure' first."
    exit 1
}
Write-Host "Authenticated as AWS Account: $Account (Region: $Region)" -ForegroundColor Green

$RegistryUrl = "$Account.dkr.ecr.$Region.amazonaws.com"
$ImageUri = "$RegistryUrl/$FunctionName`:latest"

# 2. Parse environment variables from .env
Write-Host "`n[2/7] Loading environment variables from .env..." -ForegroundColor Yellow
$EnvFile = Join-Path $PSScriptRoot "..\\.env"
$EnvVars = @{}
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $k = $parts[0].Trim()
            $v = $parts[1].Trim().Trim('"').Trim("'")
            $EnvVars[$k] = $v
        }
    }
}

$NvidiaKey = if ($EnvVars.ContainsKey("NVIDIA_API_KEY")) { $EnvVars["NVIDIA_API_KEY"] } else { "nvapi-not-set" }
$NvidiaBase = if ($EnvVars.ContainsKey("NVIDIA_BASE_URL")) { $EnvVars["NVIDIA_BASE_URL"] } else { "https://integrate.api.nvidia.com/v1" }
$ModelName = if ($EnvVars.ContainsKey("MODEL_NAME")) { $EnvVars["MODEL_NAME"] } else { "nvidia/nemotron-3.5-lightning-30b-a3b" }
$ModelTemp = if ($EnvVars.ContainsKey("MODEL_TEMPERATURE")) { $EnvVars["MODEL_TEMPERATURE"] } else { "0.2" }
$LangfusePub = if ($EnvVars.ContainsKey("LANGFUSE_PUBLIC_KEY")) { $EnvVars["LANGFUSE_PUBLIC_KEY"] } else { "" }
$LangfuseSec = if ($EnvVars.ContainsKey("LANGFUSE_SECRET_KEY")) { $EnvVars["LANGFUSE_SECRET_KEY"] } else { "" }
$LangfuseHost = if ($EnvVars.ContainsKey("LANGFUSE_BASE_URL")) { $EnvVars["LANGFUSE_BASE_URL"] } else { "https://cloud.langfuse.com" }

Write-Host "Model configured: $ModelName" -ForegroundColor Green

# 3. Ensure ECR repository exists with cost-saving lifecycle policy
Write-Host "`n[3/7] Ensuring ECR repository exists..." -ForegroundColor Yellow
$null = aws ecr describe-repositories --repository-names $FunctionName --region $Region 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating ECR repository '$FunctionName'..." -ForegroundColor Yellow
    aws ecr create-repository --repository-name $FunctionName --region $Region --image-scanning-configuration scanOnPush=true | Out-Null
    
    # Cost optimization: keep only 1 image to save on storage
    $lifecyclePolicy = '{"rules":[{"rulePriority":1,"description":"Retain only latest image","selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":1},"action":{"type":"expire"}}]}'
    aws ecr put-lifecycle-policy --repository-name $FunctionName --region $Region --lifecycle-policy-text $lifecyclePolicy | Out-Null
    Write-Host "Created ECR repository with storage-saving lifecycle policy." -ForegroundColor Green
} else {
    Write-Host "ECR repository exists." -ForegroundColor Green
}

# 4. Authenticate Docker and Push Image
Write-Host "`n[4/7] Authenticating Docker and pushing image to ECR..." -ForegroundColor Yellow
cmd /c "aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $RegistryUrl"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker login to ECR failed."
    exit 1
}

# Build with --provenance=false so AWS Lambda receives a single OCI manifest instead of an attestation index
Write-Host "Building Docker image with --provenance=false for AWS Lambda compatibility..." -ForegroundColor Yellow
docker build --provenance=false -t "$FunctionName`:latest" .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed."
    exit 1
}

Write-Host "Tagging image: $ImageUri" -ForegroundColor Yellow
docker tag "$FunctionName`:latest" $ImageUri
docker push $ImageUri
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push image to ECR."
    exit 1
}
Write-Host "Image successfully pushed to ECR." -ForegroundColor Green

# 5. Ensure IAM Lambda Execution Role exists
Write-Host "`n[5/7] Configuring IAM Lambda execution role..." -ForegroundColor Yellow
$RoleName = "$FunctionName-lambda-role"
$RoleArn = (aws iam get-role --role-name $RoleName --query "Role.Arn" --output text 2>$null)

if (-not $RoleArn) {
    Write-Host "Creating IAM role '$RoleName'..." -ForegroundColor Yellow
    $TrustPolicy = '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"lambda.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}'
    $RoleArn = (aws iam create-role --role-name $RoleName --assume-role-policy-document $TrustPolicy --query "Role.Arn" --output text)
    aws iam attach-role-policy --role-name $RoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" | Out-Null
    Write-Host "Waiting 10 seconds for IAM role propagation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
}
Write-Host "IAM Role ready: $RoleArn" -ForegroundColor Green

# Format environment variables via temporary JSON file for robust escaping
$EnvObj = @{
    Variables = @{
        NVIDIA_API_KEY       = $NvidiaKey
        NVIDIA_BASE_URL      = $NvidiaBase
        MODEL_NAME           = $ModelName
        MODEL_TEMPERATURE    = $ModelTemp
        LANGFUSE_PUBLIC_KEY  = $LangfusePub
        LANGFUSE_SECRET_KEY  = $LangfuseSec
        LANGFUSE_HOST        = $LangfuseHost
        AWS_LWA_INVOKE_MODE           = "response_stream"
        AWS_LWA_PORT                  = "8000"
        AWS_LWA_ASYNC_INIT            = "true"
        AWS_LWA_READINESS_CHECK_PATH  = "/health"
    }
}
$TempEnvPath = Join-Path ([System.IO.Path]::GetTempPath()) "lambda-env-$FunctionName.json"
[System.IO.File]::WriteAllText($TempEnvPath, ($EnvObj | ConvertTo-Json))
$FileArg = "file://$TempEnvPath"

# 6. Create or Update Lambda Function
Write-Host "`n[6/7] Deploying Lambda function '$FunctionName'..." -ForegroundColor Yellow
$ExistingFunction = aws lambda get-function --function-name $FunctionName --region $Region 2>$null

if (-not $ExistingFunction) {
    Write-Host "Creating new Lambda function '$FunctionName'..." -ForegroundColor Yellow
    aws lambda create-function `
        --function-name $FunctionName `
        --package-type Image `
        --code ImageUri=$ImageUri `
        --role $RoleArn `
        --timeout 300 `
        --memory-size 1536 `
        --region $Region `
        --environment $FileArg | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create Lambda function."
        exit 1
    }
} else {
    Write-Host "Updating existing Lambda function code..." -ForegroundColor Yellow
    aws lambda update-function-code `
        --function-name $FunctionName `
        --image-uri $ImageUri `
        --region $Region | Out-Null

    # Wait for function update to complete
    Write-Host "Waiting for function update to complete..." -ForegroundColor Yellow
    while ($true) {
        $status = (aws lambda get-function --function-name $FunctionName --region $Region --query "Configuration.LastUpdateStatus" --output text 2>$null)
        if ($status -eq "Successful" -or $status -eq "Failed") { break }
        Start-Sleep -Seconds 3
    }

    Write-Host "Updating Lambda function configuration..." -ForegroundColor Yellow
    aws lambda update-function-configuration `
        --function-name $FunctionName `
        --timeout 300 `
        --memory-size 1536 `
        --region $Region `
        --environment $FileArg | Out-Null
}

Remove-Item -Path $TempEnvPath -ErrorAction SilentlyContinue

# Wait for function to be active
Write-Host "Waiting for Lambda function to become Active..." -ForegroundColor Yellow
while ($true) {
    $state = (aws lambda get-function --function-name $FunctionName --region $Region --query "Configuration.State" --output text 2>$null)
    if ($state -eq "Active") { break }
    Start-Sleep -Seconds 3
}
Write-Host "Lambda function is Active." -ForegroundColor Green

# 7. Configure Lambda Function URL with RESPONSE_STREAM
Write-Host "`n[7/7] Configuring public streaming Function URL..." -ForegroundColor Yellow
$UrlConfig = aws lambda get-function-url-config --function-name $FunctionName --region $Region 2>$null

if (-not $UrlConfig) {
    Write-Host "Creating Function URL with response streaming enabled..." -ForegroundColor Yellow
    aws lambda create-function-url-config `
        --function-name $FunctionName `
        --auth-type NONE `
        --invoke-mode RESPONSE_STREAM `
        --region $Region | Out-Null

    # Grant public unauthenticated access to the Function URL
    aws lambda add-permission `
        --function-name $FunctionName `
        --statement-id "FunctionURLAllowPublicAccess" `
        --action "lambda:InvokeFunctionUrl" `
        --principal "*" `
        --function-url-auth-type "NONE" `
        --region $Region | Out-Null
} else {
    # Ensure invoke mode is RESPONSE_STREAM
    aws lambda update-function-url-config `
        --function-name $FunctionName `
        --auth-type NONE `
        --invoke-mode RESPONSE_STREAM `
        --region $Region | Out-Null
}

$FunctionUrl = (aws lambda get-function-url-config --function-name $FunctionName --region $Region --query "FunctionUrl" --output text)

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "            DEPLOYMENT SUCCESSFUL!                      " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Public Web Application URL: $FunctionUrl" -ForegroundColor Cyan
Write-Host "`nCost Breakdown:" -ForegroundColor Yellow
Write-Host "- Idle Cost:               `$0.00 / month (Zero requests = zero charge)" -ForegroundColor White
Write-Host "- Free Tier Allocation:    1,000,000 requests/month + 400,000 GB-seconds/month (Free forever)" -ForegroundColor White
Write-Host "- SSE Token Streaming:     Native RESPONSE_STREAM via Lambda Function URL" -ForegroundColor White
Write-Host "- Timeout:                 300 seconds (5 minutes)" -ForegroundColor White
Write-Host "`nVerify your deployment:" -ForegroundColor Yellow
Write-Host "curl -i $FunctionUrl`health" -ForegroundColor Gray
Write-Host "========================================================`n" -ForegroundColor Green
