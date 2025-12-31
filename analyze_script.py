import re

def search_table(filename, table_name):
    try:
        with open(filename, 'r', encoding='utf-16') as f:
            content = f.read()
    except UnicodeError:
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeError:
            print(f"Failed to read {filename} with both utf-16 and utf-8")
            return

    # Normalized search (remove brackets/dbo)
    pattern = re.compile(f"CREATE TABLE.*{table_name}", re.IGNORECASE)
    
    pos = 0
    while True:
        match = pattern.search(content, pos)
        if not match:
            break
        print(f"\n--- Found {table_name} ---")
        start = match.start()
        # Find end of table definition (simplistic approximation: next GO or CREATE)
        end_go = content.find("GO", start)
        end_create = content.find("CREATE TABLE", start + 1)
        
        end = end_go if end_go != -1 else len(content)
        if end_create != -1 and end_create < end:
            end = end_create
            
        print(content[start:end][:500]) # Print first 500 chars of definition
        pos = end

print("Searching for '거래처'...")
search_table('script.sql', '거래처')

print("\nSearching for 'Settings'...")
search_table('script.sql', 'Setting')

print("\nSearching for 'Config'...")
search_table('script.sql', 'Config')

print("\nSearching for 'Mail'...")
search_table('script.sql', 'Mail')

print("\nSearching for 'SMTP'...")
search_table('script.sql', 'SMTP')
