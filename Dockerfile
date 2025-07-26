FROM python:3.12-slim

WORKDIR /app

# Install Node.js 20.x for MCP servers
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy pyproject.toml and poetry.lock* first for better layer caching
COPY pyproject.toml poetry.lock* /app/

# Install Poetry
RUN pip install poetry

# Install dependencies
RUN poetry config virtualenvs.create false && \
    poetry config installer.max-workers 10 && \
    poetry lock && \
    poetry install --no-interaction --no-ansi --only=main --no-root

# Copy the rest of the application code
COPY . /app/

# Set environment variables
ENV PYTHONPATH=/app
ENV PORT=4000
ENV DOCKER_ENV=true

# Set Windows proactor event loop policy for Windows compatibility
ENV PYTHONUNBUFFERED=1

# Expose port
EXPOSE 4000

# CMD removed as it's being handled by docker-compose entrypoint
