# J.A.R.V.I.S. Android Assistant

A personal, futuristic AI assistant for Android (built for POCO M7 Plus / Android physical devices), powered by Flutter, a Node.js/Express cognitive server, and Google Gemini.

Inspired by Tony Stark's JARVIS: composed, loyal, sharp, addressing the user as "Sir", fluent in English and natural Hinglish.

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│               POCO M7 Plus (Physical Phone)            │
│  - Flutter UI (Futuristic Dark Arc Reactor Theme)       │
│  - Voice Input (Speech-to-Text)                        │
│  - Speech Output (Text-to-Speech)                      │
│  - Action Service & Validation Engine                  │
│  - Native Kotlin MethodChannel (App Control & Intents) │
└───────────────────────────┬────────────────────────────┘
                            │ USB Port Forwarding
                            │ `adb reverse tcp:3000 tcp:3000`
                            ▼
┌────────────────────────────────────────────────────────┐
│               JARVIS Core Backend (Node.js)             │
│  - Express REST API (`/api/chat`, `/api/health`)        │
│  - Gemini Chat History Alternation & Privacy Filtering │
│  - Action Protocol & Rule Intent Fallback Engine        │
│  - Secure `.env` Storage (API key never touches mobile)│
└───────────────────────────┬────────────────────────────┘
                            │ HTTPS (IPv4 Priority)
                            ▼
┌────────────────────────────────────────────────────────┐
│                  Google Gemini API                     │
│  - Primary: gemini-3.7-flash (with 3.5 fallback)       │
│  - System Prompt: Loyal JARVIS Persona & Actions       │
└────────────────────────────────────────────────────────┘
```

---

## Strict Privacy Guarantees

JARVIS is built with a **strict privacy-first architecture**:
1. **Zero Contact Access**: JARVIS **never** requests `READ_CONTACTS`. Phone numbers must be explicitly stated in voice or typed commands. If a contact name is spoken (e.g. *"Call Sam"*), JARVIS will politely inform you that contacts are not accessed and ask for the phone number.
2. **Zero Silent Calling**: Uses Android's native `ACTION_DIAL` (no `CALL_PHONE` permission). The dialer opens with the number prefilled; you tap the call button.
3. **Zero Silent SMS**: Uses Android's native `ACTION_SENDTO` with `smsto:` URI (no `SEND_SMS` or `READ_SMS` permission). The SMS app opens with recipient and message prefilled; you review and tap Send.
4. **Zero Background WhatsApp Scraping**: WhatsApp conversations are opened via WhatsApp's official `https://wa.me/<international_number>?text=<encoded_message>` deep link. You review and tap Send.
5. **Zero Broad Permissions**: The app **does not** request `QUERY_ALL_PACKAGES`, `READ_CALL_LOG`, `MANAGE_EXTERNAL_STORAGE`, `READ_MEDIA_*`, Accessibility Services, or notification listeners.
6. **API Key Security**: The Gemini API key remains strictly on the Node.js backend (`backend/.env`) and is never embedded in the Android APK or pushed to Git.

---

## Supported Commands

### 1. Phone Calling (`make_call`)
Opens Android phone dialer with the number prefilled:
- *"Call 9876543210"*
- *"Call +919876543210"*
- *"Dial 9876543210"*
- *"9876543210 ko call lagao"*
- *"9876543210 ko call karo"*

### 2. SMS Messaging (`send_sms`)
Opens default SMS application with recipient and message prefilled:
- *"Send SMS to 9876543210 saying I'll be late"*
- *"SMS to 9876543210: I'm on my way"*
- *"Send message to 9876543210 saying Meeting at 5 PM"*
- *"9876543210 ko SMS bhejo message I will be late"*

### 3. WhatsApp Messaging (`open_whatsapp`)
Opens WhatsApp chat directly with recipient and message prefilled:
- *"Open WhatsApp and message +919876543210 saying Hello"*
- *"WhatsApp message to +919876543210: I'm on my way"*
- *"WhatsApp pe +919876543210 ko message bhejo Hello Sir"*
- *Note*: WhatsApp requires an international country code (e.g. `+91`). If only 10 digits are provided, JARVIS asks for the country code to ensure delivery accuracy.

### 4. Google Search (`google_search`)
- *"Jarvis, Google par React tutorials search kar."*
- *"Search latest space missions on Google"*
- *"Google search Flutter animations"*

### 5. YouTube Search (`youtube_search`)
- *"YouTube par latest songs search kar."*
- *"Search Iron Man soundtrack on YouTube"*
- *"YouTube pe coding tutorials dhoondo"*

### 6. App Launching (`open_app`)
- *"Chrome open kar"* / *"Open Google Chrome"*
- *"YouTube open kar"* / *"Open YouTube"*
- *"Google Maps open kar"* / *"Maps kholo"*
- *"Settings open kar"* / *"Settings kholo"*

### 7. Natural AI Conversation
- *"Hello Jarvis, how are you today?"*
- *"Kya haal hai Jarvis?"* -> *"Main bilkul theek hoon, Sir. Bataiye aaj kya karna hai?"*
- *"Explain quantum entanglement in simple words"*

---

## Setup & Running

### 1. Prerequisites
- Flutter SDK (3.x+)
- Node.js (v20+)
- Android device connected via USB with Developer Options & USB Debugging enabled

### 2. Backend Setup
1. Navigate to `backend/`:
   ```bash
   cd backend
   npm install
   ```
2. Create `backend/.env` (use `backend/.env.example` as a template):
   ```env
   PORT=3000
   GEMINI_API_KEY=your_gemini_api_key_here
   GEMINI_MODEL=gemini-3.7-flash
   ```
3. Start the backend:
   ```bash
   npm start
   ```

### 3. Connect Physical Android Device (POCO M7 Plus)
1. Plug your phone into PC via USB.
2. Route port 3000 from phone to PC:
   ```bash
   adb reverse tcp:3000 tcp:3000
   ```
3. Run Flutter app:
   ```bash
   flutter run -d <your-device-id>
   ```
4. Verify server link: In JARVIS UI, tap the Settings icon in the top bar and tap **Test Server Connection** (`http://127.0.0.1:3000`).

---

## Testing & Quality Assurance

### Run Backend Unit Tests:
```bash
# Test chat history alternating turns and validation:
node backend/test_history.js

# Test Phase 2 actions (Search, Open Apps):
node backend/test_actions.js

# Test Phase 3 phone actions (Call, SMS, WhatsApp, and Privacy):
node backend/test_phase3_phone_actions.js
```

### Run Flutter Verification:
```bash
flutter analyze
flutter test
flutter build apk --debug
```

---

## Project Status

- [x] **Phase 1**: Voice input (`speech_to_text`), TTS (`flutter_tts`), chat UI (futuristic dark theme), bilingual Hinglish/English persona, loyal "Sir" address, `.env` security.
- [x] **Phase 2**: Natural language Android actions: Google Search (`google_search`), YouTube Search (`youtube_search`), and App Launching (`open_app` for Chrome, YouTube, Maps, and Settings).
- [x] **Phase 3**: Phone Actions: Dialing (`make_call` via `ACTION_DIAL`), SMS (`send_sms` via `ACTION_SENDTO`), WhatsApp (`open_whatsapp` via deep link), privacy guards against contact access.
- [ ] **Phase 4**: Wake word, background listening, lock-screen assistant (future phase).
