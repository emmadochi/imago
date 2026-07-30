# Imago: Digital Ministry Platform Implementation Plan

This document outlines the technical implementation plan for building Imago, transitioning the vision from `INFO.MD` into actionable development phases. 

## User Review Required

> [!IMPORTANT]
> Please review the proposed architecture and phasing below. Specifically, confirm if you are comfortable starting with **Flutter** for the mobile app and **FastAPI (Python)** for the backend, as suggested in the blueprint.

## Open Questions

> [!WARNING]
> **Admin Portal Tech Stack:** The blueprint outlines an admin portal for church leaders. Should we build this as a Flutter Web app (to share code with the mobile app) or a dedicated React/Next.js web application?
> 
> **Initial Bible Translation:** For the offline SQLite Bible, which public domain translation should we bundle for the MVP (e.g., KJV, World English Bible (WEB), or ASV)?

---

## Architecture Overview

**Frontend:** Flutter (iOS & Android)
**Backend:** FastAPI (Python)
**Authentication & Database:** Firebase Auth, Firestore
**AI & Vector Storage:** Google Gemini, Pinecone
**Offline Storage (Bible/Dict):** Local SQLite Database

---

## Proposed Changes / Phases

### Phase 1: Foundation & Design System (Frontend)
We will establish the "Antigravity" design language across the Flutter application.
*   **[NEW]** Initialize Flutter project (`imago_app`)
*   **[NEW]** Setup Firebase Authentication & Firestore connections.
*   **[NEW]** Build the core UI components: Glassmorphic cards, weightless floating elements, and the base navigation layout.
*   **[NEW]** Implement the Onboarding flow & Daily Spiritual Check-in UI.

### Phase 2: Core Backend & RAG Pipeline
Setting up the brain of Imago.
*   **[NEW]** Initialize FastAPI project (`imago_backend`).
*   **[NEW]** Integrate Google Gemini API for base conversational abilities.
*   **[NEW]** Setup Pinecone Vector Database.
*   **[NEW]** Create the Document Ingestion pipeline (to convert uploaded pastoral books/sermons into embeddings).
*   **[NEW]** Create the semantic search (RAG) endpoint that Imago uses to answer questions.

### Phase 3: The Chat & Voice Experience
Connecting the frontend to the backend.
*   **[NEW]** Build the Chat Interface in Flutter.
*   **[NEW]** Implement "AI Memory" using Firestore to store chat history and user context.
*   **[NEW]** Add Voice to Text / Text to Voice capabilities (Hold-to-speak counseling).

### Phase 4: Bible & Dictionary Integration
Implementing the features we just brainstormed.
*   **[NEW]** Generate/Acquire a pre-populated SQLite database containing the Bible and Easton's Bible Dictionary.
*   **[NEW]** Build the Dedicated Bible Tab (Offline reading, search, parallel versions).
*   **[NEW]** Implement Deep Chat Integration (Glowing clickable verse chips that slide up the Bible reader).
*   **[NEW]** Implement Highlight-to-Define functionality for theological terms.

### Phase 5: The Admin Portal
The dashboard for church leadership.
*   **[NEW]** Initialize Admin Web Project.
*   **[NEW]** Build Document/Sermon upload interface.
*   **[NEW]** Build Anonymous Analytics Dashboard (Mood trends, top prayer requests).

---

## Verification Plan

### Automated Tests
-   Unit tests for the FastAPI RAG pipeline to ensure similarity search returns relevant pastoral documents.
-   Widget tests in Flutter for the Bible Reader to ensure fast offline SQLite queries.

### Manual Verification
-   **Design Audit:** Verify the app strictly adheres to the "Antigravity" UI/UX principles (no standard Material design elements).
-   **Theological Testing:** Test the Gemini AI with complex spiritual questions to ensure ethical guardrails and crisis detection work as intended.
-   **Offline Test:** Put the physical device in airplane mode and verify the Bible tab and Dictionary remain fully functional.
