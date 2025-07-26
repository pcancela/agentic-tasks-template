import uvicorn
import os
import signal
import sys

# Add the current directory to Python path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi import FastAPI
from contextlib import asynccontextmanager
from pydantic import BaseModel
from assistant_orchestrator import run_query

class QueryRequest(BaseModel):
    query: str

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Register SIGTERM handler
    signal.signal(signal.SIGTERM, sigterm_handler)
    yield
    # Shutdown: Add cleanup code here if needed
    print("Shutting down application...")

def sigterm_handler(signum, frame):
    print(f"Received SIGTERM - {signum}. Performing cleanup...")
    # Add any cleanup tasks here
    sys.exit(0)

app = FastAPI(
    title="Template For Agentic Tasks",
    description="API that exposes an endpoint to query an agentic assistant that leverages MCP servers and tools to execute tasks.",
    version="1.0.0",
    lifespan=lifespan
)

@app.post("/assistant")
async def query_endpoint(request: QueryRequest):

    print(f'Input query: {request.query}')

    return run_query(request.query)

if __name__ == "__main__":
    port = int(os.getenv("PORT", 4000))
    uvicorn.run("src.main:app", host="0.0.0.0", port=port, reload=True)