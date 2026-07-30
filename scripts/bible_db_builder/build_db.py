import sqlite3
import urllib.request
import json
import os

DB_NAME = "imago_bible.sqlite"
KJV_URL = "https://raw.githubusercontent.com/thiagobodruk/bible/master/json/en_kjv.json"

def setup_db(cursor):
    print("Setting up database schema...")
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS translations (
            id TEXT PRIMARY KEY,
            name TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            abbrev TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            translation_id TEXT,
            book_id INTEGER,
            chapter INTEGER,
            verse INTEGER,
            text TEXT,
            FOREIGN KEY(translation_id) REFERENCES translations(id),
            FOREIGN KEY(book_id) REFERENCES books(id)
        )
    ''')
    
    # Dictionary schema
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS dictionary (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            term TEXT,
            definition TEXT
        )
    ''')

def insert_bible(cursor, url, translation_id, translation_name):
    print(f"Downloading {translation_name} from {url}...")
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode('utf-8-sig'))
        
    print(f"Inserting {translation_name} into database...")
    cursor.execute("INSERT OR IGNORE INTO translations (id, name) VALUES (?, ?)", (translation_id, translation_name))
    
    for book_idx, book in enumerate(data):
        book_name = book.get("name")
        book_abbrev = book.get("abbrev")
        
        # Insert book if not exists
        cursor.execute("SELECT id FROM books WHERE name = ?", (book_name,))
        row = cursor.fetchone()
        if not row:
            cursor.execute("INSERT INTO books (name, abbrev) VALUES (?, ?)", (book_name, book_abbrev))
            book_id = cursor.lastrowid
        else:
            book_id = row[0]
            
        chapters = book.get("chapters", [])
        verses_to_insert = []
        for chapter_idx, chapter in enumerate(chapters):
            for verse_idx, verse_text in enumerate(chapter):
                verses_to_insert.append((
                    translation_id,
                    book_id,
                    chapter_idx + 1,
                    verse_idx + 1,
                    verse_text
                ))
        
        cursor.executemany('''
            INSERT INTO verses (translation_id, book_id, chapter, verse, text)
            VALUES (?, ?, ?, ?, ?)
        ''', verses_to_insert)
        
    print(f"Finished inserting {translation_name}.")

def main():
    if os.path.exists(DB_NAME):
        os.remove(DB_NAME)
        
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    
    setup_db(cursor)
    
    # Insert KJV
    insert_bible(cursor, KJV_URL, "KJV", "King James Version")
    
    # NOTE: We can add WEB and Easton's dictionary later once we find reliable JSON URLs for them.
    
    conn.commit()
    conn.close()
    print("Database built successfully!")

if __name__ == "__main__":
    main()
