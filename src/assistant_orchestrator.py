import asyncio
import sys
import os

from crewai import LLM, Agent, Task, Crew
from crewai_tools import MCPServerAdapter
from configuration.mcp_config import MCPConfig
from utils.log_helper import LogHelper
from utils.config_helper import ConfigHelper

# Fix for Windows MCP subprocess issue
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

# Get model from environment variable or use default
model_name = os.getenv("OLLAMA_MODEL", "mistral")

llm = LLM(
    model=f"ollama/{model_name}",
    base_url=ConfigHelper.get_ollama_base_url(),
    streaming=True
)

print(f"Using LLM model: {model_name}")

# Load server parameters from the appropriate config file
server_params = MCPConfig(ConfigHelper.get_config_path()).get_all_server_params()

# Create and run Crew
def run_query(query: str):

    with MCPServerAdapter(server_params) as tools:
    
        print(f"Available tools from MCP servers: {[tool.name for tool in tools]}")

        worker_agent = Agent(
            role="Website Fetcher Agent",
            goal="Fetch data from websites or APIs.",
            backstory="A specialized AI agent that leverages available MCP tools for fetching data from any website or API.",
            tools=tools,
            reasoning=False, # Optional
            verbose=False, # Optional
            step_callback=LogHelper.log_step_callback, # Optional
            llm=llm
        )
        
        # Passing query directly into task
        processing_task = Task(
            description="""Process the following query and choose which tool should be called: {query}

            Call the most appropriate tool and provide a detailed and comprehensive answer that resulted 
            from the analysis of fetched data from a website or API. 
            If the answer is not a result from the analysis of fetched data from a website or API, return to the query caller claiming that you do not know the answer. 
            """,
            expected_output="A comprehensive answer to the query and any relevant output related with the response from the tool that was called.",
            #expected_output="Only the output from the MCP tools",
            agent=worker_agent,
            callback=LogHelper.log_task_callback, # Optional
        )
        
        data_crew = Crew(
            agents=[worker_agent],
            tasks=[processing_task],
            # memory=True,
            # embedder={
            #     "provider": "huggingface",
            #     "config": {
            #         "model": "mixedbread-ai/mxbai-embed-large-v1", # https://huggingface.co/mixedbread-ai/mxbai-embed-large-v1
            #     }
            # },
            verbose=False
        )
    
        result = data_crew.kickoff(inputs={"query": query})
        return {"result": result}

if __name__ == "__main__":
    result = run_query("Show me the list of all tools available.")
    print(f"""
        Query completed!
        result: {result}
    """)