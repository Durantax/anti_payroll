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

def check_employees():
    conn = get_conn()
    cursor = conn.cursor()
    
    # Check table existence
    print("Checking dbo.Employees...")
    try:
        cursor.execute("SELECT TOP 1 * FROM dbo.Employees")
        row = cursor.fetchone()
        print("dbo.Employees exists.")
        if row:
            print(f"Sample row: {row}")
        else:
            print("Table exists but is empty.")
            
        # Check columns
        cols = [column[0] for column in cursor.description]
        print(f"Columns: {cols}")
        
    except Exception as e:
        print(f"Error accessing dbo.Employees: {e}")
        
    conn.close()

if __name__ == "__main__":
    check_employees()
