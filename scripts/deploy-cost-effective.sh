#!/usr/bin/env bash
set -e

REGION="${1:-ap-south-1}"
FUNCTION_NAME="${2:-marketprism}"

echo "========================================================"
echo "   MarketPrism Cost-Effective AWS Serverless Deployment   "
echo "========================================================"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${REGISTRY_URL}/${FUNCTION_NAME}:latest"

# Ensure ECR repo exists
aws ecr describe-repositories --repository-names "${FUNCTION_NAME}" --region "${REGION}" >/dev/null 2>&1 || {
    aws ecr create-repository --repository-name "${FUNCTION_NAME}" --region "${REGION}" --image-scanning-configuration scanOnPush=true
    aws ecr put-lifecycle-policy --repository-name "${FUNCTION_NAME}" --region "${REGION}" \
        --lifecycle-policy-text '{"rules":[{"rulePriority":1,"description":"Retain only latest image","selection":{"tagStatus":"any","countType":"imageCountMoreThan","countNumber":1},"action":{"type":"expire"}}]}'
}

# Login, build, and push
aws ecr get-login-password --region "${REGION}" | docker login --username AWS --password-stdin "${REGISTRY_URL}"
docker build -t "${FUNCTION_NAME}:latest" .
docker tag "${FUNCTION_NAME}:latest" "${IMAGE_URI}"
docker push "${IMAGE_URI}"

# IAM Role
ROLE_NAME="${FUNCTION_NAME}-lambda-role"
ROLE_ARN=$(aws iam get-role --role-name "${ROLE_NAME}" --query "Role.Arn" --output text 2>/dev/null || true)

if [ -z "${ROLE_ARN}" ] || [ "${ROLE_ARN}" = "None" ]; then
    ROLE_ARN=$(aws iam create-role --role-name "${ROLE_NAME}" \
        --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
        --query "Role.Arn" --output text)
    aws iam attach-role-policy --role-name "${ROLE_NAME}" --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    sleep 10
fi

# Deploy Lambda
aws lambda get-function --function-name "${FUNCTION_NAME}" --region "${REGION}" >/dev/null 2>&1 && {
    aws lambda update-function-code --function-name "${FUNCTION_NAME}" --image-uri "${IMAGE_URI}" --region "${REGION}" >/dev/null
    aws lambda wait function-updated --function-name "${FUNCTION_NAME}" --region "${REGION}"
} || {
    aws lambda create-function \
        --function-name "${FUNCTION_NAME}" \
        --package-type Image \
        --code ImageUri="${IMAGE_URI}" \
        --role "${ROLE_ARN}" \
        --timeout 300 \
        --memory-size 1536 \
        --region "${REGION}" >/dev/null
    aws lambda wait function-active-v2 --function-name "${FUNCTION_NAME}" --region "${REGION}"
}

# Function URL with RESPONSE_STREAM
aws lambda get-function-url-config --function-name "${FUNCTION_NAME}" --region "${REGION}" >/dev/null 2>&1 || {
    aws lambda create-function-url-config \
        --function-name "${FUNCTION_NAME}" \
        --auth-type NONE \
        --invoke-mode RESPONSE_STREAM \
        --region "${REGION}" >/dev/null
    aws lambda add-permission \
        --function-name "${FUNCTION_NAME}" \
        --statement-id "FunctionURLAllowPublicAccess" \
        --action "lambda:InvokeFunctionUrl" \
        --principal "*" \
        --function-url-auth-type "NONE" \
        --region "${REGION}" >/dev/null
}

URL=$(aws lambda get-function-url-config --function-name "${FUNCTION_NAME}" --region "${REGION}" --query "FunctionUrl" --output text)
echo "DEPLOYMENT COMPLETE! URL: ${URL}"
