import pyodbc
import os

DB_SERVER = os.getenv("DB_SERVER", "25.2.89.129")
DB_PORT = os.getenv("DB_PORT", "1433")
DB_NAME = os.getenv("DB_NAME", "기본정보")
DB_USER = os.getenv("DB_USER", "user1")
DB_PASSWORD = os.getenv("DB_PASSWORD", "1536")

def get_conn():
    conn_str = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={DB_SERVER},{DB_PORT};"
        f"DATABASE={DB_NAME};"
        f"UID={DB_USER};PWD={DB_PASSWORD};"
        "TrustServerCertificate=YES;"
        "Encrypt=YES;"
        "Connection Timeout=5;"
    )
    return pyodbc.connect(conn_str)

def check_db():
    try:
        conn = get_conn()
        cursor = conn.cursor()
        print("Connected to DB successfully.")
        
        # Check '거래처'
        try:
            cursor.execute("SELECT TOP 1 * FROM dbo.거래처")
            row = cursor.fetchone()
            print("Table 'dbo.거래처' exists.")
            # Print columns
            cols = [column[0] for column in cursor.description]
            print(f"Columns in 'dbo.거래처': {cols}")
        except Exception as e:
            print(f"Error accessing 'dbo.거래처': {e}")
            
        # Check 'AppSettings'
        try:
            cursor.execute("SELECT TOP 1 * FROM dbo.AppSettings")
            row = cursor.fetchone()
            print("Table 'dbo.AppSettings' exists.")
            cols = [column[0] for column in cursor.description]
            print(f"Columns in 'dbo.AppSettings': {cols}")
        except Exception as e:
            print(f"Error accessing 'dbo.AppSettings': {e}")

        # Check 'SmtpConfig'
        try:
            cursor.execute("SELECT TOP 1 * FROM dbo.SmtpConfig")
            row = cursor.fetchone()
            print("Table 'dbo.SmtpConfig' exists.")
            cols = [column[0] for column in cursor.description]
            print(f"Columns in 'dbo.SmtpConfig': {cols}")
        except Exception as e:
            print(f"Error accessing 'dbo.SmtpConfig': {e}")
            
        conn.close()
    except Exception as e:
        print(f"DB Connection failed: {e}")

if __name__ == "__main__":
    check_db()
