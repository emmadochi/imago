import os
import io
import time
import urllib.request
import urllib.error
import hmac
import hashlib
import uuid
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, Form, HTTPException, Response, UploadFile, File, Request, Depends, Header
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from dotenv import load_dotenv
from google import genai
from google.genai import types as genai_types
from pinecone import Pinecone
import pypdf
import docx
import json
import datetime
from pathlib import Path
import edge_tts

# Firebase Admin setup for Firestore Cloud Persistence
firestore_db = None
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    if not firebase_admin._apps:
        # Initialize Firebase Admin app
        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
        cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
        if cred_json:
            cred = credentials.Certificate(json.loads(cred_json))
            firebase_admin.initialize_app(cred)
        elif cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        else:
            firebase_admin.initialize_app(options={"projectId": "imago-bbd56"})
    firestore_db = firestore.client()
    print("INFO:     Firebase Firestore initialized for cloud persistence.")
except Exception as e:
    print(f"INFO:     Firestore offline, using local storage fallback: {e}")

# Database & Connection Pooler Integration (Optional / Fallback Safe)
try:
    from .database import check_db_health, get_db_session
    from .models import User, PaymentTransaction
except Exception:
    try:
        from database import check_db_health, get_db_session
        from models import User, PaymentTransaction
    except Exception:
        async def check_db_health():
            return {"status": "stateless", "message": "Running in stateless cloud mode"}
        async def get_db_session():
            yield None
        User = None
        PaymentTransaction = None

# Setup Data Directory for document tracking
DATA_DIR = Path("app/data")
DATA_DIR.mkdir(parents=True, exist_ok=True)
DOCS_FILE = DATA_DIR / "documents.json"
YOUTUBE_CACHE_FILE = DATA_DIR / "youtube_cache.json"
PODCAST_CACHE_FILE = DATA_DIR / "podcast_cache.json"
ANALYTICS_FILE = DATA_DIR / "analytics.json"
COMMUNITY_PRAYERS_FILE = DATA_DIR / "community_prayers.json"
FEEDBACK_FILE = DATA_DIR / "feedback.json"
MICRO_FEEDBACK_FILE = DATA_DIR / "micro_feedback.json"
TRANSACTIONS_FILE = DATA_DIR / "transactions.json"
PARTNERS_FILE = DATA_DIR / "partners.json"

PAYSTACK_SECRET_KEY = os.getenv("PAYSTACK_SECRET_KEY", "").strip()
PAYSTACK_PUBLIC_KEY = os.getenv("PAYSTACK_PUBLIC_KEY", "").strip()

def load_local_transactions() -> list:
    if not TRANSACTIONS_FILE.exists():
        return []
    try:
        with open(TRANSACTIONS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return []

def save_local_transaction(item: dict):
    items = load_local_transactions()
    for idx, existing in enumerate(items):
        if existing.get("reference") == item.get("reference"):
            items[idx] = item
            break
    else:
        items.insert(0, item)
    try:
        with open(TRANSACTIONS_FILE, "w") as f:
            json.dump(items, f, indent=4)
    except Exception:
        pass

def load_local_partners() -> dict:
    if not PARTNERS_FILE.exists():
        return {}
    try:
        with open(PARTNERS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def save_local_partner(key: str, data: dict):
    if not key:
        return
    partners = load_local_partners()
    partners[key.lower().strip()] = data
    try:
        with open(PARTNERS_FILE, "w") as f:
            json.dump(partners, f, indent=4)
    except Exception:
        pass

async def upgrade_user_partner_tier(
    email: str,
    tier: str,
    user_id: Optional[str] = None,
    amount: int = 0,
    reference: Optional[str] = None,
    db_session: Optional[Any] = None
):
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    partner_record = {
        "email": email,
        "user_id": user_id,
        "partner_tier": tier,
        "amount": amount,
        "reference": reference,
        "is_partner": True,
        "updated_at": now_iso
    }
    
    # 1. Local storage fallback
    if email:
        save_local_partner(email, partner_record)
    if user_id:
        save_local_partner(user_id, partner_record)

    # 2. Firebase Firestore persistence
    if firestore_db:
        try:
            doc_id = user_id or email
            if doc_id:
                firestore_db.collection("users").document(doc_id).set({
                    "partner_tier": tier,
                    "is_partner": True,
                    "email": email,
                    "last_contribution_amount": amount,
                    "last_payment_reference": reference,
                    "updated_at": firestore.SERVER_TIMESTAMP,
                }, merge=True)
                print(f"INFO: Updated partner tier in Firestore for {doc_id} -> {tier}")
        except Exception as e:
            print(f"Warning: Firestore partner tier update error: {e}")

    # 3. PostgreSQL database persistence
    if db_session and User is not None:
        try:
            from sqlalchemy import select
            query = None
            if user_id:
                query = select(User).where(User.id == user_id)
            elif email:
                query = select(User).where(User.email == email)
            if query is not None:
                res = await db_session.execute(query)
                user_obj = res.scalar_one_or_none()
                if user_obj:
                    user_obj.partner_tier = tier
                    await db_session.commit()
                    print(f"INFO: Updated partner tier in PostgreSQL for {user_obj.email} -> {tier}")
        except Exception as e:
            print(f"Warning: PostgreSQL partner tier update error: {e}")


def load_feedback() -> list:
    if firestore_db:
        try:
            doc = firestore_db.collection("imago_meta").document("user_feedback").get()
            if doc.exists:
                return doc.to_dict().get("list", [])
        except Exception as e:
            print(f"Warning: Firestore load feedback error: {e}")
    if not FEEDBACK_FILE.exists():
        return []
    try:
        with open(FEEDBACK_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return []

def save_feedback(items: list):
    if firestore_db:
        try:
            firestore_db.collection("imago_meta").document("user_feedback").set({"list": items}, merge=True)
        except Exception as e:
            print(f"Warning: Firestore save feedback error: {e}")
    try:
        with open(FEEDBACK_FILE, "w") as f:
            json.dump(items, f, indent=4)
    except Exception:
        pass

def load_micro_feedback() -> list:
    if not MICRO_FEEDBACK_FILE.exists():
        return []
    try:
        with open(MICRO_FEEDBACK_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return []

def save_micro_feedback(items: list):
    try:
        with open(MICRO_FEEDBACK_FILE, "w") as f:
            json.dump(items, f, indent=4)
    except Exception:
        pass

def load_community_prayers() -> list:
    if firestore_db:
        try:
            doc = firestore_db.collection("imago_meta").document("community_prayers").get()
            if doc.exists:
                data = doc.to_dict()
                return data.get("list", [])
        except Exception as e:
            print(f"Warning: Firestore load community prayers error: {e}")
    if not COMMUNITY_PRAYERS_FILE.exists():
        return []
    try:
        with open(COMMUNITY_PRAYERS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return []

def save_community_prayers(prayers: list):
    if firestore_db:
        try:
            firestore_db.collection("imago_meta").document("community_prayers").set({"list": prayers}, merge=True)
        except Exception as e:
            print(f"Warning: Firestore save community prayers error: {e}")
    try:
        with open(COMMUNITY_PRAYERS_FILE, "w") as f:
            json.dump(prayers, f, indent=4)
    except Exception:
        pass

def load_analytics() -> dict:
    if firestore_db:
        try:
            doc = firestore_db.collection("imago_meta").document("analytics").get()
            if doc.exists:
                return doc.to_dict()
        except Exception as e:
            print(f"Warning: Firestore load analytics error: {e}")
    if not ANALYTICS_FILE.exists():
        return {"moods": [], "prayers": []}
    try:
        with open(ANALYTICS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {"moods": [], "prayers": []}

def save_analytics(data: dict):
    if firestore_db:
        try:
            firestore_db.collection("imago_meta").document("analytics").set(data, merge=True)
        except Exception as e:
            print(f"Warning: Firestore save analytics error: {e}")
    try:
        with open(ANALYTICS_FILE, "w") as f:
            json.dump(data, f, indent=4)
    except Exception:
        pass

def load_documents() -> list:
    if firestore_db:
        try:
            doc = firestore_db.collection("imago_meta").document("documents").get()
            if doc.exists:
                data = doc.to_dict()
                return data.get("list", [])
        except Exception as e:
            print(f"Warning: Firestore load documents error: {e}")
    if not DOCS_FILE.exists():
        return []
    try:
        with open(DOCS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return []

def save_documents(docs: list):
    if firestore_db:
        try:
            firestore_db.collection("imago_meta").document("documents").set({"list": docs}, merge=True)
        except Exception as e:
            print(f"Warning: Firestore save documents error: {e}")
    try:
        with open(DOCS_FILE, "w") as f:
            json.dump(docs, f, indent=4)
    except Exception:
        pass

_cached_youtube_videos = None
_cached_youtube_timestamp = 0
_cached_podcasts = None
_cached_podcasts_timestamp = 0

def load_youtube_videos() -> list:
    global _cached_youtube_videos, _cached_youtube_timestamp
    now = time.time()
    if _cached_youtube_videos is not None and (now - _cached_youtube_timestamp < 600):
        return _cached_youtube_videos

    videos = []
    if firestore_db:
        try:
            doc = firestore_db.collection("imago_meta").document("youtube_cache").get()
            if doc.exists:
                data = doc.to_dict()
                videos = data.get("list", [])
        except Exception as e:
            print(f"Warning: Firestore load youtube error: {e}")
    if not videos and YOUTUBE_CACHE_FILE.exists():
        try:
            with open(YOUTUBE_CACHE_FILE, "r") as f:
                videos = json.load(f)
        except Exception:
            videos = []
    _cached_youtube_videos = videos
    _cached_youtube_timestamp = now
    return videos

def save_youtube_videos(videos: list):
    global _cached_youtube_videos, _cached_youtube_timestamp
    _cached_youtube_videos = videos
    _cached_youtube_timestamp = time.time()
    if firestore_db:
        try:
            firestore_db.collection("imago_meta").document("youtube_cache").set({"list": videos}, merge=True)
        except Exception as e:
            print(f"Warning: Firestore save youtube error: {e}")
    try:
        with open(YOUTUBE_CACHE_FILE, "w") as f:
            json.dump(videos, f, indent=4)
    except Exception:
        pass

def load_podcasts() -> list:
    global _cached_podcasts, _cached_podcasts_timestamp
    now = time.time()
    if _cached_podcasts is not None and (now - _cached_podcasts_timestamp < 600):
        return _cached_podcasts

    podcasts = []
    if firestore_db:
        try:
            doc = firestore_db.collection("imago_meta").document("podcast_cache").get()
            if doc.exists:
                data = doc.to_dict()
                podcasts = data.get("list", [])
        except Exception as e:
            print(f"Warning: Firestore load podcast error: {e}")
    if not podcasts and PODCAST_CACHE_FILE.exists():
        try:
            with open(PODCAST_CACHE_FILE, "r") as f:
                podcasts = json.load(f)
        except Exception:
            podcasts = []
    _cached_podcasts = podcasts
    _cached_podcasts_timestamp = now
    return podcasts

def save_podcasts(podcasts: list):
    global _cached_podcasts, _cached_podcasts_timestamp
    _cached_podcasts = podcasts
    _cached_podcasts_timestamp = time.time()
    if firestore_db:
        try:
            firestore_db.collection("imago_meta").document("podcast_cache").set({"list": podcasts}, merge=True)
        except Exception as e:
            print(f"Warning: Firestore save podcast error: {e}")
    try:
        with open(PODCAST_CACHE_FILE, "w") as f:
            json.dump(podcasts, f, indent=4)
    except Exception:
        pass

# Load environment
load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
INDEX_NAME = os.getenv("PINECONE_INDEX_NAME", "pastoral-sermons")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

# Setup Gemini client
client = None
if GEMINI_API_KEY:
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        print("INFO:     Gemini client initialized successfully.")
    except Exception as e:
        print(f"WARNING: Failed to initialize Gemini client: {e}")
else:
    print("WARNING: GEMINI_API_KEY is not set in .env file.")

def call_gemini_with_fallback(contents, config=None):
    """Resiliently executes Gemini generation with automatic fallback across supported model identifiers."""
    models = ["gemini-2.5-flash", "gemini-3.6-flash", "gemini-flash-latest"]
    last_err = None
    for m in models:
        try:
            return client.models.generate_content(
                model=m,
                contents=contents,
                config=config,
            )
        except Exception as e:
            last_err = e
            print(f"WARN: Gemini model '{m}' failed: {e}. Trying fallback...")
    raise last_err or RuntimeError("All Gemini generation models failed")

def transcribe_audio_bytes(audio_bytes: bytes, mime: str = "audio/mp4") -> str:
    """Fast transcription prioritizing Groq Whisper Turbo (<400ms) with Gemini multimodal fallback."""
    if GROQ_API_KEY:
        try:
            boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
            body = (
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="model"\r\n\r\n'
                f"whisper-large-v3-turbo\r\n"
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="temperature"\r\n\r\n'
                f"0.0\r\n"
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="file"; filename="audio.m4a"\r\n'
                f"Content-Type: audio/mp4\r\n\r\n"
            ).encode("utf-8") + audio_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

            req = urllib.request.Request(
                "https://api.groq.com/openai/v1/audio/transcriptions",
                data=body,
                headers={
                    "Authorization": f"Bearer {GROQ_API_KEY}",
                    "Content-Type": f"multipart/form-data; boundary={boundary}",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=8) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                text = data.get("text", "").strip()
                if text:
                    return text
        except Exception as ge:
            print(f"WARN: Groq transcription failed, trying Gemini: {ge}")

    # Fallback to Gemini
    gen_config = genai_types.GenerateContentConfig(
        max_output_tokens=300,
        temperature=0.0,
    ) if hasattr(genai_types, 'GenerateContentConfig') else None

    transcript_response = call_gemini_with_fallback(
        contents=[
            genai_types.Part.from_bytes(data=audio_bytes, mime_type=mime),
            "Transcribe this audio verbatim. Output ONLY the transcribed words with zero additional commentary or chat."
        ],
        config=gen_config,
    )
    return transcript_response.text.strip() if transcript_response and transcript_response.text else ""

def embed_content_with_fallback(text: str, task_type: str = "RETRIEVAL_QUERY"):
    """Resiliently executes Gemini text embedding with fallback models."""
    models = ["gemini-embedding-2", "gemini-embedding-001", "text-embedding-004"]
    last_err = None
    for m in models:
        try:
            res = client.models.embed_content(
                model=m,
                contents=text,
                config=genai_types.EmbedContentConfig(task_type=task_type)
            )
            return res.embeddings[0].values
        except Exception as e:
            last_err = e
            print(f"WARN: Embedding model '{m}' failed: {e}. Trying fallback...")
    raise last_err or RuntimeError("All Gemini embedding models failed")

index = None
if PINECONE_API_KEY:
    try:
        pc = Pinecone(api_key=PINECONE_API_KEY)
        index = pc.Index(INDEX_NAME)
    except Exception as e:
        print(f"WARNING: Pinecone connection error: {e}")
else:
    print("WARNING: PINECONE_API_KEY is not set in .env file.")

tags_metadata = [
    {
        "name": "Chat & AI",
        "description": "Conversational spiritual counseling, pastoral guidance powered by Google Gemini, audio transcription, and real-time WebSockets.",
    },
    {
        "name": "Bible & Translations",
        "description": "Scripture translation and multi-lingual Bible passage generation.",
    },
    {
        "name": "Sermons & RAG",
        "description": "Sermon document ingestion (PDF/DOCX/TXT), Pinecone vector embedding retrieval, and sermon library.",
    },
    {
        "name": "Prayer & Community",
        "description": "Personalized prayer generation and public community prayer requests with intercessory prayer counters.",
    },
    {
        "name": "Devotionals",
        "description": "Daily devotional guides with Scripture readings, reflections, and prayers.",
    },
    {
        "name": "Admin & Ingestion",
        "description": "Automated ingestion pipelines for YouTube sermons and audio podcasts, plus live admin dashboard metrics.",
    },
    {
        "name": "Feedback & Analytics",
        "description": "User experience feedback, mood analytics, and sentiment tracking.",
    },
    {
        "name": "System",
        "description": "System health checks and third-party webhook integrations.",
    },
]

app = FastAPI(
    title="Imago Pastoral AI Backend API",
    description="""
## Imago Pastoral AI & Church Management API

Interactive OpenAPI / Swagger documentation for the **Imago** backend.

### Key Capabilities:
- 🕊️ **Pastoral AI Chat**: Context-aware spiritual counseling with RAG citations from church sermons using Google Gemini & Pinecone.
- 📖 **Bible & Scripture**: Multi-lingual translations and verse explanations.
- 🎙️ **Audio & Sermons**: Audio file processing, sermon transcriptions, and automated YouTube/Podcast ingestors.
- 🙏 **Community Prayer Wall**: Live prayer requests with real-time intercessor counters.
- 🌅 **Daily Devotionals**: Automated scripture reflections and prayers.
- 📊 **Mood & Analytics**: Spiritual health and emotional wellbeing analytics.
    """,
    version="1.0.0",
    openapi_tags=tags_metadata,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Mount Admin Dashboard (Safely resolves relative to current file)
admin_dir = Path(__file__).resolve().parent / "admin"
if admin_dir.exists():
    app.mount("/admin", StaticFiles(directory=str(admin_dir), html=True), name="admin")
elif Path("app/admin").exists():
    app.mount("/admin", StaticFiles(directory="app/admin", html=True), name="admin")

# Simulated Sermon Database for audio recommendations
SERMONS_DB = [
    {
        "title": "Faith Over Fear",
        "pastor": "Pastor Henry",
        "length": "42 mins",
        "topic": "anxiety",
        "audio_url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"
    },
    {
        "title": "Strength in the Storm",
        "pastor": "Pastor Henry",
        "length": "38 mins",
        "topic": "discouraged",
        "audio_url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3"
    },
    {
        "title": "The Present Helper",
        "pastor": "Pastor Henry",
        "length": "45 mins",
        "topic": "lonely",
        "audio_url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3"
    },
    {
        "title": "Rest for Your Souls",
        "pastor": "Pastor Henry",
        "length": "35 mins",
        "topic": "tired",
        "audio_url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3"
    },
    {
        "title": "Walking in Joy",
        "pastor": "Pastor Henry",
        "length": "40 mins",
        "topic": "joyful",
        "audio_url": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3"
    }
]

# Crisis Guardrails & Hardcoded Safety Responses
CRISIS_KEYWORDS = [
    "suicide", "kill myself", "abuse", "hurt myself", 
    "end my life", "self-harm", "wanna die", "want to die"
]

CRISIS_RESPONSE = (
    "If you are in distress or experiencing thoughts of self-harm, please know that you are not alone. "
    "There is hope and support available. Please contact the National Suicide Prevention Lifeline by dialing 988 (in the US), "
    "or reach out to local emergency services immediately. You can also contact our human care ministry team at "
    "care@churchdomain.org or +1 (555) 123-4567. We are here to support and pray with you."
)

class ChatRequest(BaseModel):
    message: str
    mood: str = "Neutral"
    history: list[dict] = []
    language: str = "English"

class ChatResponse(BaseModel):
    response: str
    crisis_triggered: bool
    sources: list
    sermon_recommendation: dict | None = None
    handoff_required: bool = False
    transcript: str | None = None

def is_crisis_detected(text: str) -> bool:
    clean_text = text.lower()
    return any(keyword in clean_text for keyword in CRISIS_KEYWORDS)

def chunk_text(text, max_chars=1200, overlap=200):
    chunks = []
    start = 0
    while start < len(text):
        end = start + max_chars
        chunks.append(text[start:end])
        start += (max_chars - overlap)
    return chunks

def extract_text_from_file_bytes(filename: str, file_bytes: bytes) -> str:
    ext = os.path.splitext(filename)[1].lower()
    if ext == '.txt':
        return file_bytes.decode('utf-8', errors='ignore')
    elif ext == '.pdf':
        pdf_file = io.BytesIO(file_bytes)
        reader = pypdf.PdfReader(pdf_file)
        text = ""
        for page in reader.pages:
            text += page.extract_text() or ""
        return text
    elif ext == '.docx':
        docx_file = io.BytesIO(file_bytes)
        doc = docx.Document(docx_file)
        text = ""
        for para in doc.paragraphs:
            text += para.text + "\n"
        return text
    else:
        raise ValueError(f"Unsupported file format: {ext}")

def get_recommended_sermon(query: str, mood: str) -> dict:
    """Matches keywords in user queries and current mood to suggest relevant sermons."""
    search_context = (query + " " + mood).lower()
    
    # Check explicitly for topic keywords
    if "anxious" in search_context or "anxiety" in search_context or "worry" in search_context or "fear" in search_context:
        return SERMONS_DB[0]
    elif "discouraged" in search_context or "sad" in search_context or "defeat" in search_context or "storm" in search_context:
        return SERMONS_DB[1]
    elif "lonely" in search_context or "alone" in search_context or "isolated" in search_context:
        return SERMONS_DB[2]
    elif "tired" in search_context or "weary" in search_context or "exhaust" in search_context or "rest" in search_context:
        return SERMONS_DB[3]
    elif "joy" in search_context or "happy" in search_context or "glad" in search_context:
        return SERMONS_DB[4]
        
    return None

async def perform_rag_pipeline(query: str, mood: str, history: list = None, language: str = "English") -> dict:
    # Check configurations first
    if not client or index is None:
        return {
            "response": (
                f"Peace be with you. (Mood sensed: {mood}). "
                "\"Fear not, for I am with you; be not dismayed, for I am your God.\" — Isaiah 41:10\n\n"
                "Please ensure the backend server is running."
            ),
            "sources": [],
            "handoff_required": False
        }

    # Fast-path for simple conversational greetings: skip embedding & vector search
    clean_q = query.strip().lower().rstrip("!.? ")
    is_simple_greeting = clean_q in [
        "hi", "hello", "hey", "good morning", "good afternoon", "good evening",
        "how are you", "greetings", "hi there", "hello there", "peace", "praise god", "amen", "good day", "yoetz"
    ]

    contexts = []
    sources = []
    if is_simple_greeting:
        unified_context = "The user is saying a brief, friendly greeting. Greet them warmly and pastorally, ask how their day or walk of faith is going, and gently invite them to share whatever is on their heart. Keep it natural, welcoming, and concise (1 to 3 sentences)."
    else:
        try:
            # 1. Embed query using Gemini
            query_vector = embed_content_with_fallback(query, task_type="RETRIEVAL_QUERY")
        except Exception as e:
            print(f"ERROR: Embedding failed: {e}")
            query_vector = None
        
        query_results = {}
        if query_vector is not None and index is not None:
            try:
                # 2. Query Pinecone vector DB
                query_results = index.query(
                    vector=query_vector,
                    top_k=3,
                    include_metadata=True
                )
            except Exception as e:
                print(f"ERROR: Pinecone query failed: {e}")
                query_results = {}
        
        # 3. Compile context & sources
        matches = query_results.get("matches", [])
        highest_score = max([m.get("score", 0) for m in matches], default=0)
        
        for match in matches:
            metadata = match.get("metadata", {})
            text = metadata.get("text", "")
            title = metadata.get("title", "Unknown Teaching")
            if match.get("score", 0) > 0.1:
                contexts.append(f"Source: {title}\nTeaching: {text}")
                sources.append({"title": title, "score": match.get("score")})
            
        if not contexts or highest_score < 0.2:
            unified_context = "No specific teachings found for this exact query. Rely on general pastoral wisdom, be highly interactive, and keep the conversation flowing naturally."
        else:
            unified_context = "\n\n---\n\n".join(contexts)
    
    # Define mood-based counseling adjustments
    mood_directives = {
        "Anxious": "The user is currently feeling anxious or worried. Emphasize God's peace, stillness, sovereignty, and comfort. Remind them of scriptures like Philippians 4:6-7.",
        "Discouraged": "The user is feeling discouraged or defeated. Speak words of hope, strength, perseverance, and encouragement. Remind them of Joshua 1:9.",
        "Lonely": "The user is feeling lonely or isolated. Emphasize God's presence, fellowship, the comfort of the Holy Spirit, and the church community. Remind them of Hebrews 13:5.",
        "Tired": "The user is feeling tired, weary, or burnt out. Speak gently about rest, refreshing, and casting burdens on Christ. Remind them of Matthew 11:28-30.",
        "Joyful": "The user is feeling joyful and praiseful. Celebrate with them, encourage thanksgiving, and direct their joy to glorify God. Remind them of Psalm 100.",
        "Prayerful": "The user is in a prayerful state. Help guide them into deep reflection, alignment with God's word, and prayer models. Remind them of 1 Thessalonians 5:17."
    }
    mood_directive = mood_directives.get(mood, "Speak with empathy, grace, and biblical accuracy.")

    # Define language directives
    lang_directives = {
        "Pidgin": " CRITICAL LANGUAGE INSTRUCTION: The user selected Nigerian Pidgin English. Respond ENTIRELY in authentic, warm, and natural Nigerian Pidgin English (e.g., 'My pikin, make your heart no fail. God dey with you everywhere you step...'). Keep it deeply encouraging and pastoral.",
        "Igbo": " CRITICAL LANGUAGE INSTRUCTION: The user selected Igbo. Respond ENTIRELY in fluent, grammatically sound Igbo language (e.g., 'Nwa m, atụla egwu. Chineke nọ mma n'akụkụ gị oge niile...').",
        "Hausa": " CRITICAL LANGUAGE INSTRUCTION: The user selected Hausa. Respond ENTIRELY in fluent Hausa language (e.g., 'Ɗana, kada ka ji tsoro. Ubangiji yana tare da kai koyaushe...').",
        "Yoruba": " CRITICAL LANGUAGE INSTRUCTION: The user selected Yoruba. Respond ENTIRELY in fluent Yoruba language with proper diacritics (e.g., 'Ọmọ mi, má ṣe bẹ̀rù. Olúwa wà pẹ̀lú rẹ ni gbogbo ọ̀nà rẹ...').",
    }
    lang_directive = lang_directives.get(language, "")

    # Load YouTube Videos
    yt_videos = load_youtube_videos()
    yt_context = ""
    if yt_videos:
        yt_context = "\n\nAvailable Pastor YouTube Videos:\n"
        for v in yt_videos:
            yt_context += f"- Title: '{v['title']}' (ID: {v['id']})\n"
        yt_context += "\nIf the user's struggle perfectly matches a video topic, recommend it by appending exactly this markdown to your response: [YOUTUBE:id] (replace id with the video ID). Only recommend one video at most."

    # Load Podcasts
    podcasts = load_podcasts()
    podcast_context = ""
    if podcasts:
        podcast_context = "\n\nAvailable Audio Podcast Sermons:\n"
        for p in podcasts:
            podcast_context += f"- Title: '{p['title']}' (URL: {p['url']})\n"
        podcast_context += "\nIf the user's struggle perfectly matches an audio podcast topic, recommend it by appending exactly this markdown to your response: [AUDIO:url] (replace url with the exact URL). Only recommend one audio at most."

    # 4. Generate response using Gemini
    system_instruction = (
        "You are Imago, a highly interactive and compassionate virtual pastoral assistant for a Christian church. "
        "Be naturally conversational, just like ChatGPT or a real human companion. "
        "If the user says a simple greeting like 'hi' or 'hello', warmly welcome them back without forcing a deep theological lesson. "
        "When they share a struggle, weave the provided pastoral context naturally into your conversational response. "
        "Do not invent doctrines. "
        "Always complete your thoughts, scriptures, and counsel fully with a warm closing blessing. Never cut off or leave sentences incomplete. "
        f"{mood_directive} "
        f"{lang_directive} "
        f"{yt_context} "
        f"{podcast_context}"
    )

    # Build history for the Gemini contents list
    contents = []
    for h in (history or []):
        role = h.get("role", "user")
        parts = h.get("parts", [])
        if parts:
            first_part = parts[0]
            text_part = first_part.get("text", "") if isinstance(first_part, dict) else str(first_part)
        else:
            text_part = str(h.get("text", ""))
        contents.append(genai_types.Content(role=role, parts=[genai_types.Part(text=text_part)]))
    
    # Add current query
    full_prompt = f"PASTORAL CONTEXT:\n{unified_context}\n\nUSER QUESTION ({language}): {query}"
    contents.append(genai_types.Content(role="user", parts=[genai_types.Part(text=full_prompt)]))

    try:
        response = call_gemini_with_fallback(
            contents=contents,
            config=genai_types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.7,
                max_output_tokens=300 if is_simple_greeting else 1200,
            )
        )
        return {
            "response": response.text.strip(),
            "sources": sources,
            "handoff_required": False
        }
    except Exception as e:
        print(f"ERROR: Gemini generation failed: {e}")
        return {
            "response": (
                "I encountered a momentary difficulty reaching our AI systems. "
                "Please know that God is with you. "
                "\"I can do all things through Christ who strengthens me.\" — Philippians 4:13 "
                "Please try again in a moment."
            ),
            "sources": sources,
            "handoff_required": False
        }

@app.post("/api/chat", response_model=ChatResponse, tags=["Chat & AI"], summary="Send chat message to Pastoral AI")
async def chat_endpoint(request: ChatRequest):
    # Guardrail Check
    if is_crisis_detected(request.message):
        return ChatResponse(
            response=CRISIS_RESPONSE,
            crisis_triggered=True,
            sources=[],
            sermon_recommendation=None,
            handoff_required=True
        )
        
    try:
        result = await perform_rag_pipeline(request.message, request.mood, request.history, request.language)
        sermon_rec = get_recommended_sermon(request.message, request.mood)
        return ChatResponse(
            response=result["response"],
            crisis_triggered=False,
            sources=result["sources"],
            sermon_recommendation=sermon_rec,
            handoff_required=result.get("handoff_required", False)
        )
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

class BibleTranslateRequest(BaseModel):
    book: str
    chapter: int
    language: str
    verses: list[dict]

BIBLE_CACHE_FILE = DATA_DIR / "bible_translations_cache.json"

def load_bible_cache() -> dict:
    if firestore_db:
        try:
            doc = firestore_db.collection("imago_meta").document("bible_cache").get()
            if doc.exists:
                return doc.to_dict().get("cache", {})
        except Exception:
            pass
    if not BIBLE_CACHE_FILE.exists():
        return {}
    try:
        with open(BIBLE_CACHE_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def save_bible_cache(cache: dict):
    if firestore_db:
        try:
            firestore_db.collection("imago_meta").document("bible_cache").set({"cache": cache}, merge=True)
        except Exception:
            pass
    try:
        with open(BIBLE_CACHE_FILE, "w") as f:
            json.dump(cache, f, indent=2)
    except Exception:
        pass

@app.post("/api/bible/translate", tags=["Bible & Translations"], summary="Translate Bible passage into target language")
async def translate_bible_chapter(body: BibleTranslateRequest):
    cache_key = f"{body.language}_{body.book}_{body.chapter}"
    cache = load_bible_cache()
    if cache_key in cache:
        return {"status": "success", "verses": cache[cache_key]}
    
    if not client:
        return {"status": "fallback", "verses": body.verses}
        
    prompt = (
        f"You are an expert biblical scholar and translator. Translate the following verses of {body.book} Chapter {body.chapter} "
        f"into {body.language}.\n"
        f"Language rules:\n"
        f"- If The Living Bible: Paraphrase accurately into the classic, easy-to-understand, dynamic paraphrase style of Kenneth N. Taylor's The Living Bible (TLB).\n"
        f"- If Pidgin: Use authentic, natural, respectful Nigerian Pidgin English (e.g., 'For God so love the world say...').\n"
        f"- If Igbo: Use standard, grammatically sound Igbo (Baịbụl Nsọ style).\n"
        f"- If Hausa: Use clear Hausa (Littafi Mai Tsarki style).\n"
        f"- If Yoruba: Use standard Yoruba with proper diacritics (Bíbélì Mímọ́ style).\n\n"
        f"Input Verses:\n" + json.dumps(body.verses, indent=2) + "\n\n"
        f"Return ONLY a JSON array of objects with keys 'verse' (int) and 'text' (string). Do not add markdown formatting or extra text."
    )
    try:
        response = call_gemini_with_fallback(
            contents=prompt,
            config=genai_types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.3
            )
        )
        translated_verses = json.loads(response.text.strip())
        cache[cache_key] = translated_verses
        save_bible_cache(cache)
        return {"status": "success", "verses": translated_verses}
    except Exception as e:
        print(f"ERROR: Bible translation failed: {e}")
        return {"status": "fallback", "verses": body.verses}

# ─────────────────────────────────────────────────────────────────────────────
# PROJECTOR LIVE LISTENER — Transcription Endpoint
# Lean, purpose-built endpoint for the Scripture Projector's audio listener.
# Unlike /api/chat/audio, this ONLY transcribes and returns the raw text.
# No AI counseling pipeline, no history, no mood — just fast Gemini transcription
# optimized for rapid 6-second audio chunk cycles in a live sanctuary setting.
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/api/projector/transcribe", tags=["Scripture Projector"], summary="Transcribe projector audio chunk for live scripture detection")
async def projector_transcribe_endpoint(file: UploadFile = File(...)):
    if not GEMINI_API_KEY and not GROQ_API_KEY:
        raise HTTPException(status_code=503, detail="Transcription service is not configured.")

    try:
        audio_bytes = await file.read()
        if len(audio_bytes) < 1000:
            return {"transcript": "", "message": "Audio chunk too short."}

        mime = file.content_type
        if not mime or mime == "application/octet-stream":
            mime = "audio/mp4"  # Flutter record package outputs m4a

        transcript = transcribe_audio_bytes(audio_bytes, mime)
        return {"transcript": transcript}

    except Exception as e:
        print(f"ERROR: Projector transcription failed: {e}")
        # Return empty transcript on error rather than raising — the client
        # will simply skip this chunk and retry on the next cycle.
        return {"transcript": "", "error": str(e)}

@app.post("/api/chat/audio", response_model=ChatResponse, tags=["Chat & AI"], summary="Send voice/audio message for AI response")
async def chat_audio_endpoint(
    file: UploadFile = File(...), 
    mood: str = Form("Neutral"),
    history: str = Form("[]")
):
    if not GEMINI_API_KEY and not GROQ_API_KEY:
        raise HTTPException(status_code=503, detail="AI service is not configured.")

    try:
        audio_bytes = await file.read()
        # Handle Flutter's default 'application/octet-stream' fallback
        mime = file.content_type
        if not mime or mime == "application/octet-stream":
            mime = "audio/mp4"  # m4a format

        transcript = transcribe_audio_bytes(audio_bytes, mime)
        if not transcript:
            raise ValueError("Audio transcription returned empty result.")

        # Guardrail Check
        if is_crisis_detected(transcript):
            return ChatResponse(
                response=CRISIS_RESPONSE,
                crisis_triggered=True,
                sources=[],
                sermon_recommendation=None,
                handoff_required=True
            )

        # Proceed with normal RAG
        try:
            history_list = json.loads(history)
        except Exception:
            history_list = []
            
        result = await perform_rag_pipeline(transcript, mood, history_list)
        sermon_rec = get_recommended_sermon(transcript, mood)

        return ChatResponse(
            response=result["response"],
            crisis_triggered=False,
            sources=result["sources"],
            sermon_recommendation=sermon_rec,
            handoff_required=result.get("handoff_required", False),
            transcript=transcript
        )
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

class NaturalTtsRequest(BaseModel):
    text: str
    voice: Optional[str] = "en-US-ChristopherNeural"
    rate: Optional[str] = "+0%"
    pitch: Optional[str] = "+0Hz"

@app.post("/api/tts/natural", tags=["TTS & Audio"], summary="Generate studio-quality natural neural speech MP3")
async def natural_tts_endpoint(body: NaturalTtsRequest):
    clean_text = body.text.strip()
    if not clean_text:
        raise HTTPException(status_code=400, detail="Text cannot be empty.")
    try:
        voice = body.voice or "en-US-ChristopherNeural"
        rate = body.rate or "+0%"
        pitch = body.pitch or "+0Hz"
        communicate = edge_tts.Communicate(clean_text, voice, rate=rate, pitch=pitch)
        chunks = []
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                chunks.append(chunk["data"])
        audio_bytes = b"".join(chunks)
        return Response(content=audio_bytes, media_type="audio/mpeg")
    except Exception as e:
        print(f"ERROR: Natural TTS failed: {e}")
        raise HTTPException(status_code=500, detail=f"TTS generation failed: {str(e)}")

@app.get("/api/tts/stream", tags=["TTS & Audio"], summary="Stream studio-quality natural neural speech MP3")
async def natural_tts_stream_endpoint(text: str, voice: Optional[str] = "en-US-ChristopherNeural"):
    clean_text = text.strip()
    if not clean_text:
        raise HTTPException(status_code=400, detail="Text cannot be empty.")
    try:
        communicate = edge_tts.Communicate(clean_text, voice)
        chunks = []
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                chunks.append(chunk["data"])
        audio_bytes = b"".join(chunks)
        return Response(content=audio_bytes, media_type="audio/mpeg")
    except Exception as e:
        print(f"ERROR: Natural TTS streaming failed: {e}")
        raise HTTPException(status_code=500, detail=f"TTS streaming failed: {str(e)}")

from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict, List
import asyncio

class ConnectionManager:
    def __init__(self):
        self.active_users: Dict[str, WebSocket] = {}
        self.active_admins: List[WebSocket] = []

    async def connect_user(self, client_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_users[client_id] = websocket
        await self.broadcast_to_admins({"type": "user_connected", "client_id": client_id})

    def disconnect_user(self, client_id: str):
        if client_id in self.active_users:
            del self.active_users[client_id]
        asyncio.create_task(self.broadcast_to_admins({"type": "user_disconnected", "client_id": client_id}))

    async def connect_admin(self, websocket: WebSocket):
        await websocket.accept()
        self.active_admins.append(websocket)
        await websocket.send_json({"type": "active_users", "users": list(self.active_users.keys())})

    def disconnect_admin(self, websocket: WebSocket):
        if websocket in self.active_admins:
            self.active_admins.remove(websocket)

    async def send_to_user(self, client_id: str, message: str):
        if client_id in self.active_users:
            await self.active_users[client_id].send_json({"type": "message", "sender": "counselor", "text": message})

    async def broadcast_to_admins(self, data: dict):
        for admin in self.active_admins:
            try:
                await admin.send_json(data)
            except Exception:
                pass

manager = ConnectionManager()

@app.websocket("/api/chat/ws/{client_id}")
async def websocket_user_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect_user(client_id, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.broadcast_to_admins({
                "type": "message",
                "client_id": client_id,
                "text": data
            })
    except WebSocketDisconnect:
        manager.disconnect_user(client_id)

@app.websocket("/api/admin/ws")
async def websocket_admin_endpoint(websocket: WebSocket):
    await manager.connect_admin(websocket)
    try:
        while True:
            data = await websocket.receive_json()
            client_id = data.get("client_id")
            text = data.get("text")
            if client_id and text:
                await manager.send_to_user(client_id, text)
    except WebSocketDisconnect:
        manager.disconnect_admin(websocket)

@app.post("/api/webhook/whatsapp", tags=["System"], summary="Twilio WhatsApp incoming webhook")
async def whatsapp_webhook(Body: str = Form(...), From: str = Form(...)):
    """Twilio WhatsApp webhook endpoint."""
    # Guardrail Check
    if is_crisis_detected(Body):
        reply = CRISIS_RESPONSE
    else:
        try:
            result = perform_rag_pipeline(Body, "Neutral")
            reply = result["response"]
        except Exception as e:
            reply = "I apologize, beloved. I encountered a difficulty processing your request. Please try again later."
            
    # Compile TwiML Response
    twiml_response = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Message>{reply}</Message>
</Response>"""

    return Response(content=twiml_response, media_type="application/xml")

@app.post("/api/sermons/upload", tags=["Sermons & RAG"], summary="Upload sermon document (PDF, DOCX, TXT) to Pinecone")
async def upload_sermon_endpoint(file: UploadFile = File(...)):
    """Admin upload endpoint supporting PDF, Word, and TXT files for dynamic vector injection."""
    if not GEMINI_API_KEY or index is None:
        raise HTTPException(
            status_code=503, 
            detail="Vector ingestion service is offline. Please configure GEMINI_API_KEY and PINECONE_API_KEY."
        )

    filename = file.filename
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ['.txt', '.pdf', '.docx', '.mp3', '.wav', '.m4a']:
        raise HTTPException(status_code=400, detail="Only .txt, .pdf, .docx, .mp3, .wav, and .m4a files are supported.")
        
    try:
        file_bytes = await file.read()
        if ext in ['.mp3', '.wav', '.m4a']:
            # Audio sermon text notes representation
            content = f"Audio Sermon Document: {filename}\nTopic: Pastoral Audio Teaching\nContent: Audio sermon uploaded to Imago ministry repository for spiritual counseling."
        else:
            content = extract_text_from_file_bytes(filename, file_bytes)
        
        if not content.strip():
            raise HTTPException(status_code=400, detail="Uploaded file content is empty.")
            
        title = filename.split('.')[0].replace("_", " ").title()
        chunks = chunk_text(content)
        vectors_to_upsert = []
        
        for idx, chunk in enumerate(chunks):
            chunk_id = f"{filename}_{idx}"
            
            # Embed with Gemini
            embedding = embed_content_with_fallback(chunk, task_type="RETRIEVAL_DOCUMENT")
            
            vectors_to_upsert.append({
                "id": chunk_id,
                "values": embedding,
                "metadata": {
                    "title": title,
                    "text": chunk
                }
            })
            
        # Bulk upsert to Pinecone
        batch_size = 100
        for i in range(0, len(vectors_to_upsert), batch_size):
            batch = vectors_to_upsert[i : i + batch_size]
            index.upsert(vectors=batch)
            
        docs = load_documents()
        docs = [d for d in docs if d['filename'] != filename] # Replace if exists
        docs.append({
            "filename": filename,
            "title": title,
            "num_chunks": len(chunks),
            "upload_date": datetime.datetime.now().isoformat()
        })
        save_documents(docs)
            
        return {
            "status": "success",
            "message": f"Successfully parsed '{title}', split into {len(chunks)} chunks, and indexed in Pinecone."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/sermons", tags=["Sermons & RAG"], summary="List all indexed sermon documents")
async def list_sermons_endpoint():
    """Returns the list of tracked uploaded documents."""
    return {"documents": load_documents()}

@app.delete("/api/sermons/{filename}", tags=["Sermons & RAG"], summary="Delete sermon document from index and storage")
async def delete_sermon_endpoint(filename: str):
    if index is None:
        raise HTTPException(status_code=503, detail="Pinecone is not configured.")
        
    docs = load_documents()
    doc_to_delete = next((d for d in docs if d["filename"] == filename), None)
    
    if not doc_to_delete:
        raise HTTPException(status_code=404, detail="Document not found in local tracking.")
        
    num_chunks = doc_to_delete.get("num_chunks", 0)
    if num_chunks > 0:
        ids_to_delete = [f"{filename}_{i}" for i in range(num_chunks)]
        batch_size = 1000
        for i in range(0, len(ids_to_delete), batch_size):
            batch = ids_to_delete[i:i+batch_size]
            try:
                index.delete(ids=batch)
            except Exception as e:
                print(f"Warning: Failed to delete chunk batch from Pinecone: {e}")
                
    docs = [d for d in docs if d["filename"] != filename]
    save_documents(docs)
    
    return {"status": "success", "message": f"Successfully deleted '{filename}'."}


class PrayerRequest(BaseModel):
    request: str

@app.get("/health", tags=["System"], summary="Health check endpoint for load balancers & monitoring")
async def health_check():
    """Health check endpoint for Load Balancers, monitoring, and zero-downtime rolling deploys."""
    db_health = await check_db_health()
    return {
        "status": "ok",
        "service": "imago-api",
        "version": "1.0.0",
        "timestamp": datetime.datetime.now().isoformat(),
        "database": db_health,
    }

class PrayerResponse(BaseModel):
    prayer: str

@app.post("/api/prayer", response_model=PrayerResponse, tags=["Prayer & Community"], summary="Generate personalized pastoral prayer")
async def prayer_endpoint(body: PrayerRequest):
    """Generates an intercessory prayer response using the RAG pipeline with a Prayer-specific system prompt."""
    if is_crisis_detected(body.request):
        return PrayerResponse(prayer=CRISIS_RESPONSE)

    if not GEMINI_API_KEY or index is None:
        # Offline fallback prayer
        offline_prayer = (
            f"Heavenly Father,\n\nWe come before you in the name of Jesus, lifting up this prayer concerning: \"{body.request}\".\n\n"
            "Lord, we trust in your faithfulness. Grant wisdom, peace, and strength according to your perfect will.\n\n"
            "May your presence be felt in this moment. Let your peace, which surpasses all understanding, "
            "guard this heart and mind in Christ Jesus. (Philippians 4:7)\n\nIn Jesus' Name,\n\nAmen. 🙏"
        )
        return PrayerResponse(prayer=offline_prayer)

    try:
        # Embed the prayer request and retrieve related teachings
        query_vector = embed_content_with_fallback(body.request, task_type="RETRIEVAL_QUERY")

        query_results = index.query(
            vector=query_vector,
            top_k=2,
            include_metadata=True
        )

        contexts = []
        for match in query_results.get("matches", []):
            metadata = match.get("metadata", {})
            text = metadata.get("text", "")
            title = metadata.get("title", "")
            contexts.append(f"Source: {title}\n{text}")

        unified_context = "\n\n---\n\n".join(contexts) if contexts else "Lead a general biblical prayer."

        prayer_system_instruction = (
            "You are a pastoral prayer leader for a Christian church. "
            "Using the provided biblical context, compose a warm, sincere, scripture-referenced intercessory prayer "
            "on behalf of the believer. The prayer must include: an address to God the Father, acknowledgement of scripture, "
            "intercession for the user's specific concern, declaration of faith, and a closing Amen. "
            "Write in first-person plural (we/us). Do not exceed 300 words. Be empathetic, biblical, and reverent."
        )

        prompt = f"BIBLICAL CONTEXT:\n{unified_context}\n\nPRAYER REQUEST: {body.request}"
        
        response = call_gemini_with_fallback(
            contents=prompt,
            config=genai_types.GenerateContentConfig(
                system_instruction=prayer_system_instruction,
                temperature=0.8,
                max_output_tokens=1024,
            )
        )

        # Log the prayer topic anonymously
        analytics = load_analytics()
        analytics.setdefault("prayers", []).append({
            "topic": body.request,
            "timestamp": datetime.datetime.now().isoformat()
        })
        save_analytics(analytics)

        return PrayerResponse(prayer=response.text.strip())

    except Exception as e:
        import traceback
        traceback.print_exc()
        # Graceful fallback prayer
        fallback_prayer = (
            f"Heavenly Father,\n\nWe come before You in Jesus' name, lifting up this request: \"{body.request}\".\n\n"
            "Lord, You are faithful and Your word declares that You hear us when we call upon You. "
            "Grant wisdom, peace, and provision according to Your perfect will.\n\n"
            "May Your peace, which surpasses all understanding, guard this heart and mind in Christ Jesus. (Philippians 4:7)\n\n"
            "In Jesus' Name, Amen. 🙏"
        )
        return PrayerResponse(prayer=fallback_prayer)


class CommunityPrayerRequest(BaseModel):
    request: str
    is_anonymous: bool = True
    author_name: Optional[str] = "Anonymous"
    uid: Optional[str] = None

@app.post("/api/community-prayer", tags=["Prayer & Community"], summary="Post public community prayer request")
async def post_community_prayer(body: CommunityPrayerRequest):
    import uuid
    prayers = load_community_prayers()
    item_id = str(uuid.uuid4())[:8]
    item = {
        "id": item_id,
        "request": body.request,
        "is_anonymous": body.is_anonymous,
        "author_name": "Anonymous" if body.is_anonymous else (body.author_name or "Believer"),
        "uid": None if body.is_anonymous else body.uid,
        "prayed_count": 0,
        "created_at": datetime.datetime.now().isoformat()
    }
    prayers.insert(0, item)
    save_community_prayers(prayers)
    
    analytics = load_analytics()
    analytics.setdefault("prayers", []).append({
        "topic": body.request,
        "timestamp": datetime.datetime.now().isoformat()
    })
    save_analytics(analytics)
    
    return {"status": "success", "prayer": item}

@app.get("/api/community-prayer", tags=["Prayer & Community"], summary="Get recent community prayer requests")
async def get_community_prayers(limit: int = 50):
    prayers = load_community_prayers()
    return {"prayers": prayers[:limit]}

@app.post("/api/community-prayer/{prayer_id}/pray", tags=["Prayer & Community"], summary="Increment prayer count for a community prayer")
async def pray_for_community_item(prayer_id: str):
    prayers = load_community_prayers()
    found = False
    new_count = 0
    for p in prayers:
        if p.get("id") == prayer_id:
            p["prayed_count"] = p.get("prayed_count", 0) + 1
            new_count = p["prayed_count"]
            found = True
            break
    if not found:
        raise HTTPException(status_code=404, detail="Prayer request not found")
    save_community_prayers(prayers)
    return {"status": "success", "id": prayer_id, "prayed_count": new_count}


DEVOTIONAL_CACHE_FILE = DATA_DIR / "devotional_cache.json"

DAILY_VERSES = [
    {
        "verse": "Jeremiah 29:11",
        "text": "\"For I know the plans I have for you,\" declares the Lord, \"plans to prosper you and not to harm you, plans to give you hope and a future.\"",
        "theme": "Purpose & Hope"
    },
    {
        "verse": "Philippians 4:6-7",
        "text": "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.",
        "theme": "Unshakable Peace"
    },
    {
        "verse": "Isaiah 41:10",
        "text": "Fear not, for I am with you; be not dismayed, for I am your God. I will strengthen you, yes, I will help you, I will uphold you with My righteous right hand.",
        "theme": "Divine Strength"
    },
    {
        "verse": "Proverbs 3:5-6",
        "text": "Trust in the Lord with all your heart, and lean not on your own understanding; in all your ways acknowledge Him, and He shall direct your paths.",
        "theme": "Trust & Direction"
    },
    {
        "verse": "Romans 8:28",
        "text": "And we know that all things work together for good to those who love God, to those who are the called according to His purpose.",
        "theme": "Providence & Grace"
    },
    {
        "verse": "Psalm 46:10",
        "text": "Be still, and know that I am God; I will be exalted among the nations, I will be exalted in the earth!",
        "theme": "Stillness & Faith"
    },
    {
        "verse": "2 Corinthians 12:9",
        "text": "My grace is sufficient for you, for My strength is made perfect in weakness.",
        "theme": "Sufficient Grace"
    }
]

def load_devotional_cache() -> dict:
    if firestore_db:
        try:
            doc = firestore_db.collection("imago_meta").document("devotional_cache").get()
            if doc.exists:
                return doc.to_dict()
        except Exception as e:
            print(f"Warning: Firestore load devotional error: {e}")
    if not DEVOTIONAL_CACHE_FILE.exists():
        return {}
    try:
        with open(DEVOTIONAL_CACHE_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def save_devotional_cache(data: dict):
    if firestore_db:
        try:
            firestore_db.collection("imago_meta").document("devotional_cache").set(data, merge=True)
        except Exception as e:
            print(f"Warning: Firestore save devotional error: {e}")
    try:
        with open(DEVOTIONAL_CACHE_FILE, "w") as f:
            json.dump(data, f, indent=4)
    except Exception:
        pass

@app.get("/api/devotional/today", tags=["Devotionals"], summary="Get today's daily devotional guide")
async def get_today_devotional():
    today_str = datetime.date.today().isoformat()
    cache = load_devotional_cache()
    
    if today_str in cache:
        return cache[today_str]
        
    day_of_year = datetime.date.today().timetuple().tm_yday
    v_info = DAILY_VERSES[day_of_year % len(DAILY_VERSES)]
    
    reflection = f"Beloved, today God reminds you through {v_info['verse']} that His eye is upon you. Walk with confidence knowing that His presence goes before you."
    action_step = f"Take 60 seconds today to meditate on {v_info['verse']} and thank God for His faithfulness."
    
    if GEMINI_API_KEY:
        try:
            prompt = (
                f"Create a short 2-paragraph pastoral daily devotional reflection and a 1-sentence practical daily action step for this scripture:\n"
                f"Scripture: {v_info['verse']} - {v_info['text']}\nTheme: {v_info['theme']}\n\n"
                f"Write in a warm, encouraging pastoral tone. Output JSON format strictly with keys 'reflection' and 'action_step'."
            )
            response = call_gemini_with_fallback(
                contents=prompt,
                config=genai_types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.7,
                )
            )
            data = json.loads(response.text)
            reflection = data.get("reflection", reflection)
            action_step = data.get("action_step", action_step)
        except Exception as e:
            print(f"AI Devotional Generation fallback: {e}")

    result = {
        "date": today_str,
        "verse": v_info["verse"],
        "text": v_info["text"],
        "theme": v_info["theme"],
        "reflection": reflection,
        "action_step": action_step
    }
    
    cache[today_str] = result
    save_devotional_cache(cache)
    return result




class YouTubeRequest(BaseModel):
    channel_url: str

@app.post("/api/admin/youtube", tags=["Admin & Ingestion"], summary="Ingest sermon transcript from YouTube channel URL")
async def sync_youtube_channel(body: YouTubeRequest):
    import yt_dlp
    
    url = body.channel_url
    # Force /videos tab for channel URLs to prevent downloading nested playlists
    if "@" in url and not url.endswith("/videos") and not url.endswith("/shorts") and not url.endswith("/streams"):
        url = url.rstrip("/") + "/videos"
        
    ydl_opts = {
        'extract_flat': 'in_playlist',
        'quiet': True,
        'playlist_items': '1-20', # Get top 20 latest to keep context size manageable
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            entries = info.get('entries', [])
            videos = []
            for entry in entries:
                if entry.get('id') and entry.get('title'):
                    videos.append({
                        "id": entry['id'],
                        "title": entry['title'],
                        "url": entry.get('url', f"https://www.youtube.com/watch?v={entry['id']}")
                    })
            save_youtube_videos(videos)
            return {"status": "success", "message": f"Successfully synced {len(videos)} videos.", "videos": videos}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class PodcastRequest(BaseModel):
    rss_url: str

@app.post("/api/admin/podcast", tags=["Admin & Ingestion"], summary="Ingest sermon podcasts from RSS feed")
async def sync_podcast_feed(body: PodcastRequest):
    import feedparser
    try:
        feed = feedparser.parse(body.rss_url)
        if feed.bozo:
            raise Exception("Invalid RSS feed")
            
        podcasts = []
        for entry in feed.entries[:20]: # Get top 20 latest
            audio_url = None
            # Find the audio enclosure
            for link in entry.get('links', []):
                if link.get('type', '').startswith('audio/') or link.get('href', '').endswith('.mp3'):
                    audio_url = link.get('href')
                    break
            
            if audio_url and entry.get('title'):
                podcasts.append({
                    "id": audio_url, # using url as id for audio since it's direct
                    "title": entry['title'],
                    "url": audio_url
                })
                
        save_podcasts(podcasts)
        return {"status": "success", "message": f"Successfully synced {len(podcasts)} audio podcasts.", "podcasts": podcasts}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class MoodRequest(BaseModel):
    mood: str
    intensity: float

@app.post("/api/analytics/mood", tags=["Feedback & Analytics"], summary="Log user spiritual mood / emotional state")
async def log_mood(body: MoodRequest):
    analytics = load_analytics()
    analytics.setdefault("moods", []).append({
        "mood": body.mood,
        "intensity": body.intensity,
        "timestamp": datetime.datetime.now().isoformat()
    })
    save_analytics(analytics)
    return {"status": "success"}

@app.get("/api/admin/analytics", tags=["Admin & Ingestion"], summary="Get admin dashboard analytics and metrics")
async def get_analytics():
    analytics = load_analytics()
    moods = analytics.get("moods", [])
    prayers = analytics.get("prayers", [])
    
    # Fallback sample data if empty for instant rich admin dashboard preview
    if not moods and not prayers:
        mood_counts = {
            "Anxious": 42,
            "Prayerful": 38,
            "Joyful": 27,
            "Discouraged": 19,
            "Tired": 15,
            "Lonely": 9
        }
        recent_prayers = [
            "Praying for peace in our family and guidance for career decisions.",
            "Healing for my mother who is undergoing surgery this week.",
            "Seeking direction and strength during a season of uncertainty.",
            "Financial wisdom and provision for home expenses.",
            "Overcoming anxiety and finding rest in God's promises."
        ]
        total_moods = 150
        total_prayers = 48
    else:
        mood_counts = {}
        for m in moods:
            mood_str = m.get("mood", "Unknown")
            mood_counts[mood_str] = mood_counts.get(mood_str, 0) + 1
        recent_prayers = [p.get("topic") for p in prayers[-10:]][::-1]
        total_moods = len(moods)
        total_prayers = len(prayers)
        
    return {
        "status": "success",
        "mood_counts": mood_counts,
        "recent_prayers": recent_prayers,
        "total_moods": total_moods,
        "total_prayers": total_prayers,
        "total_documents": len(load_documents())
    }

class FeedbackPayload(BaseModel):
    id: Optional[str] = None
    category: str
    category_label: Optional[str] = None
    rating: int
    message: str
    email: Optional[str] = None
    user_name: Optional[str] = None
    screen_context: Optional[str] = "general"
    platform: Optional[str] = "unknown"
    app_version: Optional[str] = "1.0.0"
    timestamp: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

@app.post("/api/feedback", tags=["Feedback & Analytics"], summary="Submit detailed user feedback")
async def receive_user_feedback(body: FeedbackPayload):
    feedback_list = load_feedback()
    item = body.dict()
    if not item.get("id"):
        item["id"] = f"fb_{int(datetime.datetime.now().timestamp() * 1000)}"
    if not item.get("timestamp"):
        item["timestamp"] = datetime.datetime.now().isoformat()
    
    feedback_list.insert(0, item)
    save_feedback(feedback_list)
    print(f"INFO: Received feedback [{body.category}] {body.rating} stars: {body.message[:40]}...")
    return {"status": "success", "id": item["id"]}

class MicroFeedbackPayload(BaseModel):
    id: Optional[str] = None
    context_id: str
    is_positive: bool
    screen_context: Optional[str] = "chat"
    note: Optional[str] = None
    timestamp: Optional[str] = None

@app.post("/api/feedback/micro", tags=["Feedback & Analytics"], summary="Submit micro-feedback survey response")
async def receive_micro_feedback(body: MicroFeedbackPayload):
    micro_list = load_micro_feedback()
    item = body.dict()
    if not item.get("id"):
        item["id"] = f"mfb_{int(datetime.datetime.now().timestamp() * 1000)}"
    if not item.get("timestamp"):
        item["timestamp"] = datetime.datetime.now().isoformat()
    micro_list.append(item)
    save_micro_feedback(micro_list)
    return {"status": "success"}

@app.get("/api/admin/feedback", tags=["Feedback & Analytics"], summary="Retrieve all submitted user feedback")
async def get_admin_feedback():
    feedback_list = load_feedback()
    micro_list = load_micro_feedback()
    
    # Calculate metrics
    total_count = len(feedback_list)
    if total_count > 0:
        avg_rating = round(sum(f.get("rating", 5) for f in feedback_list) / total_count, 1)
    else:
        avg_rating = 4.9

    category_counts = {}
    for f in feedback_list:
        cat = f.get("category", "general")
        category_counts[cat] = category_counts.get(cat, 0) + 1

    positive_micro = sum(1 for m in micro_list if m.get("is_positive", True))
    negative_micro = sum(1 for m in micro_list if not m.get("is_positive", True))

    return {
        "status": "success",
        "total_feedback": total_count,
        "average_rating": avg_rating,
        "category_counts": category_counts,
        "micro_positive": positive_micro,
        "micro_negative": negative_micro,
        "feedback_items": feedback_list[:50]
    }

# ─── PAYMENTS & PARTNERSHIP INTEGRATION ──────────────────────────────────────

class PaystackInitRequest(BaseModel):
    email: str
    amount: int # Amount in NGN (e.g. 5000)
    tier: Optional[str] = "Ministry Partner"
    frequency: Optional[str] = "monthly"
    user_id: Optional[str] = None
    callback_url: Optional[str] = "yoetz://payment-callback"

@app.post("/api/payments/paystack/initialize", tags=["Payments"], summary="Initialize a live Paystack partnership checkout")
async def initialize_paystack_payment(
    body: PaystackInitRequest,
    db: Optional[Any] = Depends(get_db_session)
):
    if not body.email or "@" not in body.email:
        raise HTTPException(status_code=400, detail="A valid contributor email is required.")
    if body.amount <= 0:
        raise HTTPException(status_code=400, detail="Partnership amount must be greater than zero.")

    reference = f"yoetz_{int(time.time())}_{uuid.uuid4().hex[:6]}"
    amount_kobo = body.amount * 100

    # Pending record
    tx_record = {
        "reference": reference,
        "email": body.email.strip(),
        "user_id": body.user_id,
        "amount": body.amount,
        "currency": "NGN",
        "tier": body.tier or "Ministry Partner",
        "frequency": body.frequency or "monthly",
        "status": "pending",
        "gateway": "paystack",
        "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "paid_at": None,
    }
    save_local_transaction(tx_record)

    if firestore_db:
        try:
            firestore_db.collection("payment_transactions").document(reference).set(tx_record, merge=True)
        except Exception as e:
            print(f"Warning: Firestore save pending tx error: {e}")

    if db and PaymentTransaction is not None:
        try:
            db_tx = PaymentTransaction(
                user_id=body.user_id,
                reference=reference,
                email=body.email.strip(),
                amount=amount_kobo,
                currency="NGN",
                partner_tier=body.tier or "Ministry Partner",
                frequency=body.frequency or "monthly",
                status="pending",
                gateway="paystack",
            )
            db.add(db_tx)
            await db.commit()
        except Exception as e:
            print(f"Warning: PostgreSQL save pending tx error: {e}")

    # If Paystack secret key is configured, initialize live transaction with Paystack API
    if PAYSTACK_SECRET_KEY:
        try:
            post_payload = json.dumps({
                "email": body.email.strip(),
                "amount": amount_kobo,
                "reference": reference,
                "callback_url": body.callback_url or "yoetz://payment-callback",
                "metadata": {
                    "user_id": body.user_id,
                    "tier": body.tier,
                    "frequency": body.frequency,
                    "app": "yo-ETS",
                }
            }).encode("utf-8")

            req = urllib.request.Request(
                "https://api.paystack.co/transaction/initialize",
                data=post_payload,
                headers={
                    "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
                    "Content-Type": "application/json",
                    "User-Agent": "yo-ETS-Backend/1.0"
                },
                method="POST"
            )

            with urllib.request.urlopen(req, timeout=15) as resp:
                resp_data = json.loads(resp.read().decode("utf-8"))
                if resp_data.get("status") is True and "data" in resp_data:
                    data = resp_data["data"]
                    return {
                        "status": "success",
                        "reference": reference,
                        "authorization_url": data.get("authorization_url", ""),
                        "access_code": data.get("access_code", ""),
                    }
                else:
                    raise HTTPException(
                        status_code=502,
                        detail=resp_data.get("message", "Paystack initialization failed.")
                    )
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8") if e.fp else str(e)
            print(f"ERROR: Paystack API HTTPError {e.code}: {err_body}")
            raise HTTPException(status_code=502, detail=f"Paystack error: {err_body}")
        except Exception as e:
            print(f"ERROR: Failed to contact Paystack API: {e}")
            raise HTTPException(status_code=502, detail=f"Payment gateway connection error: {str(e)}")

    # If secret key not yet configured in .env, guide the admin/client
    return {
        "status": "config_required",
        "reference": reference,
        "message": "PAYSTACK_SECRET_KEY is not set in backend environment. Configure keys in .env to initiate live sessions.",
        "authorization_url": ""
    }

@app.get("/api/payments/paystack/webhook", tags=["Payments"], summary="Webhook health probe and verification status")
async def paystack_webhook_probe():
    return {
        "status": "active",
        "service": "Paystack Webhook Listener",
        "configured": bool(PAYSTACK_SECRET_KEY),
        "message": "Endpoint is active and ready to receive POST events from Paystack."
    }

@app.post("/api/payments/paystack/webhook", tags=["Payments"], summary="Secure webhook handler for Paystack events")
async def paystack_webhook(
    request: Request,
    db: Optional[Any] = Depends(get_db_session),
    x_paystack_signature: Optional[str] = Header(None)
):
    body_bytes = await request.body()

    # Verify HMAC SHA512 signature when PAYSTACK_SECRET_KEY is present
    if PAYSTACK_SECRET_KEY:
        computed_sig = hmac.new(
            PAYSTACK_SECRET_KEY.encode("utf-8"),
            body_bytes,
            hashlib.sha512
        ).hexdigest()

        if not x_paystack_signature or not hmac.compare_digest(computed_sig, x_paystack_signature):
            print("WARNING: Rejected Paystack webhook with invalid signature")
            raise HTTPException(status_code=400, detail="Invalid webhook signature")

    try:
        payload = json.loads(body_bytes.decode("utf-8"))
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    event = payload.get("event")
    event_data = payload.get("data", {})

    if event == "charge.success":
        reference = event_data.get("reference")
        amount = (event_data.get("amount") or 0) // 100 # Convert kobo to NGN
        customer = event_data.get("customer") or {}
        email = customer.get("email", "").strip()
        metadata = event_data.get("metadata") or {}
        tier = metadata.get("tier", "Ministry Partner")
        user_id = metadata.get("user_id")

        now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()

        # Update local transaction
        tx_item = {
            "reference": reference,
            "email": email,
            "user_id": user_id,
            "amount": amount,
            "currency": event_data.get("currency", "NGN"),
            "tier": tier,
            "status": "success",
            "paid_at": now_iso,
            "channel": event_data.get("channel"),
            "gateway": "paystack",
        }
        save_local_transaction(tx_item)

        if firestore_db and reference:
            try:
                firestore_db.collection("payment_transactions").document(reference).set(tx_item, merge=True)
            except Exception as e:
                print(f"Warning: Firestore webhook tx save error: {e}")

        # Update PostgreSQL transaction
        if db and PaymentTransaction is not None and reference:
            try:
                from sqlalchemy import select
                stmt = select(PaymentTransaction).where(PaymentTransaction.reference == reference)
                res = await db.execute(stmt)
                db_tx = res.scalar_one_or_none()
                if db_tx:
                    db_tx.status = "success"
                    db_tx.paid_at = datetime.datetime.now(datetime.timezone.utc)
                    db_tx.channel = event_data.get("channel")
                    await db.commit()
            except Exception as e:
                print(f"Warning: PostgreSQL webhook tx update error: {e}")

        # Promote User's Partner Tier
        await upgrade_user_partner_tier(
            email=email,
            tier=tier,
            user_id=user_id,
            amount=amount,
            reference=reference,
            db_session=db
        )
        print(f"INFO: Successfully processed charge.success for {email} ({tier}, ₦{amount:,})")

    return {"status": "ok"}

@app.get("/api/payments/paystack/verify/{reference}", tags=["Payments"], summary="Verify transaction status via Paystack")
async def verify_paystack_transaction(
    reference: str,
    db: Optional[Any] = Depends(get_db_session)
):
    if not reference:
        raise HTTPException(status_code=400, detail="Transaction reference is required.")

    # If secret key is configured, query Paystack API directly
    if PAYSTACK_SECRET_KEY:
        try:
            req = urllib.request.Request(
                f"https://api.paystack.co/transaction/verify/{urllib.parse.quote(reference)}",
                headers={
                    "Authorization": f"Bearer {PAYSTACK_SECRET_KEY}",
                    "Content-Type": "application/json",
                    "User-Agent": "yo-ETS-Backend/1.0"
                },
                method="GET"
            )
            with urllib.request.urlopen(req, timeout=15) as resp:
                resp_data = json.loads(resp.read().decode("utf-8"))
                if resp_data.get("status") is True and "data" in resp_data:
                    data = resp_data["data"]
                    paystack_status = data.get("status") # "success", "failed", "abandoned"
                    amount = (data.get("amount") or 0) // 100
                    customer = data.get("customer") or {}
                    email = customer.get("email", "")
                    metadata = data.get("metadata") or {}
                    tier = metadata.get("tier", "Ministry Partner")
                    user_id = metadata.get("user_id")

                    if paystack_status == "success":
                        # Record success and promote
                        await upgrade_user_partner_tier(
                            email=email,
                            tier=tier,
                            user_id=user_id,
                            amount=amount,
                            reference=reference,
                            db_session=db
                        )

                    return {
                        "status": "success",
                        "payment_status": paystack_status,
                        "reference": reference,
                        "amount": amount,
                        "tier": tier,
                        "email": email,
                    }
        except Exception as e:
            print(f"Warning: Direct Paystack verify error: {e}")

    # Fallback to local / Firestore transaction record
    items = load_local_transactions()
    for item in items:
        if item.get("reference") == reference:
            return {
                "status": "success",
                "payment_status": item.get("status", "pending"),
                "reference": reference,
                "amount": item.get("amount", 0),
                "tier": item.get("tier", "Ministry Partner"),
                "email": item.get("email", ""),
            }

    return {
        "status": "not_found",
        "payment_status": "unknown",
        "reference": reference,
        "message": "Transaction not found."
    }

@app.get("/api/user/partner-tier", tags=["Payments"], summary="Fetch active partner status and tier for a user")
async def get_user_partner_tier(
    email: Optional[str] = None,
    user_id: Optional[str] = None
):
    tier = "Free"
    is_partner = False
    details = {}

    key = user_id or email
    if key:
        partners = load_local_partners()
        clean_key = key.lower().strip()
        if clean_key in partners:
            details = partners[clean_key]
            tier = details.get("partner_tier", "Free")
            is_partner = details.get("is_partner", False)

    if firestore_db and key and (not is_partner or tier == "Free"):
        try:
            doc = firestore_db.collection("users").document(key).get()
            if doc.exists:
                doc_data = doc.to_dict() or {}
                if doc_data.get("partner_tier") and doc_data.get("partner_tier") != "Free":
                    tier = doc_data.get("partner_tier")
                    is_partner = True
                    details = doc_data
        except Exception as e:
            print(f"Warning: Firestore partner query error: {e}")

    return {
        "status": "success",
        "email": email,
        "user_id": user_id,
        "partner_tier": tier,
        "is_partner": is_partner,
        "details": details
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
