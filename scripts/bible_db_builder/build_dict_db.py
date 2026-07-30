import sqlite3
import os
import json
import re
import urllib.request

DB_NAME = "dictionary.db"
TARGET_DIR = "../../mobile_app/assets/bible"

EASTON_URL = "https://raw.githubusercontent.com/garydavenport73/eastons-bible-dictionary-json/main/eastons.json"
GREEK_URL = "https://raw.githubusercontent.com/openscriptures/strongs/master/greek/strongs-greek-dictionary.js"
HEBREW_URL = "https://raw.githubusercontent.com/openscriptures/strongs/master/hebrew/strongs-hebrew-dictionary.js"

def setup_db(cursor):
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS dictionary (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            strongs TEXT,
            term TEXT,
            translit TEXT,
            pron TEXT,
            definition TEXT,
            type TEXT
        )
    ''')

def fetch_json_from_js(url):
    print(f"Fetching {url}...")
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        content = response.read().decode('utf-8')
    
    # Strip JS variable assignment if present (find first { to last })
    start_idx = content.find('{')
    end_idx = content.rfind('}')
    if start_idx != -1 and end_idx != -1:
        json_str = content[start_idx:end_idx+1]
        return json.loads(json_str)
    raise ValueError(f"Could not parse JSON from {url}")

def main():
    target_path = os.path.abspath(os.path.join(os.path.dirname(__file__), TARGET_DIR, DB_NAME))
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    
    if os.path.exists(target_path):
        os.remove(target_path)
        
    conn = sqlite3.connect(target_path)
    cursor = conn.cursor()
    setup_db(cursor)
    
    total_inserted = 0
    
    # 1. Process Easton's Bible Dictionary
    try:
        print(f"Downloading Easton's Bible Dictionary from {EASTON_URL}...")
        req = urllib.request.urlopen(EASTON_URL)
        easton_data = json.loads(req.read())
        easton_count = 0
        for term, entries in easton_data.items():
            if isinstance(entries, list) and len(entries) > 0:
                definition = "\n\n".join(entry.get("definition", "") for entry in entries if entry.get("definition"))
                if definition:
                    cursor.execute(
                        "INSERT INTO dictionary (strongs, term, translit, pron, definition, type) VALUES (?, ?, ?, ?, ?, ?)",
                        (None, term, None, None, definition, 'easton')
                    )
                    easton_count += 1
        print(f"Added {easton_count} Easton entries.")
        total_inserted += easton_count
    except Exception as e:
        print(f"Error processing Easton: {e}")

    # 2. Process Strong's Greek
    try:
        greek_data = fetch_json_from_js(GREEK_URL)
        greek_count = 0
        for key, entry in greek_data.items():
            lemma = entry.get("lemma", "")
            translit = entry.get("xlit", "") or entry.get("translit", "")
            pron = entry.get("pron", "")
            derivation = entry.get("derivation", "")
            kjv_def = entry.get("kjv_def", "")
            strongs_def = entry.get("strongs_def", "")
            
            full_def_parts = []
            if lemma:
                full_def_parts.append(f"Lemma: {lemma}")
            if translit:
                full_def_parts.append(f"Transliteration: {translit}")
            if pron:
                full_def_parts.append(f"Pronunciation: {pron}")
            if derivation:
                full_def_parts.append(f"Derivation: {derivation}")
            if strongs_def:
                full_def_parts.append(f"Strong's Definition:\n{strongs_def}")
            if kjv_def:
                full_def_parts.append(f"KJV Translation:\n{kjv_def}")
                
            definition = "\n\n".join(full_def_parts)
            term = f"{key} - {lemma}" if lemma else key
            
            cursor.execute(
                "INSERT INTO dictionary (strongs, term, translit, pron, definition, type) VALUES (?, ?, ?, ?, ?, ?)",
                (key, term, translit, pron, definition, 'greek')
            )
            greek_count += 1
        print(f"Added {greek_count} Greek entries.")
        total_inserted += greek_count
    except Exception as e:
        print(f"Error processing Greek: {e}")

    # 3. Process Strong's Hebrew
    try:
        hebrew_data = fetch_json_from_js(HEBREW_URL)
        hebrew_count = 0
        for key, entry in hebrew_data.items():
            lemma = entry.get("lemma", "")
            translit = entry.get("xlit", "") or entry.get("translit", "")
            pron = entry.get("pron", "")
            derivation = entry.get("derivation", "")
            kjv_def = entry.get("kjv_def", "")
            strongs_def = entry.get("strongs_def", "")
            
            full_def_parts = []
            if lemma:
                full_def_parts.append(f"Lemma: {lemma}")
            if translit:
                full_def_parts.append(f"Transliteration: {translit}")
            if pron:
                full_def_parts.append(f"Pronunciation: {pron}")
            if derivation:
                full_def_parts.append(f"Derivation: {derivation}")
            if strongs_def:
                full_def_parts.append(f"Strong's Definition:\n{strongs_def}")
            if kjv_def:
                full_def_parts.append(f"KJV Translation:\n{kjv_def}")
                
            definition = "\n\n".join(full_def_parts)
            term = f"{key} - {lemma}" if lemma else key
            
            cursor.execute(
                "INSERT INTO dictionary (strongs, term, translit, pron, definition, type) VALUES (?, ?, ?, ?, ?, ?)",
                (key, term, translit, pron, definition, 'hebrew')
            )
            hebrew_count += 1
        print(f"Added {hebrew_count} Hebrew entries.")
        total_inserted += hebrew_count
    except Exception as e:
        print(f"Error processing Hebrew: {e}")

    conn.commit()
    conn.close()
    print(f"Unified dictionary database built successfully at {target_path} with {total_inserted} total terms!")

if __name__ == "__main__":
    main()
