from crewai.tasks.task_output import TaskOutput

class TaskValidator:
    """
    A comprehensive utility class for validating task outputs and conditions.
    This class provides various methods to check if tasks have meaningful results.
    """

    @staticmethod
    def is_data_not_missing(output: TaskOutput) -> bool:
        """
        Check if the previous task has meaningful observations/results
        
        Args:
            output (TaskOutput): The output from a previous task
            
        Returns:
            bool: True if data is present and meaningful, False otherwise
        """
        # Method 1: Check if output has content and is not empty
        if not output or not output.raw:
            return False
        
        # Method 2: Check if the raw output contains meaningful content
        raw_content = str(output.raw).strip().lower()
        
        # Filter out common "no data" responses
        no_data_indicators = [
            "thought:",
            "using a different method to find"
            "i do not know",
            "i don't know", 
            "no data",
            "failed to fetch",
            "error",
            "unable to",
            "could not",
            "cannot",
            "timeout",
            "not available"
        ]
        
        # If output contains any "no data" indicators, consider it as missing data
        for indicator in no_data_indicators:
            if indicator in raw_content:
                return False
        
        # Method 3: Check minimum content length (meaningful responses are usually longer)
        if len(raw_content) < 50:  # Adjust threshold as needed
            return False
        
        # Method 4: Check if agent_execution has tool calls/observations
        if hasattr(output, 'agent_execution') and output.agent_execution:
            # Check if there were any tool executions
            if hasattr(output.agent_execution, 'tool_calls') and output.agent_execution.tool_calls:
                return len(output.agent_execution.tool_calls) > 0
        
        return True  # If we get here, assume data is present

    @staticmethod
    def has_successful_tool_calls(output: TaskOutput) -> bool:
        """
        Check if the task output contains successful tool calls
        
        Args:
            output (TaskOutput): The output from a task
            
        Returns:
            bool: True if there are successful tool calls, False otherwise
        """
        if not output or not hasattr(output, 'agent_execution') or not output.agent_execution:
            return False
            
        if hasattr(output.agent_execution, 'tool_calls') and output.agent_execution.tool_calls:
            # Check if any tool calls were successful (you can customize this logic)
            return len(output.agent_execution.tool_calls) > 0
            
        return False

    @staticmethod
    def contains_keywords(output: TaskOutput, keywords: list) -> bool:
        """
        Check if the task output contains specific keywords
        
        Args:
            output (TaskOutput): The output from a task
            keywords (list): List of keywords to search for
            
        Returns:
            bool: True if any keywords are found, False otherwise
        """
        if not output or not output.raw:
            return False
            
        content = str(output.raw).lower()
        return any(keyword.lower() in content for keyword in keywords)

    @classmethod
    def get_task_info(cls, output: TaskOutput) -> dict:
        """
        Get comprehensive information about a task output
        
        Args:
            output (TaskOutput): The output from a task
            
        Returns:
            dict: Dictionary containing various information about the task output
        """
        if not output:
            return {"error": "No output provided"}
            
        info = {
            "has_raw_output": bool(output.raw),
            "output_length": len(str(output.raw)) if output.raw else 0,
            "has_agent_execution": hasattr(output, 'agent_execution') and output.agent_execution is not None,
            "output_preview": str(output.raw)[:200] + "..." if output.raw and len(str(output.raw)) > 200 else str(output.raw),
            "has_meaningful_data": cls.is_data_not_missing(output),
            "has_tool_calls": cls.has_successful_tool_calls(output),
            "meets_min_length": cls.has_minimum_content_length(output),
            "no_errors": cls.does_not_contain_error_indicators(output)
        }
        
        # Add tool call information if available
        if hasattr(output, 'agent_execution') and output.agent_execution:
            if hasattr(output.agent_execution, 'tool_calls') and output.agent_execution.tool_calls:
                info["tool_calls_count"] = len(output.agent_execution.tool_calls)
                info["tools_used"] = [
                    getattr(call, 'tool_name', 'unknown') 
                    for call in output.agent_execution.tool_calls
                ]
            else:
                info["tool_calls_count"] = 0
                info["tools_used"] = []
        
        return info

    @classmethod
    def create_custom_validator(cls, **conditions) -> callable:
        """
        Create a custom validator function based on specified conditions
        
        Args:
            **conditions: Keyword arguments for validation conditions
                - min_length (int): Minimum content length
                - required_keywords (list): Keywords that must be present
                - forbidden_keywords (list): Keywords that must not be present
                - require_tool_calls (bool): Whether tool calls are required
                
        Returns:
            callable: A validation function that can be used with ConditionalTask
        """
        def validator(output: TaskOutput) -> bool:
            # Check minimum length if specified
            if 'min_length' in conditions:
                if not cls.has_minimum_content_length(output, conditions['min_length']):
                    return False
            
            # Check required keywords if specified
            if 'required_keywords' in conditions:
                if not cls.contains_keywords(output, conditions['required_keywords']):
                    return False
            
            # Check forbidden keywords if specified
            if 'forbidden_keywords' in conditions:
                if cls.contains_keywords(output, conditions['forbidden_keywords']):
                    return False
            
            # Check tool calls if required
            if conditions.get('require_tool_calls', False):
                if not cls.has_successful_tool_calls(output):
                    return False
            
            return True
        
        return validator
