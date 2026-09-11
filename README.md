# MarketPrism

[![Live Demo](https://img.shields.io/badge/Live%20Demo-marketprism--ai-orange?style=for-the-badge&logo=amazon-aws)](https://tinyurl.com/marketprism-ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11](https://img.shields.io/badge/python-3.11-blue.svg)](https://www.python.org/downloads/release/python-3110/)
[![React](https://img.shields.io/badge/React-18-61dafb.svg?logo=react)](https://reactjs.org/)

An AI-powered stock market analysis platform that provides comprehensive financial data and intelligent insights through a real-time conversational interface.

🔗 **Live Website:** [https://tinyurl.com/marketprism-ai](https://tinyurl.com/marketprism-ai)  
*(Direct AWS Endpoint: [https://m2gb43bpkfy53jo6b3zp5wkcxy0sjuuz.lambda-url.ap-south-1.on.aws/](https://m2gb43bpkfy53jo6b3zp5wkcxy0sjuuz.lambda-url.ap-south-1.on.aws/))*


---

## Overview

MarketPrism leverages advanced AI agents to deliver real-time stock market information, financial analysis, and investment insights. The platform combines the power of LangChain, LangGraph, and NVIDIA's Nemotron-3.5-Lightning-30B-A3B language model with Yahoo Finance data to create an intelligent assistant for stock market research.

## Technology Stack

**Backend:**
- FastAPI for high-performance API endpoints
- LangChain & LangGraph for multi-agent orchestration
- NVIDIA Nemotron-3.5-Lightning-30B-A3B (`nvidia/nemotron-3.5-lightning-30b-a3b`) via NVIDIA NIM
- YFinance for live market and fundamental data retrieval
- Langfuse for observability and tracing

**Frontend:**
- Modern React SPA with responsive design
- Real-time Server-Sent Events (SSE) token streaming
- Interactive financial charts and analysis views

**Deployment:**
- Serverless container architecture on **AWS Lambda** (Container Image)
- **AWS Lambda Web Adapter** for native HTTP and unbuffered response streaming
- Direct **AWS Lambda Function URL** (Zero proxy markup, true $0.00 idle cost)

---

## Live Demo & Architecture

The application is deployed live on AWS in `ap-south-1` using an ultra cost-effective serverless architecture:

- **Live URL:** [https://m2gb43bpkfy53jo6b3zp5wkcxy0sjuuz.lambda-url.ap-south-1.on.aws/](https://m2gb43bpkfy53jo6b3zp5wkcxy0sjuuz.lambda-url.ap-south-1.on.aws/)
- **Idle Running Cost:** **$0.00 / month** (Scales to zero when not receiving requests)
- **Streaming Support:** True real-time unbuffered token streaming via Lambda Function URL `InvokeMode: RESPONSE_STREAM`.

For detailed architecture details, refer to the [Cost-Effective AWS Deployment Guide](docs/cost-effective-aws-deployment.md).

---

## Getting Started Locally

### Prerequisites
- Python 3.11+
- Node.js 18+ (for frontend development)
- NVIDIA API key (from [build.nvidia.com](https://build.nvidia.com))

### Local Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/varshith0810/MarketPrism.git
   cd MarketPrism
   ```

2. **Set up Python backend:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: .\venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```
   Add your `NVIDIA_API_KEY` to `.env`.

4. **Install and run frontend:**
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

5. **Start backend server:**
   ```bash
   python main.py
   ```

6. Access the API at `http://localhost:8000` and frontend at `http://localhost:3000`.

---

## AWS Deployment

Deploy the entire stack (FastAPI backend + compiled React SPA) into a single serverless container on AWS:

### 1-Click Deployment
- **Windows (PowerShell):**
  ```powershell
  .\scripts\deploy-cost-effective.ps1
  ```
- **Linux / macOS (Bash):**
  ```bash
  chmod +x ./scripts/deploy-cost-effective.sh
  ./scripts/deploy-cost-effective.sh
  ```

### Automated CI/CD (GitHub Actions)
Every push to `main` automatically builds, tests, and deploys the latest container to Amazon ECR and AWS Lambda via [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml).

---

## API Capabilities

The platform provides specialized financial analysis tools:
- Real-time stock quotes and ticker lookup
- Historical price movements and trend analysis
- Fundamental financial statements (Balance Sheet, Income Statement, Cash Flow)
- Valuation ratios and company profiles
- Dividend history and stock splits
- Institutional holders and insider transactions
- Wall Street analyst ratings and consensus summaries
