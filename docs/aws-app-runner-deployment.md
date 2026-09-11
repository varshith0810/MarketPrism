# AWS Deployment Guide: MarketPrism on AWS App Runner

This guide provides step-by-step instructions to deploy **MarketPrism** (FastAPI backend + NVIDIA Nemotron-3.5-Lightning LLM agent + React frontend) to Amazon Web Services using **AWS App Runner** and **Amazon Elastic Container Registry (ECR)**.

---

## Architecture Overview

```
                          ┌────────────────────────┐
                          │   Client / Browser     │
                          └───────────┬────────────┘
                                      │ HTTPS (Port 443)
                                      ▼
             ┌──────────────────────────────────────────────────┐
             │            AWS App Runner Service                │
             │   (Auto-scaling, Managed TLS, Native Streaming)   │
             │                                                  │
             │   ┌──────────────────────────────────────────┐   │
             │   │       Unified Container (Port 8000)      │   │
             │   │  ┌────────────────────────────────────┐  │   │
             │   │  │   FastAPI Server (Uvicorn)         │  │   │
             │   │  │  - /          -> React SPA         │  │   │
             │   │  │  - /health    -> Health check      │  │   │
             │   │  │  - /api/chat  -> LangGraph Agent   │  │   │
             │   │  └──────────────────┬─────────────────┘  │   │
             │   └─────────────────────┼────────────────────┘   │
             └─────────────────────────┼────────────────────────┘
                                       │ HTTPS / TLS
                                       ▼
                     ┌───────────────────────────────────┐
                     │ NVIDIA NIM Catalog API            │
                     │ (nemotron-3.5-lightning-30b-a3b)  │
                     └───────────────────────────────────┘
```

### Why AWS App Runner for MarketPrism?
- **Fully Managed Containers**: No EC2 instances, VPC subnets, or Kubernetes clusters to configure.
- **Native Server-Sent Events (SSE)**: Supports long-lived streaming responses needed by LLM chat agents.
- **Automatic HTTPS**: Provides a secure `https://<service-id>.<region>.awsapprunner.com` URL and supports custom domains with free auto-renewing SSL certificates.
- **Unified Deployment**: Serves both the compiled React frontend and the FastAPI backend from a single container, eliminating CORS and multi-domain configuration.

---

## Prerequisites

1. **AWS Account**: An active AWS account with administrative permissions.
2. **AWS CLI**: Installed and configured (`aws configure`).
3. **Docker**: Installed and running on your machine.

---

## Step 1: Create Amazon ECR Repository

Amazon ECR stores your container images securely.

```bash
# Set your preferred AWS Region and Repository Name
export AWS_REGION="us-east-1"
export REPO_NAME="marketprism"

# Create the ECR repository
aws ecr create-repository \
    --repository-name $REPO_NAME \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true
```

Take note of the `repositoryUri` from the output (format: `<account-id>.dkr.ecr.<region>.amazonaws.com/marketprism`).

---

## Step 2: Build and Push Docker Image

Authenticate Docker to your ECR registry, build the multi-stage image, and push it:

### On Windows PowerShell:
```powershell
$AWS_REGION = "us-east-1"
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$ECR_URI = "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/marketprism"

# 1. Authenticate Docker with ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# 2. Build the unified container image
docker build -t marketprism:latest .

# 3. Tag the image for ECR
docker tag marketprism:latest "$ECR_URI`:latest"

# 4. Push to ECR
docker push "$ECR_URI`:latest"
```

### On Linux / macOS:
```bash
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/marketprism"

# 1. Authenticate Docker with ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# 2. Build the unified container image
docker build -t marketprism:latest .

# 3. Tag the image for ECR
docker tag marketprism:latest "${ECR_URI}:latest"

# 4. Push to ECR
docker push "${ECR_URI}:latest"
```

---

## Step 3: Store API Secrets in AWS Systems Manager (SSM)

Store your secret keys in AWS Parameter Store as `SecureString` parameters so they are never stored in plaintext:

```bash
# NVIDIA API Key (Required)
aws ssm put-parameter \
    --name "/marketprism/NVIDIA_API_KEY" \
    --value "nvapi-YOUR_ACTUAL_NVIDIA_API_KEY" \
    --type "SecureString" \
    --overwrite

# Langfuse Secret Key (Optional)
aws ssm put-parameter \
    --name "/marketprism/LANGFUSE_SECRET_KEY" \
    --value "sk-lf-YOUR_LANGFUSE_SECRET_KEY" \
    --type "SecureString" \
    --overwrite
```

---

## Step 4: Create the AWS App Runner Service

You can create the service using the AWS Console or the AWS CLI.

### Method A: Via AWS Management Console (Recommended)

1. Open the [AWS App Runner Console](https://console.aws.amazon.com/apprunner).
2. Click **Create service**.
3. **Source**:
   - Repository type: **Container registry**
   - Provider: **Amazon ECR**
   - Container image URI: Click **Browse** and select `marketprism:latest`.
   - Deployment trigger: Choose **Automatic** (deploys whenever a new image is pushed) or **Manual**.
   - ECR access role: Select **Create new service role** (App Runner will configure the IAM policy automatically).
4. Click **Next**.
5. **Configure service**:
   - **Service name**: `marketprism-prod`
   - **Virtual CPU & Memory**: `1 vCPU, 2 GB` (or `2 vCPU, 4 GB` for heavier load)
   - **Port**: `8000`
   - **Environment variables**:
     | Key | Value |
     | :--- | :--- |
     | `MODEL_NAME` | `nvidia/nemotron-3.5-lightning-30b-a3b` |
     | `MODEL_TEMPERATURE` | `0.2` |
     | `NVIDIA_BASE_URL` | `https://integrate.api.nvidia.com/v1` |
     | `LANGFUSE_PUBLIC_KEY` | *(Your public key, if using Langfuse)* |
     | `LANGFUSE_HOST` | `https://cloud.langfuse.com` |
   - **Environment secrets**:
     | Key | SSM Parameter ARN / Reference |
     | :--- | :--- |
     | `NVIDIA_API_KEY` | `arn:aws:ssm:<region>:<account-id>:parameter/marketprism/NVIDIA_API_KEY` |
     | `LANGFUSE_SECRET_KEY` | `arn:aws:ssm:<region>:<account-id>:parameter/marketprism/LANGFUSE_SECRET_KEY` |
   - **Health check**:
     - Protocol: `HTTP`
     - Path: `/health`
     - Interval: `10 seconds`
     - Timeout: `5 seconds`
     - Healthy threshold: `1`
     - Unhealthy threshold: `3`
6. Click **Next**, review configuration, and click **Create & deploy**.

App Runner will provision the service and output a public HTTPS URL (e.g., `https://xxxxxx.us-east-1.awsapprunner.com`).

---

## Step 5: Verify the Deployment

Once the service status transitions to **Running**:

1. **Test Health Endpoint**:
   ```bash
   curl -i https://<your-apprunner-domain>/health
   # Expected response: {"status":"ok","message":"Service is running"}
   ```

2. **Test Chat API**:
   ```bash
   curl -X POST https://<your-apprunner-domain>/api/chat \
     -H "Content-Type: application/json" \
     -d '{
       "prompt": {"content": "What is the stock price of Apple?", "id": "1", "role": "user"},
       "threadId": "test-session",
       "responseId": "resp-1"
     }'
   ```

3. **Open the Web Application**:
   Navigate to `https://<your-apprunner-domain>` in any browser. The full MarketPrism React interface will load and stream real-time financial data directly through your App Runner backend!

---

## Step 6: Custom Domain & SSL (Optional)

To use your own domain (e.g., `marketprism.yourdomain.com`):

1. Go to your service in the **App Runner Console**.
2. Click the **Custom domains** tab and click **Link domain**.
3. Enter your domain name (e.g., `marketprism.yourdomain.com`).
4. App Runner generates DNS validation CNAME records.
5. Add these CNAME records to your DNS provider (Route 53, Cloudflare, GoDaddy, etc.).
6. Once validated, AWS automatically provisions and renews an ACM SSL certificate.
