param (
    [string]$mode = "local",  # Default to local mode
    [string]$gpu = "auto",    # GPU mode: auto, nvidia, amd, cpu
    [string]$model = "mistral" # LLM model: mistral, llama3, codellama, etc.
)

function PrintHeader {
    param (
        [string]$text
    )
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host " $text" -ForegroundColor Cyan
    Write-Host "============================================`n" -ForegroundColor Cyan
}

function DetectGPU {
    Write-Host "Detecting GPU configuration..." -ForegroundColor Yellow
    
    # Check for NVIDIA GPU
    $nvidiaGPU = $false
    try {
        $nvidiaOutput = nvidia-smi 2>$null
        if ($LASTEXITCODE -eq 0) {
            $nvidiaGPU = $true
            Write-Host "✓ NVIDIA GPU detected" -ForegroundColor Green
        }
    } catch {
        # nvidia-smi not found or failed
    }
    
    # Check for AMD GPU (basic detection on Windows)
    $amdGPU = $false
    try {
        $gpuInfo = Get-WmiObject -Class Win32_VideoController | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" }
        if ($gpuInfo) {
            $amdGPU = $true
            Write-Host "✓ AMD GPU detected" -ForegroundColor Green
        }
    } catch {
        # WMI query failed
    }
    
    # Check Docker GPU support
    $dockerGPU = $false
    try {
        $dockerTest = docker run --rm --gpus=all nvcr.io/nvidia/k8s/cuda-sample:nbody nbody -gpu -benchmark 2>$null
        if ($LASTEXITCODE -eq 0) {
            $dockerGPU = $true
            Write-Host "✓ Docker GPU support available" -ForegroundColor Green
        }
    } catch {
        Write-Host "! Docker GPU support not available" -ForegroundColor Yellow
    }
    
    # Return detection results
    return @{
        NVIDIA = $nvidiaGPU -and $dockerGPU
        AMD = $amdGPU
        CPU = $true
    }
}

function UpdateMCPConfigPaths {
    Write-Host "Updating MCP configuration with current directory paths..." -ForegroundColor Yellow
    
    $configFile = "mcp-config.local.json"
    if (Test-Path $configFile) {
        try {
            # Read the current config
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            
            # Get current working directory
            $currentDir = (Get-Location).Path
            
            # Update paths for all MCP servers
            $updated = $false
            foreach ($serverName in $config.mcpServers.PSObject.Properties.Name) {
                $server = $config.mcpServers.$serverName
                if ($server.args -and $server.args.Count -gt 0) {
                    for ($i = 0; $i -lt $server.args.Count; $i++) {
                        $arg = $server.args[$i]
                        # Check if the argument looks like a file path (contains .js, .py, etc.)
                        if ($arg -match '\.(js|py|ts|mjs)$' -and -not [System.IO.Path]::IsPathRooted($arg)) {
                            # Convert relative path to absolute path
                            $absolutePath = Join-Path $currentDir $arg
                            $server.args[$i] = $absolutePath
                            $updated = $true
                            Write-Host "  Updated path for $serverName`: $absolutePath" -ForegroundColor Gray
                        }
                    }
                }
            }
            
            if ($updated) {
                # Write back the updated config
                $config | ConvertTo-Json -Depth 10 | Set-Content $configFile
                Write-Host "✓ MCP configuration updated with current directory paths" -ForegroundColor Green
            } else {
                Write-Host "No relative paths found to update in MCP configuration" -ForegroundColor Gray
            }
        } catch {
            Write-Host "✗ Error updating MCP configuration: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "MCP configuration file not found: $configFile" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function InstallMCPDependencies {
    Write-Host "Installing MCP-StdIO Node.js dependencies..." -ForegroundColor Yellow
    
    # Find all package.json files in MCP-StdIO folder, excluding node_modules
    $mcpStdIOPath = "MCP-StdIO"
    if (Test-Path $mcpStdIOPath) {
        $packageJsonFiles = Get-ChildItem -Path $mcpStdIOPath -Name "package.json" -Recurse | Where-Object { 
            $_ -notmatch "node_modules" 
        }
        
        if ($packageJsonFiles.Count -eq 0) {
            Write-Host "No package.json files found in MCP-StdIO folder" -ForegroundColor Gray
            return
        }
        
        foreach ($packageFile in $packageJsonFiles) {
            $packageDir = Split-Path (Join-Path $mcpStdIOPath $packageFile) -Parent
            Write-Host "Installing dependencies in: $packageDir" -ForegroundColor Cyan
            
            Push-Location $packageDir
            try {
                # Check if npm is available
                $npmVersion = npm --version 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "✗ npm not found. Please install Node.js and npm." -ForegroundColor Red
                    Pop-Location
                    continue
                }
                
                Write-Host "  Using npm version: $npmVersion" -ForegroundColor Gray
                
                # Run npm install
                npm install
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ Dependencies installed successfully" -ForegroundColor Green
                } else {
                    Write-Host "  ✗ Failed to install dependencies" -ForegroundColor Red
                }
            } catch {
                Write-Host "  ✗ Error during npm install: $($_.Exception.Message)" -ForegroundColor Red
            } finally {
                Pop-Location
            }
        }
    } else {
        Write-Host "MCP-StdIO folder not found" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function SelectDockerCompose {
    param (
        [string]$gpuMode,
        [hashtable]$gpuDetection
    )
    
    $composeFile = "docker-compose.yml"
    $description = "CPU mode"
    
    if ($gpuMode -eq "auto") {
        if ($gpuDetection.NVIDIA) {
            $composeFile = "docker-compose.yml"
            $description = "Auto-detected NVIDIA GPU mode"
        } elseif ($gpuDetection.AMD) {
            $composeFile = "docker-compose.amd.yml"
            $description = "Auto-detected AMD GPU mode"
        } else {
            $composeFile = "docker-compose.cpu.yml"
            $description = "Auto-detected CPU-only mode"
        }
    } elseif ($gpuMode -eq "nvidia") {
        if ($gpuDetection.NVIDIA) {
            $composeFile = "docker-compose.yml"
            $description = "Forced NVIDIA GPU mode"
        } else {
            Write-Host "Warning: NVIDIA GPU requested but not detected. Falling back to CPU mode." -ForegroundColor Yellow
            $composeFile = "docker-compose.cpu.yml"
            $description = "Fallback CPU mode"
        }
    } elseif ($gpuMode -eq "amd") {
        if ($gpuDetection.AMD) {
            $composeFile = "docker-compose.amd.yml"
            $description = "Forced AMD GPU mode"
        } else {
            Write-Host "Warning: AMD GPU requested but not detected. Falling back to CPU mode." -ForegroundColor Yellow
            $composeFile = "docker-compose.cpu.yml"
            $description = "Fallback CPU mode"
        }
    } elseif ($gpuMode -eq "cpu") {
        $composeFile = "docker-compose.cpu.yml"
        $description = "Forced CPU-only mode"
    } else {
        Write-Host "Invalid GPU mode: $gpuMode. Using CPU mode." -ForegroundColor Red
        $composeFile = "docker-compose.cpu.yml"
        $description = "Default CPU mode"
    }
    
    Write-Host "Selected configuration: $description" -ForegroundColor Cyan
    Write-Host "Using: $composeFile" -ForegroundColor Gray
    
    return $composeFile
}

if ($mode -eq "docker") {
    PrintHeader "Running in Docker mode"
    
    # Set environment variable for the model
    $env:OLLAMA_MODEL = $model
    Write-Host "Using model: $model" -ForegroundColor Cyan
    
    # Detect GPU and select appropriate docker-compose file
    $gpuDetection = DetectGPU
    $composeFile = SelectDockerCompose -gpuMode $gpu -gpuDetection $gpuDetection
    
    Write-Host "Building and starting Docker containers..." -ForegroundColor Yellow
    docker-compose -f $composeFile up --build
}
elseif ($mode -eq "docker-rebuild") {
    PrintHeader "Rebuilding and running Docker containers"
    
    # Set environment variable for the model
    $env:OLLAMA_MODEL = $model
    Write-Host "Using model: $model" -ForegroundColor Cyan
    
    # Detect GPU and select appropriate docker-compose file
    $gpuDetection = DetectGPU
    $composeFile = SelectDockerCompose -gpuMode $gpu -gpuDetection $gpuDetection
    
    Write-Host "Rebuilding Docker containers from scratch..." -ForegroundColor Yellow
    docker-compose -f $composeFile down
    docker-compose -f $composeFile build --no-cache
    docker-compose -f $composeFile up
}
elseif ($mode -eq "local") {
    PrintHeader "Running in local mode"
    
    # Update MCP configuration with current directory paths
    UpdateMCPConfigPaths
    
    # Install MCP-StdIO dependencies
    InstallMCPDependencies
    
    # Detect GPU for local Ollama recommendations
    Write-Host "Checking system configuration..." -ForegroundColor Yellow
    $gpuDetection = DetectGPU
    
    if ($gpuDetection.NVIDIA) {
        Write-Host "✓ NVIDIA GPU detected - Ollama should automatically use GPU acceleration" -ForegroundColor Green
    } elseif ($gpuDetection.AMD) {
        Write-Host "✓ AMD GPU detected - Ollama may use GPU acceleration (check Ollama documentation)" -ForegroundColor Yellow
        Write-Host "  Note: AMD GPU support in Ollama varies by platform" -ForegroundColor Gray
    } else {
        Write-Host "! No dedicated GPU detected - Ollama will use CPU" -ForegroundColor Yellow
        Write-Host "  This may result in slower inference times" -ForegroundColor Gray
    }
    
    # Check if Ollama is running locally
    $ollamaRunning = $false
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -ErrorAction SilentlyContinue
        $ollamaRunning = $true
        Write-Host "✓ Ollama is running" -ForegroundColor Green
    } catch {
        $ollamaRunning = $false
    }
    
    if (-not $ollamaRunning) {
        Write-Host "✗ Ollama is not running. Please start Ollama before continuing." -ForegroundColor Red
        Write-Host "You can download Ollama from: https://ollama.com/download" -ForegroundColor Yellow
        if ($gpuDetection.NVIDIA) {
            Write-Host ""
            Write-Host "GPU Tips for Ollama:" -ForegroundColor Cyan
            Write-Host "- Ollama should automatically detect and use your NVIDIA GPU" -ForegroundColor Gray
            Write-Host "- You can verify GPU usage with: nvidia-smi (while running models)" -ForegroundColor Gray
        }
        exit 1
    }
    
    # Check if specified model is available in Ollama
    $modelAvailable = $false
    if ($ollamaRunning) {
        try {
            $models = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -ErrorAction SilentlyContinue
            $modelAvailable = $models.models | Where-Object { $_.name -eq $model -or $_.name -eq "$model`:latest" } | Select-Object -First 1
            if ($modelAvailable) {
                Write-Host "✓ $model model is available" -ForegroundColor Green
            }
        } catch {
            $modelAvailable = $false
        }
    }
    
    if (-not $modelAvailable) {
        Write-Host "Downloading $model model..." -ForegroundColor Yellow
        if ($gpuDetection.NVIDIA) {
            Write-Host "This may take a while, but GPU acceleration will make inference much faster!" -ForegroundColor Cyan
        }
        ollama pull $model
        Write-Host "✓ $model model downloaded successfully" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Starting FastAPI application in local mode..." -ForegroundColor Green
    if ($gpuDetection.NVIDIA) {
        Write-Host "GPU acceleration should be active for better performance" -ForegroundColor Cyan
    }
    
    # Set environment variables for local mode
    $env:DOCKER_ENV = "false"
    $env:OLLAMA_MODEL = $model
    
    Write-Host "Using model: $model" -ForegroundColor Cyan
    
    # Run the application
    poetry run uvicorn src.main:app --reload --host 0.0.0.0 --port 4000
}
else {
    Write-Host "Invalid mode specified." -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\run.ps1 [-mode <mode>] [-gpu <gpu>] [-model <model>]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Modes:" -ForegroundColor Cyan
    Write-Host "  local           - Run locally with Poetry (default)" -ForegroundColor Gray
    Write-Host "  docker          - Run in Docker containers" -ForegroundColor Gray
    Write-Host "  docker-rebuild  - Rebuild and run Docker containers" -ForegroundColor Gray
    Write-Host ""
    Write-Host "GPU Options (for Docker modes):" -ForegroundColor Cyan
    Write-Host "  auto            - Auto-detect GPU (default)" -ForegroundColor Gray
    Write-Host "  nvidia          - Force NVIDIA GPU mode" -ForegroundColor Gray
    Write-Host "  amd             - Force AMD GPU mode" -ForegroundColor Gray
    Write-Host "  cpu             - Force CPU-only mode" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Model Options (for local mode):" -ForegroundColor Cyan
    Write-Host "  mistral         - Mistral 7B model (default)" -ForegroundColor Gray
    Write-Host "  llama3          - Llama 3 model" -ForegroundColor Gray
    Write-Host "  codellama       - Code Llama model" -ForegroundColor Gray
    Write-Host "  gemma           - Google Gemma model" -ForegroundColor Gray
    Write-Host "  phi3            - Microsoft Phi-3 model" -ForegroundColor Gray
    Write-Host "  qwen            - Qwen model" -ForegroundColor Gray
    Write-Host "  <custom>        - Any other Ollama model name" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\run.ps1                                    # Local mode with mistral" -ForegroundColor Gray
    Write-Host "  .\run.ps1 -model llama3                     # Local mode with llama3" -ForegroundColor Gray
    Write-Host "  .\run.ps1 -mode docker                      # Docker with auto GPU detection" -ForegroundColor Gray
    Write-Host "  .\run.ps1 -mode docker -gpu nvidia          # Docker with NVIDIA GPU" -ForegroundColor Gray
    Write-Host "  .\run.ps1 -model codellama                  # Local mode with codellama" -ForegroundColor Gray
    exit 1
}
