import os
import glob
from dotenv import load_dotenv
import google.generativeai as genai
from pinecone import Pinecone, ServerlessSpec
import pypdf
import docx

# Load keys
load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
INDEX_NAME = os.getenv("PINECONE_INDEX_NAME", "pastoral-sermons")

# Configure APIs
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
if PINECONE_API_KEY:
    pc = Pinecone(api_key=PINECONE_API_KEY)

def chunk_text(text, max_chars=1200, overlap=200):
    """Splits a document text into sliding chunks with overlap."""
    chunks = []
    start = 0
    while start < len(text):
        end = start + max_chars
        chunks.append(text[start:end])
        start += (max_chars - overlap)
    return chunks

def extract_text_from_pdf(file_path):
    reader = pypdf.PdfReader(file_path)
    text = ""
    for page in reader.pages:
        text += page.extract_text() or ""
    return text

def extract_text_from_docx(file_path):
    doc = docx.Document(file_path)
    text = ""
    for para in doc.paragraphs:
        text += para.text + "\n"
    return text

def extract_text(file_path):
    ext = os.path.splitext(file_path)[1].lower()
    if ext == '.txt':
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read()
    elif ext == '.pdf':
        return extract_text_from_pdf(file_path)
    elif ext == '.docx':
        return extract_text_from_docx(file_path)
    else:
        raise ValueError(f"Unsupported file format: {ext}")

def get_data_dir(data_dir="data"):
    if os.path.isabs(data_dir) and os.path.exists(data_dir):
        return data_dir
    # Check current directory
    if os.path.exists(data_dir):
        return data_dir
    # Check parent directory
    parent_data_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
    if os.path.exists(parent_data_dir):
        return parent_data_dir
    # Fallback to creating data folder in parent directory
    os.makedirs(parent_data_dir, exist_ok=True)
    return parent_data_dir

def embed_and_store_sermons(data_dir="data"):
    if not GEMINI_API_KEY or not PINECONE_API_KEY:
        print("Error: GEMINI_API_KEY and PINECONE_API_KEY must be set in your environment or .env file.")
        return

    # Ensure index exists
    if INDEX_NAME not in pc.list_indexes().names():
        print(f"Creating Pinecone index: {INDEX_NAME}...")
        pc.create_index(
            name=INDEX_NAME,
            dimension=768, # models/text-embedding-004 output dimension
            metric="cosine",
            spec=ServerlessSpec(cloud="aws", region="us-east-1")
        )
    
    index = pc.Index(INDEX_NAME)
    
    resolved_data_dir = get_data_dir(data_dir)
    print(f"Scanning directory: {resolved_data_dir} for sermon documents...")
    
    # Scan for supported formats
    pattern = os.path.join(resolved_data_dir, "*")
    files = [f for f in glob.glob(pattern) if os.path.splitext(f)[1].lower() in ['.txt', '.pdf', '.docx']]
    
    if not files:
        print(f"No sermon (.txt, .pdf, .docx) files found in '{resolved_data_dir}' directory.")
        return
        
    for file_path in files:
        title = os.path.basename(file_path).split('.')[0].replace("_", " ").title()
        print(f"Processing sermon: {title}")
        
        try:
            content = extract_text(file_path)
            if not content.strip():
                print(f"Skipping empty file: {file_path}")
                continue
                
            chunks = chunk_text(content)
            vectors_to_upsert = []
            
            for idx, chunk in enumerate(chunks):
                chunk_id = f"{os.path.basename(file_path)}_{idx}"
                
                # Generate embedding with Gemini models/text-embedding-004
                embedding_response = genai.embed_content(
                    model="models/text-embedding-004",
                    content=chunk,
                    task_type="retrieval_document",
                    title=title
                )
                embedding = embedding_response['embedding']
                
                vectors_to_upsert.append({
                    "id": chunk_id,
                    "values": embedding,
                    "metadata": {
                        "title": title,
                        "text": chunk
                    }
                })
                
            # Bulk upsert in batches of 100
            batch_size = 100
            for i in range(0, len(vectors_to_upsert), batch_size):
                batch = vectors_to_upsert[i : i + batch_size]
                index.upsert(vectors=batch)
                
            print(f"Successfully uploaded {len(chunks)} chunks for '{title}' to Pinecone.")
        except Exception as e:
            print(f"Error processing {file_path}: {e}")

if __name__ == "__main__":
    embed_and_store_sermons("data")
