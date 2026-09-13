"""
Database Connection & Session Factory Module
Supports both MySQL (Production Standard) and SQLite (Local Self-Contained Fallback).
"""

import os
import sqlite3
from pathlib import Path
from sqlalchemy import create_engine, text

BASE_DIR = Path(__file__).resolve().parent.parent

try:
    from dotenv import load_dotenv
    load_dotenv(BASE_DIR / ".env")
except ImportError:
    pass

# MySQL Configuration Defaults
MYSQL_USER = os.getenv("MYSQL_USER", "root")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "")
MYSQL_HOST = os.getenv("MYSQL_HOST", "127.0.0.1")
MYSQL_PORT = os.getenv("MYSQL_PORT", "3306")
MYSQL_DB = os.getenv("MYSQL_DB", "marketplace_db")

# SQLite Fallback Location
SQLITE_PATH = BASE_DIR / "data" / "processed" / "marketplace.db"


def get_engine():
    """
    Returns an active SQLAlchemy engine.
    Tries MySQL first; if unavailable, falls back gracefully to SQLite.
    """
    # 1. Attempt MySQL connection
    try:
        mysql_url = f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DB}"
        engine = create_engine(mysql_url, pool_pre_ping=True, connect_args={"connect_timeout": 3})
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return engine, "mysql"
    except Exception:
        pass

    # 2. Local SQLite Engine Fallback
    SQLITE_PATH.parent.mkdir(parents=True, exist_ok=True)
    sqlite_url = f"sqlite:///{SQLITE_PATH}"
    engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})
    return engine, "sqlite"


def execute_query(sql_statement: str, params: dict = None):
    """
    Executes a SQL query returning results as a pandas DataFrame.
    """
    import pandas as pd
    engine, dialect = get_engine()
    with engine.connect() as conn:
        df = pd.read_sql_query(text(sql_statement), conn, params=params)
    return df
