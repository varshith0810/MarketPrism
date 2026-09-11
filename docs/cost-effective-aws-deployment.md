# Cost-Effective Serverless AWS Deployment Guide for MarketPrism

This guide documents the ultra cost-effective serverless deployment of **MarketPrism** on Amazon Web Services using **AWS Lambda (Container Image)** with the **AWS Lambda Web Adapter** and **Lambda Function URLs (Response Streaming)**.

---

## Architecture Overview

```
                      ┌────────────────────────┐
                      │   Client / Browser     │
                      └───────────┬────────────┘
                                  │ HTTPS / Native SSE Streaming
                                  ▼
         ┌────────────────────────────────────────────────────────┐
         │              AWS Lambda Function URL                   │
         │   (https://<id>.lambda-url.ap-south-1.on.aws)          │
         │                                                        │
         │   ┌────────────────────────────────────────────────┐   │
         │   │            AWS Lambda Container microVM        │   │
         │   │   ┌────────────────────────────────────────┐   │   │
         │   │   │  AWS Lambda Web Adapter Extension      │   │   │
         │   │   │  (Listens on Port 8000, RESPONSE_STREAM)│  │   │
         │   │   └──────────────────┬─────────────────────┘   │   │
         │   │                      │ Reverse proxy           │   │
         │   │   ┌──────────────────▼─────────────────────┐   │   │
         │   │   │  FastAPI Application (Uvicorn)         │   │   │
         │   │   │  - /          -> React SPA static files │   │   │
         │   │   │  - /health    -> Health check          │   │   │
         │   │   │  - /api/chat  -> LangGraph Agent SSE   │   │   │
         │   │   └──────────────────┬─────────────────────┘   │   │
         │   └──────────────────────┼─────────────────────────┘   │
         └──────────────────────────┼─────────────────────────────┘
                                    │ HTTPS
                                    ▼
                  ┌───────────────────────────────────┐
                  │ NVIDIA NIM Catalog API            │
                  │ (nemotron-3.5-lightning-30b-a3b)  │
                  └───────────────────────────────────┘
```

---

## Cost Comparison: Why This Saves You Money

| Component | Previous (AWS App Runner) | New (AWS Lambda Serverless Container) |
| :--- | :--- | :--- |
| **Idle Hosting Cost** | ~$10 - $25 / month | **$0.00 / month** (Billed $0 when idle) |
| **Active Compute Cost** | ~$0.078 / hour active (~$56/mo) | Pay only per millisecond of request execution |
| **Permanent Free Tier** | None (charges from day 1) | **1,000,000 requests/mo + 400,000 GB-seconds/mo free forever** |
| **Container Storage (ECR)** | Standard private repository | Storage-saving lifecycle policy (keeps only the latest image) |
| **Real-time SSE Streaming** | Native HTTP streaming | **Native `RESPONSE_STREAM` via Function URL** |
| **Estimated Monthly Bill** | **$25.00 – $56.00+** | **$0.00 – $0.50** |

---

## Deployed Endpoints

* **Public Web Application:**
  `https://m2gb43bpkfy53jo6b3zp5wkcxy0sjuuz.lambda-url.ap-south-1.on.aws/`
* **Health Check Endpoint:**
  `https://m2gb43bpkfy53jo6b3zp5wkcxy0sjuuz.lambda-url.ap-south-1.on.aws/health`
* **Chat Streaming API:**
  `https://m2gb43bpkfy53jo6b3zp5wkcxy0sjuuz.lambda-url.ap-south-1.on.aws/api/chat`

---

## How to Redeploy or Update

Whenever you make changes to the frontend or backend, run the automated deployment script:

### On Windows PowerShell:
```powershell
.\scripts\deploy-cost-effective.ps1
```

### On Linux / macOS:
```bash
chmod +x ./scripts/deploy-cost-effective.sh
./scripts/deploy-cost-effective.sh
```

The script automatically:
1. Builds the multi-stage Docker container with `--provenance=false`.
2. Authenticates and pushes the updated image to Amazon ECR.
3. Deploys the updated image to AWS Lambda.
4. Ensures the public streaming Function URL is configured and active.

---

## Monitoring and Logs

View real-time application logs using the AWS CLI:
```bash
aws logs tail /aws/lambda/marketprism --region ap-south-1 --follow
```
