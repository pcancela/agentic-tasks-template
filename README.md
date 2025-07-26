# Agentic Tasks Template

## FastAPI server using CrewAI and MCP servers and tools

This is a simple FastAPI server that uses CrewAI to execute tasks with the help of MCP tools.

## Requirements
- [Python](https://www.python.org/downloads/release/python-31210/) as the programming language
- [Poetry](https://python-poetry.org) for virtual env and dependency management
- [Ollama](https://ollama.com/) for LLM inference
- [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/) (optional, for containerized deployment)

## Setup
1. Clone this repository
2. Run `pip install poetry` to install poetry
3. Run `poetry lock` to sync toml and lock files
3. Run `poetry install` to install project dependencies
4. Make sure Ollama is installed and running locally (if running in local mode)
5. Configure your MCP servers in either:
   - `mcp-config.json` (for Docker environment)
   - `mcp-config.local.json` (for local Windows environment)

## Running the Application

### Using the Helper Script (Recommended)
Use the PowerShell script to easily run the application in different modes:

#### Local Mode (default)
```powershell
.\run.ps1
# or explicitly specify:
.\run.ps1 -mode local
```

#### Docker Mode with GPU Auto-Detection
```powershell
.\run.ps1 -mode docker
# Automatically detects and uses available GPU (NVIDIA/AMD) or falls back to CPU
```

#### Docker Mode with Specific GPU Configuration
```powershell
# Force NVIDIA GPU mode
.\run.ps1 -mode docker -gpu nvidia

# Force AMD GPU mode  
.\run.ps1 -mode docker -gpu amd

# Force CPU-only mode
.\run.ps1 -mode docker -gpu cpu
```

#### Docker Rebuild (clean build)
```powershell
.\run.ps1 -mode docker-rebuild -gpu auto
```

### LLM Model Configuration

The application supports configurable LLM models through Ollama:

#### Using Command Line Parameters
```powershell
# Use default mistral model
.\run.ps1

# Use llama3 model
.\run.ps1 -model llama3

# Use codellama model
.\run.ps1 -model codellama

# Use any other Ollama model
.\run.ps1 -model phi3
```

#### Using Environment Variables
You can also set the model using the `OLLAMA_MODEL` environment variable:

```powershell
# Windows PowerShell
$env:OLLAMA_MODEL = "llama3"
.\run.ps1

# Windows Command Prompt
set OLLAMA_MODEL=llama3
.\run.ps1
```

**Note**: When running locally, if no `OLLAMA_MODEL` environment variable is defined, the application will default to using the **mistral** model. The `run.ps1` script will automatically download the specified model if it's not already available in your local Ollama installation.

#### Supported Models
The application works with any model available in Ollama, including:
- `mistral` (default)
- `llama3`
- `codellama`
- `gemma`
- `phi3`
- `qwen`
- Custom models with specific tags (e.g., `llama3:70b`)

### GPU Support in Docker

The application supports multiple GPU configurations:

- **NVIDIA GPUs**: Uses CUDA acceleration (requires NVIDIA Container Toolkit)
- **AMD GPUs**: Uses ROCm acceleration (Linux only, experimental on Windows)
- **CPU-only**: Universal fallback that works on any system

The helper scripts automatically detect your GPU and select the appropriate Docker Compose configuration:
- `docker-compose.yml` - Default with optional NVIDIA GPU support
- `docker-compose.amd.yml` - AMD GPU with ROCm support  
- `docker-compose.cpu.yml` - CPU-only mode

See `docker-gpu-guide.md` for detailed GPU setup instructions.

### Manual Startup

#### Local Startup
```powershell
poetry run uvicorn src.main:app --reload --host 0.0.0.0 --port 4000
```

#### Docker Startup
```powershell
docker-compose up --build
```

## Configuration

The application supports different configurations for local development and Docker environments:

- `mcp-config.local.json`: Used when running locally, containing Windows-style paths
- `mcp-config.json`: Used when running in Docker, containing Unix-style paths

The correct configuration file is automatically selected based on the `DOCKER_ENV` environment variable.

## API Documentation

Interactive API docs will be accessible at:
http://localhost:4000/docs
