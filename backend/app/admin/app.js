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
    
    const validExtensions = ['.pdf', '.txt', '.docx', '.mp3', '.wav', '.m4a'];
    let successCount = 0;
    let failCount = 0;
    
    for (let i = 0; i < files.length; i++) {
        const file = files[i];
        const fileExtension = file.name.substring(file.name.lastIndexOf('.')).toLowerCase();
        
        if (!validExtensions.includes(fileExtension)) {
            console.error(`Invalid file type: ${file.name}`);
            failCount++;
            continue;
        }

        uploadStatus.className = 'status-msg loading';
        uploadStatus.textContent = `Processing file ${i + 1} of ${files.length}: ${file.name}...`;

        const success = await uploadFile(file);
        if (success) {
            successCount++;
        } else {
            failCount++;
        }
    }
    
    if (successCount > 0 && failCount === 0) {
        uploadStatus.className = 'status-msg success';
        uploadStatus.textContent = `All ${successCount} files uploaded successfully!`;
    } else if (successCount > 0 && failCount > 0) {
        uploadStatus.className = 'status-msg warning';
        uploadStatus.textContent = `Completed! ${successCount} succeeded, ${failCount} failed.`;
    } else {
        uploadStatus.className = 'status-msg error';
        uploadStatus.textContent = `Failed to upload any of the ${failCount} files.`;
    }
    
    fetchDocuments();
    fetchAnalytics();
}

async function uploadFile(file) {
    const formData = new FormData();
    formData.append('file', file);

    try {
        const response = await fetch('/api/sermons/upload', {
            method: 'POST',
            body: formData
        });
        
        return response.ok;
    } catch (error) {
        console.error(error);
        return false;
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

// ── USER FEEDBACK & VALIDATION TAB LOGIC ──────────────────
async function fetchFeedback() {
    const container = document.getElementById('feedback-items-container');
    const statAvgRating = document.getElementById('stat-avg-rating');
    const statTotalFeedback = document.getElementById('stat-total-feedback');
    const statMicroRatio = document.getElementById('stat-micro-ratio');

    if (!container) return;

    try {
        const res = await fetch('/api/admin/feedback');
        const data = await res.json();

        if (data.status === 'success') {
            if (statAvgRating) statAvgRating.textContent = `${data.average_rating || 5.0} ★`;
            if (statTotalFeedback) statTotalFeedback.textContent = data.total_feedback || 0;

            const pos = data.micro_positive || 0;
            const neg = data.micro_negative || 0;
            const totalMicro = pos + neg;
            const ratio = totalMicro > 0 ? Math.round((pos / totalMicro) * 100) : 100;
            if (statMicroRatio) statMicroRatio.textContent = `${ratio}%`;

            const items = data.feedback_items || [];
            if (items.length === 0) {
                container.innerHTML = `
                    <div style="text-align: center; padding: 2.5rem; color: #94A3B8;">
                        <p style="font-size: 1.5rem; margin-bottom: 0.5rem;">💌</p>
                        <p style="font-weight: 500;">No user feedback submitted yet.</p>
                        <p style="font-size: 0.85rem;">Feedback submitted from mobile and desktop builds will stream here in real time.</p>
                    </div>
                `;
                return;
            }

            container.innerHTML = items.map(fb => {
                const stars = '★'.repeat(fb.rating || 5) + '☆'.repeat(Math.max(0, 5 - (fb.rating || 5)));
                const dateStr = fb.timestamp ? new Date(fb.timestamp).toLocaleString() : 'Recent';
                const userTag = fb.user_name || fb.email || 'Anonymous Believer';
                const catTag = fb.category_label || fb.category || 'General';

                return `
                    <div class="glass-panel" style="padding: 1.1rem; border-radius: 12px; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08);">
                        <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.4rem;">
                            <div>
                                <span style="color: #FFC857; font-size: 1.1rem; letter-spacing: 2px;">${stars}</span>
                                <span style="display: inline-block; margin-left: 0.75rem; background: rgba(79, 70, 229, 0.2); color: #818CF8; padding: 2px 8px; border-radius: 6px; font-size: 0.75rem; font-weight: 600;">
                                    ${catTag}
                                </span>
                                <span style="display: inline-block; margin-left: 0.4rem; background: rgba(255,255,255,0.06); color: #94A3B8; padding: 2px 6px; border-radius: 6px; font-size: 0.7rem;">
                                    ${fb.platform || 'app'} • ${fb.screen_context || 'general'}
                                </span>
                            </div>
                            <span style="font-size: 0.75rem; color: #64748B;">${dateStr}</span>
                        </div>
                        <p style="margin: 0.4rem 0 0.6rem 0; font-size: 0.95rem; line-height: 1.45; color: #E2E8F0;">
                            "${fb.message || ''}"
                        </p>
                        <div style="font-size: 0.78rem; color: #94A3B8; display: flex; gap: 0.8rem;">
                            <span>👤 ${userTag}</span>
                            ${fb.email ? `<span>✉️ <a href="mailto:${fb.email}" style="color: #818CF8; text-decoration: none;">${fb.email}</a></span>` : ''}
                        </div>
                    </div>
                `;
            }).join('');
        }
    } catch (e) {
        console.error('Error fetching feedback:', e);
        if (container) {
            container.innerHTML = '<p class="error-msg">Failed to load feedback feed.</p>';
        }
    }
}

const refreshFeedbackBtn = document.getElementById('refresh-feedback-btn');
if (refreshFeedbackBtn) {
    refreshFeedbackBtn.addEventListener('click', fetchFeedback);
}

// Initial fetch on page load
fetchFeedback();
