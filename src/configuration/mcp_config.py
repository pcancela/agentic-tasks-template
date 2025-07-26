import os
import json

from mcp import StdioServerParameters

class MCPConfig:
    def __init__(self, config_file: str):
        self.config_file = config_file
        self.mcp_servers = self._load_mcp_servers()

    def _load_mcp_servers(self):
        try:
            with open(self.config_file, 'r') as f:
                config = json.load(f)
            return config.get("mcpServers", {})
        except FileNotFoundError:
            print(f"ERROR: MCP config file not found: {self.config_file}")
            print(f"Current working directory: {os.getcwd()}")
            raise
        except json.JSONDecodeError:
            print(f"ERROR: Invalid JSON in MCP config file: {self.config_file}")
            raise
    
    def get_server_params(self, server_id: str):
        server_config = self.mcp_servers.get(server_id)
        if not server_config:
            raise ValueError(f"Server ID '{server_id}' not found in MCP configuration.")
        
        if server_config.get("type") == "StdIO":
            return StdioServerParameters(
                command=server_config.get("command"),
                args=server_config.get("args", []),
                env=os.environ
            )
        elif server_config.get("type") == "streamable-http" or server_config.get("type") == "sse":
            return {
                "url": server_config.get("url"),
                "headers": server_config.get("headers", {})
            }
        else:
            raise ValueError(f"Unsupported MCP server type: {server_config.get('type')}")

    def get_all_server_params(self):
        """Return a list of all server parameters from the configuration file.
        Only returns server parameters that are successfully created (ignores errors).
        """
        server_params = []
        for server_id in self.mcp_servers.keys():
            try:
                param = self.get_server_params(server_id)
                server_params.append(param)
            except ValueError as e:
                # Skip problematic server configurations
                print(f"Warning: Skipping server '{server_id}': {str(e)}")
        return server_params
    
# For running as a script
# ie poetry run python mcp_config.py
if __name__ == "__main__":
    config = MCPConfig("..\\mcp-config.json")
    all_server_params = config.get_all_server_params()
    print(all_server_params)