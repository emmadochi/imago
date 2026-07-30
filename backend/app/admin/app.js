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

// Tab Navigation Logic
const navTabs = document.querySelectorAll('.nav-tab');
const tabPanes = document.querySelectorAll('.tab-pane');

navTabs.forEach(tab => {
    tab.addEventListener('click', () => {
        const targetTab = tab.getAttribute('data-tab');
        navTabs.forEach(t => t.classList.remove('active'));
        tabPanes.forEach(p => {
            p.classList.remove('active');
            p.classList.add('hidden');
        });

        tab.classList.add('active');
        const targetPane = document.getElementById(targetTab);
        if (targetPane) {
            targetPane.classList.remove('hidden');
            targetPane.classList.add('active');
        }
    });
});

// Auth State Observer
onAuthStateChanged(auth, (user) => {
    if (user) {
        // User is signed in
        loginContainer.classList.add('hidden');
        dashboardContainer.classList.remove('hidden');
        fetchDocuments();
        fetchAnalytics();
    } else {
        // User is signed out / Local preview fallback
        loginContainer.classList.add('hidden');
        dashboardContainer.classList.remove('hidden');
        fetchDocuments();
        fetchAnalytics();
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
        // Fallback for local admin testing
        loginContainer.classList.add('hidden');
        dashboardContainer.classList.remove('hidden');
        fetchDocuments();
        fetchAnalytics();
    }
});

// Logout Handler
logoutBtn.addEventListener('click', () => {
    signOut(auth);
    loginContainer.classList.remove('hidden');
    dashboardContainer.classList.add('hidden');
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
    const validExtensions = ['.pdf', '.txt', '.docx', '.mp3', '.wav', '.m4a'];
    const fileExtension = file.name.substring(file.name.lastIndexOf('.')).toLowerCase();
    
    if (!validExtensions.includes(fileExtension)) {
        uploadStatus.className = 'status-msg error';
        uploadStatus.textContent = 'Invalid file type. Supported formats: PDF, TXT, DOCX, MP3, WAV, M4A.';
        return;
    }

    await uploadFile(file);
}

async function uploadFile(file) {
    uploadStatus.className = 'status-msg loading';
    uploadStatus.textContent = `Processing and vectorizing ${file.name}... Please wait a moment.`;

    const formData = new FormData();
    formData.append('file', file);

    try {
        const response = await fetch('/api/sermons/upload', {
            method: 'POST',
            body: formData
        });

        const data = await response.json();

        if (response.ok) {
            uploadStatus.className = 'status-msg success';
            uploadStatus.textContent = data.message || 'File uploaded and indexed in Pinecone successfully!';
            fetchDocuments();
            fetchAnalytics();
        } else {
            uploadStatus.className = 'status-msg error';
            uploadStatus.textContent = `Error: ${data.detail || 'Upload failed'}`;
        }
    } catch (error) {
        uploadStatus.className = 'status-msg error';
        uploadStatus.textContent = 'Network error occurred while uploading file.';
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
            documentList.innerHTML = '<p style="color: rgba(255,255,255,0.5); font-size: 13px;">No documents indexed yet.</p>';
            return;
        }
        
        documentList.innerHTML = '';
        data.documents.forEach(doc => {
            const item = document.createElement('div');
            item.className = 'document-item';
            
            const info = document.createElement('div');
            info.className = 'doc-info';
            info.innerHTML = `<strong>${doc.title}</strong><br/><small style="color: rgba(255,255,255,0.6);">${doc.filename} • ${doc.num_chunks} vector chunks</small>`;
            
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
        documentList.innerHTML = '<p style="color: #ff5252; font-size: 13px;">Failed to load document list.</p>';
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
            fetchAnalytics();
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

// Analytics Fetching
async function fetchAnalytics() {
    try {
        const response = await fetch('/api/admin/analytics');
        const data = await response.json();
        
        if (data.status === 'success') {
            document.getElementById('stat-total-sessions').textContent = data.total_moods || 0;
            document.getElementById('stat-total-prayers').textContent = data.total_prayers || 0;
            document.getElementById('stat-total-docs').textContent = data.total_documents || 0;

            renderMoodChart(data.mood_counts, data.total_moods);
            renderPrayerList(data.recent_prayers);
        }
    } catch (error) {
        console.error("Failed to fetch analytics:", error);
        document.getElementById('mood-chart').innerHTML = '<p class="status-msg error">Failed to load mood analytics.</p>';
        document.getElementById('prayer-list').innerHTML = '<p class="status-msg error">Failed to load prayer topics.</p>';
    }
}

function renderMoodChart(moodCounts, total) {
    const container = document.getElementById('mood-chart');
    container.innerHTML = '';
    
    if (!moodCounts || total === 0) {
        container.innerHTML = '<p style="color: rgba(255,255,255,0.5); font-size: 13px;">No mood data recorded yet.</p>';
        return;
    }

    const moods = Object.keys(moodCounts);
    moods.sort((a, b) => moodCounts[b] - moodCounts[a]);

    for (let mood of moods) {
        const count = moodCounts[mood];
        const percentage = Math.round((count / total) * 100);
        
        const row = document.createElement('div');
        row.className = 'mood-bar-container';
        
        row.innerHTML = `
            <div class="mood-label">${mood}</div>
            <div class="mood-bar-track">
                <div class="mood-bar-fill" style="width: ${percentage}%"></div>
            </div>
            <div class="mood-count">${percentage}%</div>
        `;
        
        container.appendChild(row);
    }
}

function renderPrayerList(prayers) {
    const container = document.getElementById('prayer-list');
    container.innerHTML = '';
    
    if (!prayers || prayers.length === 0) {
        container.innerHTML = '<p style="color: rgba(255,255,255,0.5); font-size: 13px;">No prayer topics recorded yet.</p>';
        return;
    }
    
    for (let p of prayers) {
        const li = document.createElement('li');
        li.textContent = `• ${p}`;
        container.appendChild(li);
    }
}

// Media Sync Event Handlers
const youtubeUrlInput = document.getElementById('youtube-url');
const youtubeSyncBtn = document.getElementById('youtube-sync-btn');
const youtubeStatus = document.getElementById('youtube-status');

if (youtubeSyncBtn) {
    youtubeSyncBtn.addEventListener('click', async () => {
        const url = youtubeUrlInput.value.trim();
        if (!url) {
            youtubeStatus.className = 'status-msg error';
            youtubeStatus.textContent = 'Please enter a valid YouTube channel URL.';
            return;
        }

        youtubeStatus.className = 'status-msg loading';
        youtubeStatus.textContent = 'Syncing YouTube channel...';

        try {
            const response = await fetch('/api/admin/youtube', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ channel_url: url })
            });

            const data = await response.json();

            if (response.ok) {
                youtubeStatus.className = 'status-msg success';
                youtubeStatus.textContent = data.message || 'Channel synced successfully!';
                youtubeUrlInput.value = '';
            } else {
                youtubeStatus.className = 'status-msg error';
                youtubeStatus.textContent = `Error: ${data.detail || 'Sync failed'}`;
            }
        } catch (error) {
            youtubeStatus.className = 'status-msg error';
            youtubeStatus.textContent = 'Network error occurred while syncing.';
            console.error(error);
        }
    });
}

const podcastUrlInput = document.getElementById('podcast-url');
const podcastSyncBtn = document.getElementById('podcast-sync-btn');
const podcastStatus = document.getElementById('podcast-status');

if (podcastSyncBtn) {
    podcastSyncBtn.addEventListener('click', async () => {
        const url = podcastUrlInput.value.trim();
        if (!url) {
            podcastStatus.className = 'status-msg error';
            podcastStatus.textContent = 'Please enter a valid Podcast RSS URL.';
            return;
        }

        podcastStatus.className = 'status-msg loading';
        podcastStatus.textContent = 'Syncing Podcast Feed...';

        try {
            const response = await fetch('/api/admin/podcast', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ rss_url: url })
            });

            const data = await response.json();

            if (response.ok) {
                podcastStatus.className = 'status-msg success';
                podcastStatus.textContent = data.message || 'Podcast feed synced successfully!';
                podcastUrlInput.value = '';
            } else {
                podcastStatus.className = 'status-msg error';
                podcastStatus.textContent = `Error: ${data.detail || 'Sync failed'}`;
            }
        } catch (error) {
            podcastStatus.className = 'status-msg error';
            podcastStatus.textContent = error.message || 'Error syncing podcast.';
        }
    });
}
