import os
import uvicorn
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from langfuse import Langfuse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, FileResponse
from langchain_core.messages import SystemMessage, HumanMessage
from config.config import RequestObject
from MarketInsight.components.agent import agent, model_name
from MarketInsight.utils.logger import get_logger

logger = get_logger(__name__)
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update with your Vercel URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

langfuse = Langfuse(
    public_key=os.getenv("LANGFUSE_PUBLIC_KEY"),
    secret_key=os.getenv("LANGFUSE_SECRET_KEY"),
    host=os.getenv("LANGFUSE_HOST")
)


@app.get("/health")
async def health_check():
    """Health check endpoint for service monitoring and keep-alive pings"""
    return {"status": "ok", "message": "Service is running"}


@app.post("/api/chat")
async def chat(request: RequestObject):
    config = {'configurable': {'thread_id': request.threadId}}
    async def generate():
        try:
            # Create a span for the entire request
            with langfuse.start_as_current_observation(
                as_type="span", 
                name="chat-request",
                input=request.prompt.content
            ) as span:
                # Set user_id as metadata
                span.update(metadata={"user_id": request.threadId})
                
                # Create a nested generation for the LLM/agent call
                with langfuse.start_as_current_observation(
                    as_type="generation",
                    name="agent-stream",
                    model=model_name,
                    input=request.prompt.content
                ) as generation:
                    
                    full_response = ""
                    for token, _ in agent.stream(
                        {
                            'messages': [
                                SystemMessage(content="You are a professional stock market analyst. For every user query, first determine whether a relevant tool can provide accurate or real-time data. If an appropriate tool exists, you must use it before answering. If the user does not provide an exact stock ticker, use the available tool to identify or resolve the correct ticker when required. Only when no suitable tool applies should you respond using your own reasoning and general market knowledge. Never guess, assume, or fabricate any financial data."),
                                HumanMessage(content=request.prompt.content)
                            ]
                        },
                        stream_mode='messages',
                        config=config
                    ):
                        chunk_content = token.content if hasattr(token, "content") else str(token)
                        if isinstance(chunk_content, str) and chunk_content:
                            full_response += chunk_content
                            yield chunk_content
                    
                    # Update generation with the complete output
                    generation.update(output=full_response)
                
                # Update span with completion status
                span.update(output="Request completed successfully")
                
        except Exception as e:
            error_msg = f"\n\nError: {str(e)}"
            if "Authorization failed" in str(e) or "401" in str(e) or "403" in str(e):
                error_msg += "\n\nPlease check that a valid NVIDIA_API_KEY is configured in your .env file."
            logger.error(f"Error in chat: {error_msg}")
            yield error_msg
    
    return StreamingResponse(generate(), media_type='text/event-stream',
        headers={
            'cache-control': 'no-cache, no-transform', 
            'connection': 'keep-alive'
        })

# --------------------------------------------------------------------------------
# Static Files & SPA Routing (Production / Container Deployment)
# --------------------------------------------------------------------------------
frontend_dist = os.path.join(os.path.dirname(__file__), "frontend", "dist")
if os.path.exists(frontend_dist):
    assets_dir = os.path.join(frontend_dist, "assets")
    if os.path.exists(assets_dir):
        app.mount("/assets", StaticFiles(directory=assets_dir), name="assets")

    @app.get("/{full_path:path}")
    async def serve_spa(full_path: str):
        file_path = os.path.join(frontend_dist, full_path)
        if full_path and os.path.exists(file_path) and os.path.isfile(file_path):
            return FileResponse(file_path)
        return FileResponse(os.path.join(frontend_dist, "index.html"))

if __name__ == '__main__':
    logger.info("App Initiated Successfully")
    uvicorn.run(app, host='0.0.0.0', port=8000)