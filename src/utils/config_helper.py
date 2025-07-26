import os
import pathlib

class ConfigHelper:
    """Utility class for configuration-related operations."""
    
    @staticmethod
    def get_config_path():
        """
        Choose config file based on environment.
        Returns the path to the appropriate configuration file.
        """
        # Check if we're running in Docker
        in_docker = os.environ.get('DOCKER_ENV', '').lower() == 'true'
        
        # Base path for the project
        base_path = pathlib.Path(__file__).parent.parent.parent
        
        # For local development use mcp-config.local.json if it exists
        if not in_docker and (base_path / "mcp-config.local.json").exists():
            config_file = "mcp-config.local.json"
            print(f"Using local configuration: {config_file}")
        else:
            config_file = "mcp-config.json"
            print(f"Using Docker configuration: {config_file}")
        
        return str(base_path / config_file)
    
    @staticmethod
    def get_ollama_base_url():
        """
        Determine the appropriate Ollama base URL based on environment.
        Returns http://ollama:11434 in Docker, http://localhost:11434 otherwise.
        """
        # Check if we're running in Docker
        if os.environ.get('DOCKER_ENV', '').lower() == 'true':
            # Use the service name as defined in docker-compose.yml
            return "http://ollama:11434"
        else:
            # Default for local development
            return "http://localhost:11434"
    
    @staticmethod
    def get_ollama_model() -> str:
        """Get the Ollama model name from environment variable or use default."""
        return os.getenv("OLLAMA_MODEL", "mistral")
