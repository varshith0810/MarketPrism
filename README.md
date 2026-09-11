# MarketPrism

[![Live Demo](https://img.shields.io/badge/Live%20Demo-marketprism--ai-orange?style=for-the-badge&logo=google-chrome)](https://tinyurl.com/marketprism-ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11](https://img.shields.io/badge/python-3.11-blue.svg)](https://www.python.org/downloads/release/python-3110/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688.svg?logo=fastapi)](https://fastapi.tiangolo.com/)
[![LangChain](https://img.shields.io/badge/LangChain-LangGraph-1C3C3C.svg)](https://www.langchain.com/)
[![React](https://img.shields.io/badge/React-19-61dafb.svg?logo=react)](https://reactjs.org/)
[![Vite](https://img.shields.io/badge/Vite-7-646CFF.svg?logo=vite)](https://vitejs.dev/)

An intelligent, AI-powered stock market research platform that delivers real-time financial intelligence, deep fundamental analysis, and institutional data through an interactive, streaming conversational assistant.

🔗 **Live Website:** [https://tinyurl.com/marketprism-ai](https://tinyurl.com/marketprism-ai)

---

## Overview

MarketPrism combines autonomous AI agent orchestration (**LangGraph**) with high-performance language modeling (**NVIDIA Nemotron-3.5-Lightning-30B-A3B**) and real-time market data providers (**Yahoo Finance**) to give investors, analysts, and traders immediate access to institutional-grade stock intelligence.

Instead of navigating complex financial terminals and disjointed dashboards, users can query MarketPrism in natural language. The underlying agent autonomously decides which financial tools to invoke, fetches and cross-references live data, and streams reasoned analytical insights token-by-token.

---

## Key Features

### 1. Autonomous Multi-Tool AI Agent
- **LangGraph Orchestration**: Powered by a robust state graph and `MemorySaver` checkpointer for persistent, multi-turn conversation memory.
- **NVIDIA Nemotron-3.5-Lightning-30B-A3B**: High-throughput, reasoning-dense model accessed through NVIDIA NIM API for rapid analysis and structured tool calling.
- **Autonomous Tool Dispatching**: Evaluates user prompts and decides when to search for tickers, pull live prices, or fetch balance sheets before responding. Never fabricates financial figures.

### 2. Comprehensive 16-Tool Financial Analysis Suite
MarketPrism integrates 16 specialized analytical tools categorized into five pillars:

| Category | Tools | Description |
| :--- | :--- | :--- |
| **Quotes & Pricing** | `get_stock_price`<br>`get_historical_data`<br>`get_ticker` | Real-time equity prices, historical OHLCV data across custom timeframes, and smart company-to-ticker symbol resolution. |
| **Fundamentals** | `get_balance_sheet`<br>`get_income_statement`<br>`get_cash_flow`<br>`get_company_info` | Annual and quarterly financial statements, cash flow dynamics, business models, sector/industry classification, and valuation multiples. |
| **Corporate Actions** | `get_dividends`<br>`get_splits` | Historical dividend payout yields, ex-dividend dates, distribution records, and forward/reverse stock split ratios. |
| **Ownership & Institutions** | `get_major_shareholders`<br>`get_institutional_holders`<br>`get_mutual_fund_holders`<br>`get_insider_transactions` | Equity ownership distribution, top institutional asset managers, mutual fund positions, and recent insider buying/selling filings. |
| **Sentiment & Consensus** | `get_analyst_recommendations`<br>`get_analyst_recommendations_summary`<br>`get_stock_news` | Wall Street consensus ratings (Buy/Hold/Sell), price targets, recent analyst upgrades/downgrades, and market headlines. |

### 3. Real-Time Streaming Architecture
- **Server-Sent Events (SSE)**: Chat completions are streamed in real time over HTTP via FastAPI's `StreamingResponse`, eliminating long response waits and providing immediate visual feedback.

### 4. Enterprise Observability & Tracing
- **Langfuse Integration**: Built-in distributed tracing and telemetry. Logs user sessions, latency, token consumption, and nested LLM generation calls for transparency and prompt optimization.

### 5. Modern Interactive Frontend
- **React 19 & Vite 7**: Fast, modern single-page application with dark-mode aesthetic.
- **Dynamic Markdown & Financial Cards**: Renders tables, structured reports, bullet points, and code blocks seamlessly as responses stream in.

---

## Project Structure

```
MarketPrism/
├── MarketInsight/
│   ├── components/
│   │   └── agent.py          # LangGraph agent definition, tools binding & model setup
│   └── utils/
│       ├── logger.py         # Resilient application logger with /tmp fallback
│       └── tools.py          # 16 financial tools interfacing with yfinance & APIs
├── config/
│   └── config.py             # Pydantic request & session schema models
├── frontend/                 # Modern React 19 + TypeScript + Vite SPA
│   ├── src/                  # React components, chat interface & styles
│   ├── package.json          # Frontend dependencies & scripts
│   └── vite.config.ts        # Vite build configuration
├── main.py                   # FastAPI backend server with SSE streaming & SPA static mounts
├── requirements.txt          # Python backend dependencies
├── Dockerfile                # Multi-stage container build (Node.js build -> Python runtime)
└── .env.example              # Template for environment variables
```

---

## Local Deployment & Setup

You can run MarketPrism locally in either **Development Mode** (with hot-reloading for both backend and frontend) or **Single-Port Production Mode**.

### Prerequisites

- **Python**: Version 3.11 or higher
- **Node.js**: Version 18 or higher (with `npm`)
- **Git**
- **NVIDIA API Key**: Free API key from [build.nvidia.com](https://build.nvidia.com)

---

### Step 1: Clone the Repository

```bash
git clone https://github.com/varshith0810/MarketPrism.git
cd MarketPrism
```

---

### Step 2: Configure Environment Variables

Create a `.env` file in the root directory:

```bash
cp .env.example .env
```

Open `.env` and add your credentials:

```ini
# Required: NVIDIA NIM API Key (from https://build.nvidia.com)
NVIDIA_API_KEY=nvapi-your-key-here

# Optional Model Settings (Defaults to Nemotron 3.5 Lightning)
MODEL_NAME=nvidia/nemotron-3.5-lightning-30b-a3b
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
MODEL_TEMPERATURE=0.2

# Optional Observability (Langfuse)
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
LANGFUSE_HOST=https://cloud.langfuse.com
```

---

### Step 3: Set Up Python Backend

1. Create and activate a Python virtual environment:

   **On macOS / Linux:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

   **On Windows (PowerShell):**
   ```powershell
   python -m venv venv
   .\venv\Scripts\Activate.ps1
   ```

2. Install backend dependencies:
   ```bash
   pip install -r requirements.txt
   ```

---

### Step 4: Run Locally

You have two options for running the app locally:

#### Option A: Full Development Mode (Hot Reloading)

Ideal when developing or modifying features.

1. **Start the FastAPI backend** (in your activated virtual environment):
   ```bash
   python main.py
   ```
   *The backend will start at `http://localhost:8000`.*

2. **Start the React frontend** (in a separate terminal window):
   ```bash
   cd frontend
   npm install
   npm run dev
   ```
   *The frontend development server will launch at `http://localhost:5173` (or `http://localhost:3000`).*

Open your browser and navigate to the frontend URL to start querying the agent!

---

#### Option B: Unified Production Build (Single Port)

Build the frontend static assets and let FastAPI serve both the REST API and the frontend on port `8000`:

1. **Build the frontend bundle:**
   ```bash
   cd frontend
   npm install
   npm run build
   cd ..
   ```

2. **Launch the server:**
   ```bash
   python main.py
   ```

3. **Access the application:**
   Open your browser at **`http://localhost:8000`**.

---

### Step 5: Run with Docker Locally (Alternative)

You can also package and run the entire application using Docker:

1. **Build the Docker container:**
   ```bash
   docker build -t marketprism:local .
   ```

2. **Run the container:**
   ```bash
   docker run -p 8000:8000 --env-file .env marketprism:local
   ```

3. **Open:** Navigate to `http://localhost:8000`.

---

## API Reference

### 1. Health Check
```http
GET /health
```
**Response (200 OK):**
```json
{
  "status": "ok",
  "message": "Service is running"
}
```

### 2. Conversational Agent Streaming
```http
POST /api/chat
Content-Type: application/json

{
  "threadId": "user-session-123",
  "prompt": {
    "content": "What is Apple's current stock price and key financial ratios?"
  }
}
```
**Response:** `Transfer-Encoding: chunked` stream (`text/event-stream`) returning real-time response chunks.

---

## Sample Queries to Try

Once running locally, try asking MarketPrism queries such as:

- *"What is Microsoft's current stock price and PE ratio?"*
- *"Compare the revenue and operating cash flow of Tesla and Ford over the last four quarters."*
- *"Who are the top institutional holders of NVIDIA and have there been any recent insider sales?"*
- *"Summarize recent analyst price targets and recommendations for Alphabet."*
- *"Did Apple announce any dividends or stock splits recently?"*

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
