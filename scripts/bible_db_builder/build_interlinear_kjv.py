import sqlite3
import os
import json
import re
import urllib.request

DB_NAME = "KJV+.bbl.mybible"
BASE_KJV_PATH = "../../mobile_app/assets/bible/KJV.bbl.mybible"
TARGET_DIR = "../../mobile_app/assets/bible"
BASE_URL = "https://raw.githubusercontent.com/kaiserlik/kjv/main"

BOOK_FILES = [
    ("Gen.json", "Gen"), ("Exo.json", "Exo"), ("Lev.json", "Lev"), ("Num.json", "Num"),
    ("Deu.json", "Deu"), ("Jos.json", "Jos"), ("Jdg.json", "Jdg"), ("Rth.json", "Rth"),
    ("1Sa.json", "1Sa"), ("2Sa.json", "2Sa"), ("1Ki.json", "1Ki"), ("2Ki.json", "2Ki"),
    ("1Ch.json", "1Ch"), ("2Ch.json", "2Ch"), ("Ezr.json", "Ezr"), ("Neh.json", "Neh"),
    ("Est.json", "Est"), ("Job.json", "Job"), ("Psa.json", "Psa"), ("Pro.json", "Pro"),
    ("Ecc.json", "Ecc"), ("Sng.json", "Sng"), ("Isa.json", "Isa"), ("Jer.json", "Jer"),
    ("Lam.json", "Lam"), ("Eze.json", "Eze"), ("Dan.json", "Dan"), ("Hos.json", "Hos"),
    ("Joe.json", "Joe"), ("Amo.json", "Amo"), ("Oba.json", "Oba"), ("Jon.json", "Jon"),
    ("Mic.json", "Mic"), ("Nah.json", "Nah"), ("Hab.json", "Hab"), ("Zep.json", "Zep"),
    ("Hag.json", "Hag"), ("Zec.json", "Zec"), ("Mal.json", "Mal"), ("Mat.json", "Mat"),
    ("Mar.json", "Mar"), ("Luk.json", "Luk"), ("Jhn.json", "Jhn"), ("Act.json", "Act"),
    ("Rom.json", "Rom"), ("1Co.json", "1Co"), ("2Co.json", "2Co"), ("Gal.json", "Gal"),
    ("Eph.json", "Eph"), ("Phl.json", "Phl"), ("Col.json", "Col"), ("1Th.json", "1Th"),
    ("2Th.json", "2Th"), ("1Ti.json", "1Ti"), ("2Ti.json", "2Ti"), ("Tit.json", "Tit"),
    ("Phm.json", "Phm"), ("Heb.json", "Heb"), ("Jas.json", "Jas"), ("1Pe.json", "1Pe"),
    ("2Pe.json", "2Pe"), ("1Jo.json", "1Jo"), ("2Jo.json", "2Jo"), ("3Jo.json", "3Jo"),
    ("Jde.json", "Jde"), ("Rev.json", "Rev"),
]

def clean_json_str(raw):
    # Fix control characters or unescaped tabs/newlines in raw json
    cleaned = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', raw)
    return cleaned

def main():
    script_dir = os.path.dirname(__file__)
    base_db_path = os.path.abspath(os.path.join(script_dir, BASE_KJV_PATH))
    target_path = os.path.abspath(os.path.join(script_dir, TARGET_DIR, DB_NAME))
    
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    
    # 1. Copy base KJV DB to KJV+ DB as baseline
    if os.path.exists(target_path):
        os.remove(target_path)
        
    print(f"Seeding base KJV database from {base_db_path}...")
    base_conn = sqlite3.connect(base_db_path)
    base_cursor = base_conn.cursor()
    
    target_conn = sqlite3.connect(target_path)
    target_cursor = target_conn.cursor()
    
    target_cursor.execute('''
        CREATE TABLE IF NOT EXISTS Bible (
            Book INTEGER,
            Chapter INTEGER,
            Verse INTEGER,
            Scripture TEXT
        )
    ''')
    
    base_rows = base_cursor.execute('SELECT Book, Chapter, Verse, Scripture FROM Bible ORDER BY Book, Chapter, Verse').fetchall()
    target_cursor.executemany('INSERT INTO Bible (Book, Chapter, Verse, Scripture) VALUES (?, ?, ?, ?)', base_rows)
    target_conn.commit()
    base_conn.close()
    
    print(f"Seeded {len(base_rows)} baseline verses into {DB_NAME}.")
    
    # 2. Overlay Strong's tagged text from GitHub
    updated_count = 0
    for book_idx, (filename, book_code) in enumerate(BOOK_FILES, start=1):
        url = f"{BASE_URL}/{filename}"
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req) as resp:
                raw_bytes = resp.read()
                raw_str = raw_bytes.decode('utf-8', errors='ignore')
                
            try:
                data = json.loads(raw_str)
            except Exception:
                data = json.loads(clean_json_str(raw_str))
                
            book_dict = data.get(book_code, {})
            book_updated = 0
            
            for chap_key, chap_data in book_dict.items():
                if isinstance(chap_data, dict):
                    try:
                        chap_num = int(chap_key.split('|')[1])
                    except Exception:
                        continue
                        
                    for verse_key, verse_data in chap_data.items():
                        if isinstance(verse_data, dict):
                            try:
                                verse_num = int(verse_key.split('|')[2])
                            except Exception:
                                continue
                                
                            text = verse_data.get('en', '').strip()
                            if text and '[' in text:
                                target_cursor.execute(
                                    'UPDATE Bible SET Scripture = ? WHERE Book = ? AND Chapter = ? AND Verse = ?',
                                    (text, book_idx, chap_num, verse_num)
                                )
                                book_updated += 1
                                updated_count += 1
                                
            print(f"[{book_idx}/66] {book_code}: Tagged {book_updated} verses with Strong's numbers.")
        except Exception as e:
            print(f"[{book_idx}/66] {book_code}: Failed to download/parse ({e}) - retained baseline text.")

    target_cursor.execute('CREATE INDEX IF NOT EXISTS idx_bible ON Bible (Book, Chapter, Verse)')
    target_conn.commit()
    target_conn.close()
    print(f"\nSuccessfully built complete Interlinear KJV+ DB at {target_path}! (31,102 verses total, {updated_count} tagged with Strong's numbers)")

if __name__ == "__main__":
    main()
