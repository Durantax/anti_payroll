import re

def list_tables(filename):
    try:
        with open(filename, 'r', encoding='utf-16') as f:
            content = f.read()
    except UnicodeError:
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                content = f.read()
            print("Read used utf-8")
        except UnicodeError:
            print(f"Failed to read {filename}")
            return

    # Regex for CREATE TABLE [dbo].[TableName] or CREATE TABLE dbo.TableName
    pattern = re.compile(r"CREATE\s+TABLE\s+(?:\[?dbo\]?\.\[?(\w+|[가-힣]+)\]?)", re.IGNORECASE)
    matches = pattern.findall(content)
    
    print("Found Tables:")
    for m in matches:
        print(f"- {m}")
        
    print("\nCheck specific tables:")
    for target in ['AppSettings', 'SmtpConfig', '거래처', 'PayrollResults', 'PayrollMonthlyInput']:
        found = False
        for m in matches:
            if m.lower() == target.lower():
                found = True
                break
        print(f"{target}: {'FOUND' if found else 'NOT FOUND'}")

list_tables('script.sql')
