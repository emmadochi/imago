import sqlite3
import os
import json
import urllib.request

DB_NAME = "crossref.db"
TARGET_DIR = "../../mobile_app/assets/bible"
BASE_URL = "https://raw.githubusercontent.com/josephilipraja/bible-cross-reference-json/master"

ABBREV_TO_BOOK = {
    'GEN': 1, 'EXO': 2, 'LEV': 3, 'NUM': 4, 'DEU': 5, 'JOS': 6, 'JDG': 7, 'RUT': 8,
    '1SA': 9, '2SA': 10, '1KI': 11, '2KI': 12, '1CH': 13, '2CH': 14, 'EZR': 15, 'NEH': 16,
    'EST': 17, 'JOB': 18, 'PSA': 19, 'PRO': 20, 'ECC': 21, 'SOS': 22, 'ISA': 23, 'JER': 24,
    'LAM': 25, 'EZE': 26, 'DAN': 27, 'HOS': 28, 'JOE': 29, 'AMO': 30, 'OBA': 31, 'JON': 32,
    'MIC': 33, 'NAH': 34, 'HAB': 35, 'ZEP': 36, 'HAG': 37, 'ZEC': 38, 'MAL': 39, 'MAT': 40,
    'MAR': 41, 'LUK': 42, 'JHN': 43, 'ACT': 44, 'ROM': 45, '1CO': 46, '2CO': 47, 'GAL': 48,
    'EPH': 49, 'PHL': 50, 'COL': 51, '1TH': 52, '2TH': 53, '1TI': 54, '2TI': 55, 'TIT': 56,
    'PHM': 57, 'HEB': 58, 'JAM': 59, '1PE': 60, '2PE': 61, '1JO': 62, '2JO': 63, '3JO': 64,
    'JDE': 65, 'REV': 66
}

ABBREV_TO_NAME = {
    'GEN': 'Genesis', 'EXO': 'Exodus', 'LEV': 'Leviticus', 'NUM': 'Numbers', 'DEU': 'Deuteronomy',
    'JOS': 'Joshua', 'JDG': 'Judges', 'RUT': 'Ruth', '1SA': '1 Samuel', '2SA': '2 Samuel',
    '1KI': '1 Kings', '2KI': '2 Kings', '1CH': '1 Chronicles', '2CH': '2 Chronicles',
    'EZR': 'Ezra', 'NEH': 'Nehemiah', 'EST': 'Esther', 'JOB': 'Job', 'PSA': 'Psalms',
    'PRO': 'Proverbs', 'ECC': 'Ecclesiastes', 'SOS': 'Song of Solomon', 'ISA': 'Isaiah',
    'JER': 'Jeremiah', 'LAM': 'Lamentations', 'EZE': 'Ezekiel', 'DAN': 'Daniel',
    'HOS': 'Hosea', 'JOE': 'Joel', 'AMO': 'Amos', 'OBA': 'Obadiah', 'JON': 'Jonah',
    'MIC': 'Micah', 'NAH': 'Nahum', 'HAB': 'Habakkuk', 'ZEP': 'Zephaniah', 'HAG': 'Haggai',
    'ZEC': 'Zechariah', 'MAL': 'Malachi', 'MAT': 'Matthew', 'MAR': 'Mark', 'LUK': 'Luke',
    'JHN': 'John', 'ACT': 'Acts', 'ROM': 'Romans', '1CO': '1 Corinthians', '2CO': '2 Corinthians',
    'GAL': 'Galatians', 'EPH': 'Ephesians', 'PHL': 'Philippians', 'COL': 'Colossians',
    '1TH': '1 Thessalonians', '2TH': '2 Thessalonians', '1TI': '1 Timothy', '2TI': '2 Timothy',
    'TIT': 'Titus', 'PHM': 'Philemon', 'HEB': 'Hebrews', 'JAM': 'James', '1PE': '1 Peter',
    '2PE': '2 Peter', '1JO': '1 John', '2JO': '2 John', '3JO': '3 John', 'JDE': 'Jude', 'REV': 'Revelation'
}

def format_target_ref(raw_target):
    # Raw target e.g. "GEN 50 21" -> "Genesis 50:21"
    parts = raw_target.strip().split(' ')
    if len(parts) == 3:
        abbrev, chap, verse = parts
        full_name = ABBREV_TO_NAME.get(abbrev, abbrev)
        return f"{full_name} {chap}:{verse}"
    return raw_target

def setup_db(cursor):
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS crossref (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            source_book INTEGER,
            source_chapter INTEGER,
            source_verse INTEGER,
            target_ref TEXT
        )
    ''')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_source ON crossref (source_book, source_chapter, source_verse)')

def main():
    target_path = os.path.abspath(os.path.join(os.path.dirname(__file__), TARGET_DIR, DB_NAME))
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    
    if os.path.exists(target_path):
        os.remove(target_path)
        
    conn = sqlite3.connect(target_path)
    cursor = conn.cursor()
    setup_db(cursor)
    
    total_entries = 0
    print(f"Starting TSK Cross-References build at {target_path}...")
    
    for file_num in range(1, 33):
        url = f"{BASE_URL}/{file_num}.json"
        print(f"[{file_num}/32] Fetching {file_num}.json...")
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode('utf-8'))
            
            file_inserted = 0
            for item_id, item_data in data.items():
                if isinstance(item_data, dict):
                    source_str = item_data.get('v', '') # e.g. "GEN 34 3"
                    targets_dict = item_data.get('r', {})
                    
                    source_parts = source_str.strip().split(' ')
                    if len(source_parts) == 3:
                        abbrev, chap_str, verse_str = source_parts
                        book_num = ABBREV_TO_BOOK.get(abbrev)
                        
                        if book_num and chap_str.isdigit() and verse_str.isdigit():
                            chap_num = int(chap_str)
                            verse_num = int(verse_str)
                            
                            for raw_target in targets_dict.values():
                                formatted_target = format_target_ref(raw_target)
                                cursor.execute(
                                    'INSERT INTO crossref (source_book, source_chapter, source_verse, target_ref) VALUES (?, ?, ?, ?)',
                                    (book_num, chap_num, verse_num, formatted_target)
                                )
                                file_inserted += 1
                                total_entries += 1
                                
            print(f"   -> Added {file_inserted} cross-references.")
        except Exception as e:
            print(f"   !! Error fetching {file_num}.json: {e}")

    conn.commit()
    conn.close()
    print(f"\nSuccessfully built TSK Cross-References DB at {target_path} with {total_entries} total references!")

if __name__ == "__main__":
    main()
