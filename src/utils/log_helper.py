class LogHelper:

    @staticmethod
    def log_step_callback(output):
        print(f"""
            Step completed!
            details: {output.__dict__}
        """)

    @staticmethod
    def log_task_callback(output):
        print(f"""
            Task completed!
            details: {output.__dict__}
        """)