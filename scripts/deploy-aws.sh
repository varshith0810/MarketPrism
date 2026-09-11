#!/usr/bin/env bash
# =====================================================================
# MarketPrism AWS Build & Deploy Script
# Builds multi-stage container and pushes to Amazon ECR
# =====================================================================

set -e

AWS_REGION="${1:-us-east-1}"
REPO_NAME="${2:-marketprism}"
IMAGE_TAG="${3:-latest}"

echo -e "\033[36m=== MarketPrism AWS Deployment Script ===\033[0m"

# 1. Check AWS credentials
echo -e "\n\033[33m[1/5] Checking AWS credentials...\033[0m"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "\033[32mAuthenticated with AWS Account: ${ACCOUNT_ID} (Region: ${AWS_REGION})\033[0m"

REGISTRY_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${REGISTRY_URL}/${REPO_NAME}:${IMAGE_TAG}"

# 2. Check / Create ECR repository
echo -e "\n\033[33m[2/5] Checking ECR repository '${REPO_NAME}'...\033[0m"
if ! aws ecr describe-repositories --repository-names "${REPO_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "Creating ECR repository '${REPO_NAME}'..."
    aws ecr create-repository --repository-name "${REPO_NAME}" --region "${AWS_REGION}" --image-scanning-configuration scanOnPush=true
fi
echo -e "\033[32mECR repository ready.\033[0m"

# 3. Authenticate Docker with ECR
echo -e "\n\033[33m[3/5] Authenticating Docker with ECR...\033[0m"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${REGISTRY_URL}"
echo -e "\033[32mDocker authenticated successfully.\033[0m"

# 4. Build Docker image
echo -e "\n\033[33m[4/5] Building Docker image '${REPO_NAME}:latest'...\033[0m"
docker build -t "${REPO_NAME}:latest" .
docker tag "${REPO_NAME}:latest" "${IMAGE_URI}"

# 5. Push to ECR
echo -e "\n\033[33m[5/5] Pushing image to ECR (${IMAGE_URI})...\033[0m"
docker push "${IMAGE_URI}"

echo -e "\n\033[32mSuccessfully pushed ${IMAGE_URI}\033[0m"
echo -e "\033[36mDeployment triggered if automatic deployment is enabled on your App Runner service.\033[0m"
