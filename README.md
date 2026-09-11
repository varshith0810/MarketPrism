# MarketPrism

An AI-powered stock market analysis platform that provides comprehensive financial data and intelligent insights through a conversational interface.

## Overview

MarketPrism leverages advanced AI agents to deliver real-time stock market information, financial analysis, and investment insights. The platform combines the power of LangChain, LangGraph, and NVIDIA's Nemotron-3.5-Lightning-30B-A3B language model with Yahoo Finance data to create an intelligent assistant for stock market research.

## Technology Stack

**Backend:**
- FastAPI for high-performance API endpoints
- LangChain & LangGraph for AI agent orchestration
- NVIDIA Nemotron-3.5-Lightning-30B-A3B (`nvidia/nemotron-3.5-lightning-30b-a3b`) via NVIDIA NIM
- YFinance for financial data retrieval
- Langfuse for observability and tracing

**Frontend:**
- Modern React-based interface
- Real-time streaming responses
- Responsive design for all devices

## Getting Started

### Prerequisites
- Python 3.x
- Node.js (for frontend)
- NVIDIA API key (from [build.nvidia.com](https://build.nvidia.com))

### Installation

1. Clone the repository
2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Set up environment variables:
   ```bash
   cp .env.example .env
   ```
   Add your `NVIDIA_API_KEY` to the `.env` file.
4. Install frontend dependencies:
   ```bash
   cd frontend
   npm install
   ```
5. Run the backend server:
   ```bash
   python main.py
   ```
6. Run the frontend development server:
   ```bash
   cd frontend
   npm run dev
   ```
7. Access the API at `http://localhost:8000` and frontend at `http://localhost:3000`

## AWS Deployment

MarketPrism is containerized and production-ready for deployment on **AWS App Runner** (fully managed container service with automatic SSL, custom domains, and native SSE streaming).

### Quick Deploy to AWS
1. Review the detailed [AWS Deployment Guide](docs/aws-app-runner-deployment.md).
2. Run the deployment script to build and push the container to Amazon ECR:
   - **PowerShell (Windows)**:
     ```powershell
     .\scripts\deploy-aws.ps1 -Region us-east-1
     ```
   - **Bash (Linux / macOS)**:
     ```bash
     chmod +x ./scripts/deploy-aws.sh
     ./scripts/deploy-aws.sh us-east-1
     ```
3. Connect the ECR image to an **AWS App Runner** service.

## Project Structure

```
MarketInsight/
├── components/     # AI agent configuration
├── utils/          # Tools and utilities
├── config/         # Configuration files
├── frontend/       # React frontend application
└── main.py         # FastAPI server entry point
```

## API Capabilities

The platform provides 16 specialized tools for comprehensive stock analysis:
- Stock price tracking
- Historical data analysis
- Financial statements (Balance Sheet, Income Statement, Cash Flow)
- Company information and ratios
- Dividend and split history
- Ownership and holder data
- Insider transactions
- Analyst recommendations
- Company ticker lookup
