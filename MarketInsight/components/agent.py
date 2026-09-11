import os
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from MarketInsight.utils.tools import (
    get_stock_price,
    get_historical_data,
    get_stock_news,
    get_balance_sheet,
    get_income_statement,
    get_cash_flow,
    get_company_info,
    get_dividends,
    get_splits,
    get_institutional_holders,
    get_major_shareholders,
    get_mutual_fund_holders,
    get_insider_transactions,
    get_analyst_recommendations,
    get_analyst_recommendations_summary,
    get_ticker,
)
from MarketInsight.utils.logger import get_logger
from langgraph.checkpoint.memory import MemorySaver
from langchain.agents import create_agent

load_dotenv()
logger = get_logger(__name__)

model_name = os.getenv("MODEL_NAME", "nvidia/nemotron-3.5-lightning-30b-a3b")
base_url = os.getenv("NVIDIA_BASE_URL", os.getenv("OPENAI_BASE_URL", "https://integrate.api.nvidia.com/v1"))
api_key = os.getenv("NVIDIA_API_KEY") or os.getenv("OPENAI_API_KEY")

if not api_key:
    logger.warning("Neither NVIDIA_API_KEY nor OPENAI_API_KEY was found in environment. Please set NVIDIA_API_KEY in your .env file.")
    api_key = "nvapi-not-set"

model = ChatOpenAI(
    model=model_name,
    base_url=base_url,
    api_key=api_key,
    temperature=float(os.getenv("MODEL_TEMPERATURE", "0.2")),
)

tools = [
    get_stock_price,
    get_historical_data,
    get_stock_news,
    get_balance_sheet,
    get_income_statement,
    get_cash_flow,
    get_company_info,
    get_dividends,
    get_splits,
    get_institutional_holders,
    get_major_shareholders,
    get_mutual_fund_holders,
    get_insider_transactions,
    get_analyst_recommendations,
    get_analyst_recommendations_summary,
    get_ticker,
]

agent = create_agent(
    model,
    tools=tools,
    checkpointer=MemorySaver(),
)

logger.info(f"Agent initiated successfully with model: {model_name} (base_url: {base_url})")