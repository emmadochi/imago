# Imago Deployment Guide: Launching to Production

Launching your app involves two main phases: deploying your Python backend to the cloud, and compiling your Flutter app for the App Stores.

---

## Phase 1: Deploying the Backend (FastAPI + Admin Dashboard)
The easiest, most robust way to host a FastAPI server for free/cheap is using a platform like **Render**, **Railway**, or **Heroku**. I highly recommend **Render** for its simplicity and generous free tier.

### 1. Push Your Code to GitHub
1. Create a free account on [GitHub](https://github.com/).
2. Upload the `backend` folder of your project to a new repository.

### 2. Connect to Render
1. Create a free account on [Render.com](https://render.com/).
2. Click **New +** and select **Web Service**.
3. Connect your GitHub account and select your backend repository.

### 3. Configure the Server Settings
Render will automatically detect your `requirements.txt` file, but ensure these settings match:
- **Build Command:** `pip install -r requirements.txt`
- **Start Command:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

### 4. Inject Environment Variables
On the configuration page, scroll down to **Environment Variables** and add your secret keys. (Do NOT upload your `.env` file to GitHub).
- `GEMINI_API_KEY`: *[Your Gemini Key]*
- `PINECONE_API_KEY`: *[Your Pinecone Key]*
- `PINECONE_INDEX_NAME`: `pastoral-sermons`

### 5. Deploy!
Click **Create Web Service**. Render will build and launch your server. It will provide you with a live URL (e.g., `https://imago-backend.onrender.com`).
- Your Admin Dashboard will automatically be live at `https://imago-backend.onrender.com/admin/`!

---

## Phase 2: Updating & Publishing the Flutter App
Once your backend is live on the internet, your Flutter app no longer needs your local IP address!

### 1. Update the Backend URL
In your Flutter project, open `lib/screens/chat_screen.dart` and update the URL to point to your new live server:
```dart
// Change this:
final String _backendUrl = 'http://192.168.100.62:8000';

// To your new production URL:
final String _backendUrl = 'https://imago-backend.onrender.com';
```

### 2. Compile for Android (Google Play Store)
To package the app for the public, run this command in your Flutter terminal:
```bash
flutter build appbundle
```
This generates a secure `.aab` file located in `build/app/outputs/bundle/release/`. This is the exact file you upload to the **Google Play Console**!

### 3. Compile for iOS (Apple App Store)
*(Note: You need a Mac to compile for iOS).*
1. Run `flutter build ipa`
2. Open Xcode, sign the app with your Apple Developer account, and upload it via Transporter.

> **Data Persistence Note:** 
> Render's free tier spins down after 15 minutes of inactivity, and the local disk is wiped on restart. This means `documents.json` (your admin tracking file) will reset on a free tier. If you want permanent document tracking, you should either upgrade to Render's paid tier ($7/month) which includes a persistent disk, or we can move `documents.json` into a tiny Firebase Firestore database! Pinecone vectors are safe regardless.
