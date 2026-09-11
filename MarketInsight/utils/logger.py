# logger.py
import logging
from datetime import datetime
from pathlib import Path

import os

# Create log file ONCE in a writable directory
_current_date = datetime.now().strftime("%Y-%m-%d")
_current_timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

_base_log_dir = Path("/tmp/logs") if (os.getenv("AWS_LAMBDA_FUNCTION_NAME") or os.getenv("LAMBDA_TASK_ROOT") or os.getenv("AWS_EXECUTION_ENV")) else Path("logs")
try:
    LOG_DIR = _base_log_dir / _current_date
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    LOG_FILE = LOG_DIR / f"{_current_timestamp}.log"
except OSError:
    LOG_DIR = Path("/tmp/logs") / _current_date
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    LOG_FILE = LOG_DIR / f"{_current_timestamp}.log"

_LOGGING_CONFIGURED = False


def get_logger(name: str = __name__) -> logging.Logger:
    global _LOGGING_CONFIGURED

    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)

    if not _LOGGING_CONFIGURED:
        formatter = logging.Formatter(
            "[%(asctime)s]: %(name)s: %(levelname)s: %(lineno)d: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )

        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(formatter)

        root_logger = logging.getLogger()
        root_logger.setLevel(logging.INFO)
        root_logger.addHandler(console_handler)

        try:
            file_handler = logging.FileHandler(LOG_FILE, encoding="utf-8")
            file_handler.setLevel(logging.DEBUG)
            file_handler.setFormatter(formatter)
            root_logger.addHandler(file_handler)
        except OSError:
            pass

        _LOGGING_CONFIGURED = True

    return logger