import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import { getAuth, signInWithEmailAndPassword, onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";

const firebaseConfig = {
    apiKey: "AIzaSyBIuZIVFYj5_9WPCDLeAjtrRxUs8LdnKfM",
    authDomain: "imago-bbd56.firebaseapp.com",
    projectId: "imago-bbd56",
    storageBucket: "imago-bbd56.firebasestorage.app"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

// DOM Elements
const loginContainer = document.getElementById('login-container');
const dashboardContainer = document.getElementById('dashboard-container');
const loginForm = document.getElementById('login-form');
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');
const loginError = document.getElementById('login-error');
const logoutBtn = document.getElementById('logout-btn');

const dropZone = document.getElementById('drop-zone');
const fileInput = document.getElementById('file-input');
const uploadStatus = document.getElementById('upload-status');

// Auth State Observer
onAuthStateChanged(auth, (user) => {
    if (user) {
        // User is signed in
        loginContainer.classList.add('hidden');
        dashboardContainer.classList.remove('hidden');
        fetchDocuments();
    } else {
        // User is signed out
        loginContainer.classList.remove('hidden');
        dashboardContainer.classList.add('hidden');
    }
});

// Login Handler
loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    loginError.textContent = '';
    
    const email = emailInput.value;
    const password = passwordInput.value;

    try {
        await signInWithEmailAndPassword(auth, email, password);
    } catch (error) {
        loginError.textContent = "Invalid credentials or unauthorized admin.";
        console.error(error);
    }
});

// Logout Handler
logoutBtn.addEventListener('click', () => {
    signOut(auth);
});

// File Upload Logic
dropZone.addEventListener('click', () => fileInput.click());

['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
    dropZone.addEventListener(eventName, preventDefaults, false);
});

function preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
}

['dragenter', 'dragover'].forEach(eventName => {
    dropZone.addEventListener(eventName, () => dropZone.classList.add('dragover'), false);
});

['dragleave', 'drop'].forEach(eventName => {
    dropZone.addEventListener(eventName, () => dropZone.classList.remove('dragover'), false);
});

dropZone.addEventListener('drop', (e) => {
    let dt = e.dataTransfer;
    let files = dt.files;
    handleFiles(files);
});

fileInput.addEventListener('change', function() {
    handleFiles(this.files);
});

async function handleFiles(files) {
    if (files.length === 0) return;
    
    const file = files[0];
    const validExtensions = ['.pdf', '.txt', '.docx'];
    const fileExtension = file.name.substring(file.name.lastIndexOf('.')).toLowerCase();
    
    if (!validExtensions.includes(fileExtension)) {
        uploadStatus.className = 'status-msg error';
        uploadStatus.textContent = 'Invalid file type. Only PDF, TXT, and DOCX are allowed.';
        return;
    }

    await uploadFile(file);
}

async function uploadFile(file) {
    uploadStatus.className = 'status-msg loading';
    uploadStatus.textContent = `Uploading and processing ${file.name}... This may take a minute.`;

    const formData = new FormData();
    formData.append('file', file);

    try {
        // Endpoint hosted on the same FastAPI server
        const response = await fetch('/api/sermons/upload', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (response.ok) {
            uploadStatus.className = 'status-msg success';
            uploadStatus.textContent = data.message || 'File uploaded and indexed successfully!';
            fetchDocuments();
        } else {
            uploadStatus.className = 'status-msg error';
            uploadStatus.textContent = `Error: ${data.detail || 'Upload failed'}`;
        }
    } catch (error) {
        uploadStatus.className = 'status-msg error';
        uploadStatus.textContent = 'Network error occurred while uploading.';
        console.error(error);
    }
}

// Document Management Logic
const documentList = document.getElementById('document-list');

async function fetchDocuments() {
    try {
        const res = await fetch('/api/sermons');
        const data = await res.json();
        
        if (!data.documents || data.documents.length === 0) {
            documentList.innerHTML = '<p style="color: rgba(255,255,255,0.5); font-size: 13px;">No documents uploaded yet.</p>';
            return;
        }
        
        documentList.innerHTML = '';
        data.documents.forEach(doc => {
            const item = document.createElement('div');
            item.className = 'document-item';
            
            const info = document.createElement('div');
            info.className = 'doc-info';
            info.innerHTML = `<strong>${doc.title}</strong><br/><small style="color: rgba(255,255,255,0.6);">${doc.filename} • ${doc.num_chunks} chunks</small>`;
            
            const delBtn = document.createElement('button');
            delBtn.className = 'icon-btn delete-btn';
            delBtn.innerHTML = '🗑️';
            delBtn.title = "Delete Document";
            delBtn.onclick = () => deleteDocument(doc.filename);
            
            item.appendChild(info);
            item.appendChild(delBtn);
            documentList.appendChild(item);
        });
        
    } catch (e) {
        console.error(e);
        documentList.innerHTML = '<p style="color: #ff5252; font-size: 13px;">Failed to load documents.</p>';
    }
}

async function deleteDocument(filename) {
    if (!confirm(`Are you sure you want to delete ${filename}? This will remove it from the AI's knowledge base.`)) return;
    
    try {
        const res = await fetch(`/api/sermons/${encodeURIComponent(filename)}`, { method: 'DELETE' });
        const data = await res.json();
        
        if (res.ok) {
            uploadStatus.className = 'status-msg success';
            uploadStatus.textContent = data.message;
            fetchDocuments();
        } else {
            uploadStatus.className = 'status-msg error';
            uploadStatus.textContent = `Error: ${data.detail || 'Delete failed'}`;
        }
    } catch (e) {
        console.error(e);
        uploadStatus.className = 'status-msg error';
        uploadStatus.textContent = 'Network error occurred while deleting.';
    }
}

// ==========================================
// WebSocket Logic for Live Counselling
// ==========================================
let ws;
const chatPlaceholder = document.querySelector('.chat-placeholder');

function connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}/api/admin/ws`;
    
    ws = new WebSocket(wsUrl);
    
    ws.onopen = () => {
        console.log("Admin WebSocket connected");
        chatPlaceholder.innerHTML = '<p style="color: #4CAF50">Listening for distress signals...</p>';
    };
    
    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.type === 'user_connected') {
            console.log("User connected:", data.client_id);
        } else if (data.type === 'message') {
            handleIncomingMessage(data.client_id, data.text);
        }
    };
    
    ws.onclose = () => {
        console.log("WebSocket disconnected, retrying...");
        setTimeout(connectWebSocket, 3000);
    };
}

const activeChats = {}; // client_id -> container element

function handleIncomingMessage(clientId, text) {
    if (!activeChats[clientId]) {
        // Create new chat window
        chatPlaceholder.style.display = 'none';
        
        const chatWindow = document.createElement('div');
        chatWindow.className = 'chat-window glass-panel';
        chatWindow.style.marginTop = '20px';
        chatWindow.innerHTML = `
            <h3>Session ID: ${clientId.substring(0, 8)}...</h3>
            <div class="chat-messages" id="msgs-${clientId}" style="height: 150px; overflow-y: auto; margin: 10px 0; padding: 10px; background: rgba(0,0,0,0.3); border-radius: 8px;"></div>
            <div style="display:flex; gap: 10px;">
                <input type="text" id="input-${clientId}" placeholder="Reply to user..." style="flex: 1;" />
                <button class="primary-btn" id="send-${clientId}">Send</button>
            </div>
        `;
        document.querySelector('.live-chats-section').appendChild(chatWindow);
        
        document.getElementById(`send-${clientId}`).addEventListener('click', () => {
            const input = document.getElementById(`input-${clientId}`);
            const msg = input.value.trim();
            if (msg) {
                ws.send(JSON.stringify({ client_id: clientId, text: msg }));
                appendMessage(clientId, "You", msg, "#3D5AFE");
                input.value = '';
            }
        });
        
        activeChats[clientId] = chatWindow;
    }
    
    appendMessage(clientId, "User", text, "#E5C07B");
}

function appendMessage(clientId, sender, text, color) {
    const msgsContainer = document.getElementById(`msgs-${clientId}`);
    const msgEl = document.createElement('div');
    msgEl.style.marginBottom = '8px';
    msgEl.innerHTML = `<strong style="color: ${color}">${sender}:</strong> <span style="color: rgba(255,255,255,0.8)">${text}</span>`;
    msgsContainer.appendChild(msgEl);
    msgsContainer.scrollTop = msgsContainer.scrollHeight;
}

// Start WS connection if user is logged in
onAuthStateChanged(auth, (user) => {
    if (user && !ws) {
        connectWebSocket();
    }
});
