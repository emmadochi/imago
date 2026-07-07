import os
import io
from fastapi import FastAPI, Form, HTTPException, Response, UploadFile, File
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

# Setup Data Directory for document tracking
DATA_DIR = Path("app/data")
DATA_DIR.mkdir(parents=True, exist_ok=True)
DOCS_FILE = DATA_DIR / "documents.json"
YOUTUBE_CACHE_FILE = DATA_DIR / "youtube_cache.json"

def load_documents() -> list:
    if not DOCS_FILE.exists():
        return []
    try:
        with open(DOCS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return []

def save_documents(docs: list):
    with open(DOCS_FILE, "w") as f:
        json.dump(docs, f, indent=4)

def load_youtube_videos() -> list:
    if not YOUTUBE_CACHE_FILE.exists():
        return []
    try:
        with open(YOUTUBE_CACHE_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return []

def save_youtube_videos(videos: list):
    with open(YOUTUBE_CACHE_FILE, "w") as f:
        json.dump(videos, f, indent=4)

# Load environment
load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
INDEX_NAME = os.getenv("PINECONE_INDEX_NAME", "pastoral-sermons")

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

index = None
if PINECONE_API_KEY:
    try:
        pc = Pinecone(api_key=PINECONE_API_KEY)
        index = pc.Index(INDEX_NAME)
    except Exception as e:
        print(f"WARNING: Pinecone connection error: {e}")
else:
    print("WARNING: PINECONE_API_KEY is not set in .env file.")

app = FastAPI(title="Pastoral AI Assistant API", version="1.0.0")

# Mount Admin Dashboard
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

async def perform_rag_pipeline(query: str, mood: str, history: list = None) -> dict:
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

    try:
        # 1. Embed query using Gemini
        embed_response = client.models.embed_content(
            model="gemini-embedding-2",
            contents=query,
            config=genai_types.EmbedContentConfig(task_type="RETRIEVAL_QUERY")
        )
        query_vector = embed_response.embeddings[0].values
    except Exception as e:
        print(f"ERROR: Embedding failed: {e}")
        return {
            "response": "I am having trouble searching our teaching library right now. Please try again in a moment.",
            "sources": [],
            "handoff_required": False
        }
    
    try:
        # 2. Query Pinecone vector DB
        query_results = index.query(
            vector=query_vector,
            top_k=3,
            include_metadata=True
        )
    except Exception as e:
        print(f"ERROR: Pinecone query failed: {e}")
        return {
            "response": "I am having trouble retrieving teachings right now. Please try again in a moment.",
            "sources": [],
            "handoff_required": False
        }
    
    # 3. Compile context & sources
    contexts = []
    sources = []
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

    # Load YouTube Videos
    yt_videos = load_youtube_videos()
    yt_context = ""
    if yt_videos:
        yt_context = "\n\nAvailable Pastor YouTube Videos:\n"
        for v in yt_videos:
            yt_context += f"- Title: '{v['title']}' (ID: {v['id']})\n"
        yt_context += "\nIf the user's struggle perfectly matches a video topic, recommend it by appending exactly this markdown to your response: [YOUTUBE:id] (replace id with the video ID). Only recommend one video at most."

    # 4. Generate response using Gemini
    system_instruction = (
        "You are Imago, a highly interactive and compassionate virtual pastoral assistant for a Christian church. "
        "Be naturally conversational, just like ChatGPT or a real human companion. "
        "If the user says a simple greeting like 'hi' or 'hello', warmly welcome them back (e.g., 'Hello, beloved! How can I support you today?') without forcing a deep theological lesson. "
        "When they share a struggle, weave the provided pastoral context naturally into your conversational response. "
        "Do not invent doctrines. "
        f"{mood_directive}"
        f"{yt_context}"
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
    full_prompt = f"PASTORAL CONTEXT:\n{unified_context}\n\nUSER QUESTION: {query}"
    contents.append(genai_types.Content(role="user", parts=[genai_types.Part(text=full_prompt)]))

    try:
        response = client.models.generate_content(
            model="gemini-3.5-flash",
            contents=contents,
            config=genai_types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.7,
                max_output_tokens=1024,
            )
        )
        return {
            "response": response.text.strip(),
            "sources": sources,
            "handoff_required": False
        }
    except Exception as e:
        print(f"ERROR: Gemini generation failed: {e}")
        # Graceful scripture fallback — never show a raw 500 to the user
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

@app.post("/api/chat", response_model=ChatResponse)
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
        result = await perform_rag_pipeline(request.message, request.mood, request.history)
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

@app.post("/api/chat/audio", response_model=ChatResponse)
async def chat_audio_endpoint(
    file: UploadFile = File(...), 
    mood: str = Form("Neutral"),
    history: str = Form("[]")
):
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=503, detail="Gemini API is not configured.")

    try:
        # Transcribe audio using Gemini
        audio_bytes = await file.read()
        # Handle Flutter's default 'application/octet-stream' fallback
        mime = file.content_type
        if not mime or mime == "application/octet-stream":
            mime = "audio/mp4"  # m4a format

        transcript = ""
        try:
            transcript_response = client.models.generate_content(
                model="gemini-3.5-flash",
                contents=[
                    genai_types.Part.from_bytes(data=audio_bytes, mime_type=mime),
                    "Transcribe this audio accurately. Only output the transcription, no additional text."
                ]
            )
            transcript = transcript_response.text.strip()
        except Exception as e:
            print(f"ERROR: Audio transcription failed: {e}")
            raise HTTPException(status_code=500, detail=f"Audio transcription failed: {str(e)}")

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

@app.post("/api/webhook/whatsapp")
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

@app.post("/api/sermons/upload")
async def upload_sermon_endpoint(file: UploadFile = File(...)):
    """Admin upload endpoint supporting PDF, Word, and TXT files for dynamic vector injection."""
    if not GEMINI_API_KEY or index is None:
        raise HTTPException(
            status_code=503, 
            detail="Vector ingestion service is offline. Please configure GEMINI_API_KEY and PINECONE_API_KEY."
        )

    filename = file.filename
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ['.txt', '.pdf', '.docx']:
        raise HTTPException(status_code=400, detail="Only .txt, .pdf, and .docx files are supported.")
        
    try:
        file_bytes = await file.read()
        content = extract_text_from_file_bytes(filename, file_bytes)
        
        if not content.strip():
            raise HTTPException(status_code=400, detail="Uploaded file content is empty.")
            
        title = filename.split('.')[0].replace("_", " ").title()
        chunks = chunk_text(content)
        vectors_to_upsert = []
        
        for idx, chunk in enumerate(chunks):
            chunk_id = f"{filename}_{idx}"
            
            # Embed with Gemini (new SDK)
            embed_response = client.models.embed_content(
                model="gemini-embedding-2",
                contents=chunk,
                config=genai_types.EmbedContentConfig(
                    task_type="RETRIEVAL_DOCUMENT",
                    title=title
                )
            )
            embedding = embed_response.embeddings[0].values
            
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

@app.get("/api/sermons")
async def list_sermons_endpoint():
    """Returns the list of tracked uploaded documents."""
    return {"documents": load_documents()}

@app.delete("/api/sermons/{filename}")
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

@app.get("/health")
async def health_check():
    """Health check endpoint for Render deployment."""
    return {"status": "ok", "timestamp": datetime.datetime.now().isoformat()}

class PrayerResponse(BaseModel):
    prayer: str

@app.post("/api/prayer", response_model=PrayerResponse)
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
        embed_response = client.models.embed_content(
            model="gemini-embedding-2",
            contents=body.request,
            config=genai_types.EmbedContentConfig(task_type="RETRIEVAL_QUERY")
        )
        query_vector = embed_response.embeddings[0].values

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
        
        response = client.models.generate_content(
            model="gemini-3.5-flash",
            contents=prompt,
            config=genai_types.GenerateContentConfig(
                system_instruction=prayer_system_instruction,
                temperature=0.8,
                max_output_tokens=512,
            )
        )

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


class YouTubeRequest(BaseModel):
    channel_url: str

@app.post("/api/admin/youtube")
async def sync_youtube_channel(body: YouTubeRequest):
    import yt_dlp
    ydl_opts = {
        'extract_flat': True,
        'quiet': True,
        'playlist_end': 20, # Get top 20 latest to keep context size manageable
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(body.channel_url, download=False)
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
