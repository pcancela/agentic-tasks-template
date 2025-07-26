# Ollama Docker Compose Configuration Guide

This project provides multiple Docker Compose configurations for different GPU scenarios:

## Configuration Files

### 1. `docker-compose.yml` (Default - CPU with optional GPU)
- **Use case**: Universal configuration that works on any system
- **GPU support**: Will use GPU if available, falls back to CPU
- **Command**: `docker-compose up`

### 2. `docker-compose.cpu.yml` (CPU Only)
- **Use case**: Systems without GPU or when you want to force CPU usage
- **GPU support**: None - pure CPU inference
- **Command**: `docker-compose -f docker-compose.cpu.yml up`

### 3. `docker-compose.amd.yml` (AMD GPU via ROCm)
- **Use case**: Systems with AMD GPUs
- **GPU support**: AMD GPUs via ROCm
- **Command**: `docker-compose -f docker-compose.amd.yml up`

## Quick Start Commands

### For systems with NVIDIA GPU:
```bash
# First enable GPU support in Docker
docker-compose down
docker-compose up --build
```

### For systems with AMD GPU:
```bash
docker-compose -f docker-compose.amd.yml up --build
```

### For CPU-only systems or troubleshooting:
```bash
docker-compose -f docker-compose.cpu.yml up --build
```

## GPU Detection and Fallback

### What happens without GPU support:

1. **No NVIDIA GPU**: Default config will run in CPU mode
2. **AMD GPU**: Use the AMD-specific config file
3. **Intel/Other GPUs**: Use CPU-only config

### Environment Variables for Performance Tuning:

- `OLLAMA_NUM_PARALLEL=1`: Number of parallel requests
- `OLLAMA_MAX_LOADED_MODELS=1`: Maximum models in memory
- `NVIDIA_VISIBLE_DEVICES=all`: Which GPUs to use (NVIDIA only)

## Verification Commands

### Check if GPU is being used:
```bash
# For NVIDIA GPUs
nvidia-smi

# For AMD GPUs  
rocm-smi

# Inside container
docker-compose exec ollama nvidia-smi  # NVIDIA
docker-compose exec ollama rocm-smi    # AMD
```

### Check Ollama status:
```bash
docker-compose exec ollama ollama list
curl http://localhost:11434/api/tags
```

## Performance Notes

- **CPU-only**: Slower inference, but works everywhere
- **NVIDIA GPU**: Best performance with CUDA support
- **AMD GPU**: Good performance with ROCm (Linux only)
- **Memory**: Adjust container memory limits based on model size

## Troubleshooting

If containers fail to start:
1. Try CPU-only configuration first
2. Check GPU drivers are installed
3. Verify Docker GPU support: `docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi`
4. Check logs: `docker-compose logs ollama`
