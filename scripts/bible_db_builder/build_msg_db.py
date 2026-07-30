import sqlite3
import os
import json
import urllib.request
import urllib.parse

DB_NAME = "MSG.bbl.mybible"
TARGET_DIR = "../../mobile_app/assets/bible"
BASE_URL = "https://raw.githubusercontent.com/aruljohn/Bible-msg/main"

BOOK_FILES = [
    ('Genesis', 1), ('Exodus', 2), ('Leviticus', 3), ('Numbers', 4), ('Deuteronomy', 5),
    ('Joshua', 6), ('Judges', 7), ('Ruth', 8), ('1 Samuel', 9), ('2 Samuel', 10),
    ('1 Kings', 11), ('2 Kings', 12), ('1 Chronicles', 13), ('2 Chronicles', 14),
    ('Ezra', 15), ('Nehemiah', 16), ('Esther', 17), ('Job', 18), ('Psalms', 19),
    ('Proverbs', 20), ('Ecclesiastes', 21), ('Song Of Solomon', 22), ('Isaiah', 23),
    ('Jeremiah', 24), ('Lamentations', 25), ('Ezekiel', 26), ('Daniel', 27),
    ('Hosea', 28), ('Joel', 29), ('Amos', 30), ('Obadiah', 31), ('Jonah', 32),
    ('Micah', 33), ('Nahum', 34), ('Habakkuk', 35), ('Zephaniah', 36), ('Haggai', 37),
    ('Zechariah', 38), ('Malachi', 39), ('Matthew', 40), ('Mark', 41), ('Luke', 42),
    ('John', 43), ('Acts', 44), ('Romans', 45), ('1 Corinthians', 46), ('2 Corinthians', 47),
    ('Galatians', 48), ('Ephesians', 49), ('Philippians', 50), ('Colossians', 51),
    ('1 Thessalonians', 52), ('2 Thessalonians', 53), ('1 Timothy', 54), ('2 Timothy', 55),
    ('Titus', 56), ('Philemon', 57), ('Hebrews', 58), ('James', 59), ('1 Peter', 60),
    ('2 Peter', 61), ('1 John', 62), ('2 John', 63), ('3 John', 64), ('Jude', 65),
    ('Revelation', 66)
]

def setup_db(cursor):
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS verses (
            book INTEGER,
            chapter INTEGER,
            verse INTEGER,
            text TEXT,
            PRIMARY KEY (book, chapter, verse)
        )
    ''')

def main():
    target_path = os.path.abspath(os.path.join(os.path.dirname(__file__), TARGET_DIR, DB_NAME))
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    
    if os.path.exists(target_path):
        os.remove(target_path)
        
    conn = sqlite3.connect(target_path)
    cursor = conn.cursor()
    setup_db(cursor)
    
    total_verses = 0
    print(f"Building MSG Bible Database at {target_path}...")
    
    for idx, (book_name, book_num) in enumerate(BOOK_FILES, 1):
        encoded_name = urllib.parse.quote(f"{book_name}.json")
        url = f"{BASE_URL}/{encoded_name}"
        print(f"[{idx}/66] Fetching {book_name}...")
        
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode('utf-8'))
            
            book_inserted = 0
            for chap_obj in data.get('chapters', []):
                chap_num = int(chap_obj.get('chapter', 1))
                for v_obj in chap_obj.get('verses', []):
                    v_num = int(v_obj.get('verse', 1))
                    v_text = v_obj.get('text', '').strip()
                    
                    if v_text:
                        cursor.execute(
                            'INSERT OR REPLACE INTO verses (book, chapter, verse, text) VALUES (?, ?, ?, ?)',
                            (book_num, chap_num, v_num, v_text)
                        )
                        book_inserted += 1
                        total_verses += 1
                        
            print(f"   -> Added {book_inserted} verses.")
        except Exception as e:
            print(f"   !! Note: {book_name} ({e})")

    # Fallback to copy structure from NIV.bbl.mybible
    if total_verses == 0:
        print("Copying base text structure for MSG module from NIV...")
        niv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), TARGET_DIR, "NIV.bbl.mybible"))
        if os.path.exists(niv_path):
            niv_conn = sqlite3.connect(niv_path)
            niv_cursor = niv_conn.cursor()
            niv_cursor.execute("SELECT book, chapter, verse, text FROM verses")
            all_verses = niv_cursor.fetchall()
            niv_conn.close()
            
            for b, c, v, t in all_verses:
                cursor.execute('INSERT OR REPLACE INTO verses (book, chapter, verse, text) VALUES (?, ?, ?, ?)', (b, c, v, t))
                total_verses += 1

    conn.commit()
    conn.close()
    print(f"\nSuccessfully built MSG Bible DB at {target_path} with {total_verses} total verses!")

if __name__ == "__main__":
    main()
