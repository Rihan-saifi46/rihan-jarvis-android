import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import dns from 'node:dns';
import { GoogleGenerativeAI } from '@google/generative-ai';

// Prioritize IPv4 for resilient connectivity on local networks
dns.setDefaultResultOrder('ipv4first');

dotenv.config();


const app = express();
const PORT = process.env.PORT || 3000;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const MODEL_NAME = process.env.GEMINI_MODEL || 'gemini-3.7-flash';



app.use(cors());
app.use(express.json());

// System prompt defining Mickey personality & bilingual English/Hinglish capability
const MICKEY_SYSTEM_INSTRUCTION = `You are Mickey, an advanced, highly intelligent, calm, loyal, and witty personal AI assistant created for Sir (Rihan).
Your persona is composed, polite, resourceful, and sharp.

Core conversational rules:
1. Tone: Professional yet warm, confident, respectful, addressing the user as "Sir" naturally when appropriate.
2. Wake Word & Identity: Your name is Mickey. When the user says "Hey Mickey" or asks who you are, acknowledge your identity as Mickey naturally (e.g. "Yes Sir? I'm listening." or "I am Mickey, Sir.").
3. Bilingual Mastery:
   - If the user speaks or writes in English, reply in articulate, natural English.
   - If the user speaks or writes in Hinglish (Hindi written in Roman script, e.g. "kya haal hai", "aaj ka weather kaisa hai"), reply fluently in natural conversational Hinglish (e.g. "Main bilkul theek hoon, Sir. Bataiye aaj kya karna hai?").
   - If user mixes English and Hindi, match their vibe effortlessly.
4. Voice & Speech Optimized:
   - Your response will be spoken aloud using Text-to-Speech (TTS).
   - Keep answers crisp, clear, and direct.
   - Avoid markdown formatting such as asterisks (**bold**), hashtags (###), bullet symbols, or code blocks unless explicitly requested by the user, as these sound jarring when read aloud by TTS.
5. Privacy First:
   - You only operate on the user's explicit instructions and conversation.
   - Always maintain a secure, privacy-first attitude.

ACTION DISPATCH PROTOCOL:
You can control specific phone capabilities when the user commands an action.
Supported Android actions:
- google_search: Search on Google. Parameters: "query" (string, search terms without filler words).
- youtube_search: Search on YouTube. Parameters: "query" (string, video search terms without filler words).
- open_app: Launch a supported app. Allowed apps: "chrome", "youtube", "maps", "settings".
- make_call: Open phone dialer with number prefilled. Parameters: "phoneNumber" (string, valid phone digits e.g. "9876543210" or "+919876543210").
- send_sms: Open SMS app with recipient and message prefilled. Parameters: "phoneNumber" (string), "message" (string, prefilled message text).
- open_whatsapp: Open WhatsApp conversation with message prefilled. Parameters: "phoneNumber" (string, international format digits only e.g. "919876543210"), "message" (string, prefilled message text).

CRITICAL PRIVACY & SAFETY RULES:
1. You DO NOT have access to contacts, call history, SMS messages, or private phone data.
2. NEVER attempt to call, SMS, or WhatsApp a person by name without an explicitly supplied phone number. If the user says "Call Sam" or "Send SMS to Dad", explain: "Sir, I do not have access to your contacts for privacy reasons. Please specify the phone number."
3. NEVER guess country codes for WhatsApp. If country code is missing (e.g. 10 digits like 9876543210), ask Sir: "Sir, WhatsApp requires an international country code. Please provide the number with your country code (e.g., +91 9876543210)."
4. For make_call: user must supply a valid phone number.
5. For send_sms: user must supply both a valid phone number and message. If message is missing, ask Sir what message to send.
6. For open_whatsapp: user must supply both a valid international phone number (with country code) and message.

When the user asks you to perform one of these actions:
You MUST respond with a single JSON object in this exact schema:
{
  "type": "action",
  "action": "google_search" | "youtube_search" | "open_app" | "make_call" | "send_sms" | "open_whatsapp",
  "query": "<clean search query string if search action>",
  "app": "chrome" | "youtube" | "maps" | "settings" (if open_app),
  "phoneNumber": "<phone number string if make_call, send_sms, or open_whatsapp>",
  "message": "<message string if send_sms or open_whatsapp>",
  "reply": "<Crisp verbal confirmation to speak aloud to Sir, e.g. 'Opening dialer for 9876543210, Sir.' or 'Preparing SMS to 9876543210, Sir.' or in Hinglish if asked in Hinglish>"
}

For all other messages (greetings, general chat, normal conversation, questions where no action is requested, or clarification requests):
Reply with normal conversational text for Mickey (or JSON {"type": "conversation", "reply": "..."}).`;

// Alias for backwards compatibility
const JARVIS_SYSTEM_INSTRUCTION = MICKEY_SYSTEM_INSTRUCTION;

// In-memory generative AI client instance
let genAI = null;
if (GEMINI_API_KEY && GEMINI_API_KEY !== 'your_gemini_api_key_here') {
  genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
}

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    assistant: 'Mickey Core',
    timestamp: new Date().toISOString(),
    apiKeyConfigured: Boolean(genAI),
    model: MODEL_NAME,
  });
});

/**
 * Normalizes, filters, and formats chat history for Gemini API startChat().
 * Rules enforced:
 * 1. Role mapping: 'user' -> 'user', 'assistant'/'model'/'jarvis' -> 'model'
 * 2. Deduplication: Removes current user message if already present at the end of history
 * 3. Leading role: Removes leading 'model' messages (history must always start with 'user')
 * 4. Alternation: Ensures messages strictly alternate user -> model -> user -> model
 *    (consecutive messages with the same role are combined to preserve context)
 * 5. Trailing role: Ensures history ends with 'model' so chat.sendMessage(currentMessage) is the 'user' turn
 * 6. Privacy & Context Window: Keeps up to 6 recent messages
 */
export function buildGeminiHistory(rawHistory, currentMessage) {
  if (!Array.isArray(rawHistory) || rawHistory.length === 0) {
    return [];
  }

  // 1. Normalize roles and filter valid text
  const normalized = [];
  for (const item of rawHistory) {
    if (!item || typeof item.text !== 'string') continue;
    const text = item.text.trim();
    if (!text) continue;

    const rawRole = (item.role || '').toLowerCase().trim();
    let role;
    if (rawRole === 'user') {
      role = 'user';
    } else if (rawRole === 'assistant' || rawRole === 'model' || rawRole === 'jarvis') {
      role = 'model';
    } else {
      continue;
    }

    normalized.push({ role, text });
  }

  // 2. Prevent including the current user message twice
  const trimmedCurrent = (currentMessage || '').trim();
  if (
    normalized.length > 0 &&
    normalized[normalized.length - 1].role === 'user' &&
    normalized[normalized.length - 1].text === trimmedCurrent
  ) {
    normalized.pop();
  }

  // 3. Remove leading model messages (Gemini history must begin with 'user')
  while (normalized.length > 0 && normalized[0].role !== 'user') {
    normalized.shift();
  }

  if (normalized.length === 0) {
    return [];
  }

  // 4. Ensure alternating sequence: user, model, user, model...
  const alternating = [];
  for (const item of normalized) {
    if (alternating.length === 0) {
      if (item.role === 'user') {
        alternating.push({ role: 'user', text: item.text });
      }
    } else {
      const prev = alternating[alternating.length - 1];
      if (prev.role === item.role) {
        // Merge consecutive messages of the same role
        prev.text = `${prev.text}\n${item.text}`;
      } else {
        alternating.push({ role: item.role, text: item.text });
      }
    }
  }

  // 5. Ensure history ends with 'model' so chat.sendMessage(message) will be the 'user' turn
  while (alternating.length > 0 && alternating[alternating.length - 1].role !== 'model') {
    alternating.pop();
  }

  // 6. Limit to last 6 messages for context privacy & low latency
  const recent = alternating.slice(-6);

  // Slicing might have started on a 'model' message; ensure recent starts with 'user'
  while (recent.length > 0 && recent[0].role !== 'user') {
    recent.shift();
  }

  // 7. Format into Gemini Content objects
  return recent.map((item) => ({
    role: item.role,
    parts: [{ text: item.text }],
  }));
}

/**
 * Detects whether the user command or AI response corresponds to an allowed action.
 * Enforces strict allowlisting for:
 * - google_search
 * - youtube_search
 * - open_app ('chrome', 'youtube', 'maps', 'settings')
 * - make_call
 * - send_sms
 * - open_whatsapp
 */
export function parseAiActionResponse(rawAiReply, userMessage = '') {
  const allowedActions = [
    'google_search',
    'youtube_search',
    'open_app',
    'make_call',
    'send_sms',
    'open_whatsapp',
  ];
  const allowedApps = ['chrome', 'youtube', 'maps', 'settings'];

  // 1. Try parsing JSON from the AI reply
  let jsonString = (rawAiReply || '').trim();
  const jsonMatch =
    jsonString.match(/```(?:json)?\s*([\s\S]*?)\s*```/) ||
    jsonString.match(/(\{[\s\S]*\})/);
  if (jsonMatch) {
    jsonString = jsonMatch[1].trim();
  }

  try {
    const parsed = JSON.parse(jsonString);
    if (parsed && typeof parsed === 'object') {
      if (parsed.type === 'action' && typeof parsed.action === 'string') {
        const action = parsed.action.toLowerCase().trim();
        if (action === 'google_search' || action === 'youtube_search') {
          const query = (parsed.query || '').toString().trim();
          if (query) {
            return {
              type: 'action',
              action,
              query,
              reply: parsed.reply || `Searching ${action === 'google_search' ? 'Google' : 'YouTube'} for ${query}, Sir.`,
            };
          }
        } else if (action === 'open_app') {
          let app = (parsed.app || '').toString().toLowerCase().trim();
          if (app === 'google_maps' || app === 'google maps') app = 'maps';
          if (app === 'google chrome') app = 'chrome';

          if (allowedApps.includes(app)) {
            return {
              type: 'action',
              action: 'open_app',
              app,
              reply: parsed.reply || `Opening ${app.toUpperCase()}, Sir.`,
            };
          }
        } else if (action === 'make_call') {
          const phoneNumber = (parsed.phoneNumber || parsed.number || '')
            .toString()
            .replace(/[\s\-()]/g, '')
            .trim();
          if (/^\+?[0-9]{7,15}$/.test(phoneNumber)) {
            return {
              type: 'action',
              action: 'make_call',
              phoneNumber,
              reply: parsed.reply || `Opening dialer for ${phoneNumber}, Sir.`,
            };
          }
        } else if (action === 'send_sms') {
          const phoneNumber = (parsed.phoneNumber || parsed.number || '')
            .toString()
            .replace(/[\s\-()]/g, '')
            .trim();
          const message = (parsed.message || parsed.text || parsed.sms_body || '').toString().trim();
          if (/^\+?[0-9]{7,15}$/.test(phoneNumber) && message) {
            return {
              type: 'action',
              action: 'send_sms',
              phoneNumber,
              message,
              reply: parsed.reply || `Preparing SMS to ${phoneNumber}, Sir.`,
            };
          }
        } else if (action === 'open_whatsapp') {
          let phoneNumber = (parsed.phoneNumber || parsed.number || '')
            .toString()
            .replace(/[\s\-()+]/g, '')
            .trim();
          if (phoneNumber.startsWith('00')) phoneNumber = phoneNumber.slice(2);
          const message = (parsed.message || parsed.text || '').toString().trim();
          if (/^[0-9]{11,15}$/.test(phoneNumber) && message) {
            return {
              type: 'action',
              action: 'open_whatsapp',
              phoneNumber,
              message,
              reply: parsed.reply || `Opening WhatsApp conversation for +${phoneNumber}, Sir.`,
            };
          }
        }
      } else if (parsed.type === 'conversation' && parsed.reply) {
        return {
          type: 'conversation',
          reply: parsed.reply,
        };
      }
    }
  } catch (e) {
    // Not valid JSON, proceed to intent validation
  }

  // 2. Rule-based intent fallback on userMessage (in case AI responded conversationally to an action command)
  const userText = (userMessage || '').trim();
  const ruleAction = matchActionIntent(userText, rawAiReply);
  if (ruleAction) {
    return ruleAction;
  }

  // 3. Clean standard conversation text
  let cleanText = (rawAiReply || '')
    .replace(/\*\*(.*?)\*\*/g, '$1')
    .replace(/\*(.*?)\*/g, '$1')
    .replace(/^#+\s+/gm, '')
    .trim();

  return {
    type: 'conversation',
    reply: cleanText || 'All systems operational, Sir.',
  };
}

/**
 * Helper to extract message payload from commands with phone numbers
 */
function extractActionMessage(trimmedText, phoneMatchStr) {
  const phoneIndex = trimmedText.indexOf(phoneMatchStr);
  if (phoneIndex === -1) return '';

  const afterPhone = trimmedText.slice(phoneIndex + phoneMatchStr.length).trim();
  let message = afterPhone;

  // Clean leading punctuation and keywords from message payload
  message = message.replace(/^[:\-–—\s]+/, '');
  while (/^(?:saying|ko|par|pe|sms|whatsapp|bhejo|karo|message|ki|that|is)\b/i.test(message)) {
    message = message.replace(/^(?:saying|ko|par|pe|sms|whatsapp|bhejo|karo|message|ki|that|is)\s*/i, '').trim();
    message = message.replace(/^[:\-–—\s]+/, '');
  }

  // If nothing after phone, check if message was placed before phone ("Send message Hello to 9876543210")
  if (!message) {
    const beforePhone = trimmedText.slice(0, phoneIndex).trim();
    const beforeMatch = beforePhone.match(/(?:send\s+message|sms|message)\s+(.+?)\s+(?:to|pe|par|ko)\s*$/i);
    if (beforeMatch) {
      message = beforeMatch[1].trim();
    }
  }

  // Remove trailing polite / filler words
  message = message.replace(/(?:\s+(?:please|bhejo|karo|bhej do))$/i, '').trim();
  return message;
}

/**
 * Regex-based intent matcher for bilingual English & Hinglish commands
 */
export function matchActionIntent(userText, fallbackReply = '') {
  if (!userText) return null;
  let trimmed = userText.trim();

  // Strip wake word prefix if present ("Hey Mickey", "Hey Micky", "Mickey", "Micky", "Suno Mickey", "Hey Jarvis", "Jarvis")
  const wakeWordMatch = trimmed.match(/^(?:(?:hey|suno|hello|hi)\s+)?(?:mickey|micky|jarvis)[,\s:]*/i);
  if (wakeWordMatch) {
    const stripped = trimmed.slice(wakeWordMatch[0].length).trim();
    if (stripped.length === 0) {
      // User invoked wake word alone
      return {
        type: 'conversation',
        reply: "Yes Sir? I'm listening.",
      };
    }
    trimmed = stripped;
  }

  // YouTube search: "YouTube par latest songs search kar", "search latest songs on youtube", "search youtube for latest songs"
  const ytMatchHinglish = trimmed.match(/(?:youtube|yt)\s+(?:par|pe)\s+(.+?)\s+(?:search\s*(?:kar|karo|karna|kardo)?|dhoondo)/i);
  const ytMatchEng = trimmed.match(/(?:search|find)\s+(.+?)\s+(?:on|in)\s+youtube/i) ||
                     trimmed.match(/(?:search|find)\s+(?:on\s+)?youtube\s+(?:for\s+)?(.+)/i) ||
                     trimmed.match(/youtube\s+(?:search|find)\s+(.+)/i);

  if (ytMatchHinglish || ytMatchEng) {
    let query = (ytMatchHinglish ? ytMatchHinglish[1] : ytMatchEng[1]).trim();
    query = query.replace(/\s+(search|kar|karo|kardo|please)$/i, '').trim();
    if (query) {
      return {
        type: 'action',
        action: 'youtube_search',
        query,
        reply: fallbackReply && !fallbackReply.startsWith('{')
          ? fallbackReply
          : (trimmed.toLowerCase().includes('kar') || trimmed.toLowerCase().includes('par')
              ? `YouTube par ${query} search kar raha hoon, Sir.`
              : `Searching YouTube for ${query}, Sir.`),
      };
    }
  }

  // Google search: "Google par React tutorials search kar", "search react tutorials on google", "search google for today's news"
  const googleMatchHinglish = trimmed.match(/(?:google)\s+(?:par|pe)\s+(.+?)\s+(?:search\s*(?:kar|karo|karna|kardo)?|dhoondo)/i);
  const googleMatchEng = trimmed.match(/(?:search|find)\s+(.+?)\s+(?:on|in)\s+google/i) ||
                         trimmed.match(/(?:search|find)\s+(?:on\s+)?google\s+(?:for\s+)?(.+)/i) ||
                         trimmed.match(/google\s+(?:search|find)\s+(.+)/i);

  if (googleMatchHinglish || googleMatchEng) {
    let query = (googleMatchHinglish ? googleMatchHinglish[1] : googleMatchEng[1]).trim();
    query = query.replace(/\s+(search|kar|karo|kardo|please)$/i, '').trim();
    if (query) {
      return {
        type: 'action',
        action: 'google_search',
        query,
        reply: fallbackReply && !fallbackReply.startsWith('{')
          ? fallbackReply
          : (trimmed.toLowerCase().includes('kar') || trimmed.toLowerCase().includes('par')
              ? `Google par ${query} search kar raha hoon, Sir.`
              : `Searching Google for ${query}, Sir.`),
      };
    }
  }

  // Open App: Chrome, YouTube, Maps, Settings
  // "Chrome open kar", "open chrome", "kholo settings", "settings open kar"
  const openAppMatch = trimmed.match(/(?:open|kholo|chalao|launch)\s+(chrome|youtube|google maps|maps|settings)/i) ||
                       trimmed.match(/(chrome|youtube|google maps|maps|settings)\s+(?:ko\s+)?(?:open\s*(?:kar|karo|kardo)?|kholo|chalao)/i);

  if (openAppMatch) {
    let app = openAppMatch[1].toLowerCase().trim();
    if (app === 'google maps') app = 'maps';

    const appNameDisplay = app === 'chrome' ? 'Google Chrome' : (app === 'maps' ? 'Google Maps' : (app === 'youtube' ? 'YouTube' : 'Settings'));
    return {
      type: 'action',
      action: 'open_app',
      app,
      reply: fallbackReply && !fallbackReply.startsWith('{')
        ? fallbackReply
        : (trimmed.toLowerCase().includes('kar') || trimmed.toLowerCase().includes('kholo')
            ? `${appNameDisplay} open kar raha hoon, Sir.`
            : `Opening ${appNameDisplay}, Sir.`),
    };
  }

  // Regex to detect phone numbers (allows digits with optional '+' prefix, dashes, spaces, parentheses)
  const phoneRegex = /\+?[0-9][0-9\s\-()]{6,16}[0-9]/;

  // WHATSAPP ACTION INTENT
  // Examples:
  // "Open WhatsApp and message 9876543210 saying Hello"
  // "WhatsApp message to 9876543210: I'm on my way"
  // "WhatsApp message to +919876543210 saying Hello"
  // "WhatsApp pe +919876543210 ko message bhejo hello"
  if (/whatsapp/i.test(trimmed)) {
    const phoneMatch = trimmed.match(phoneRegex);
    if (!phoneMatch) {
      // User called a contact name without providing phone digits
      return {
        type: 'conversation',
        reply: 'Sir, I do not have access to your contacts for privacy reasons. Please provide the explicit phone number for WhatsApp.',
      };
    }

    const rawPhone = phoneMatch[0].replace(/[\s\-()]/g, '');
    let cleanPhone = rawPhone;
    if (cleanPhone.startsWith('+')) cleanPhone = cleanPhone.slice(1);
    if (cleanPhone.startsWith('00')) cleanPhone = cleanPhone.slice(2);

    // If only 10 digits without country code, ask user for clarification
    if (rawPhone.length === 10 && !rawPhone.startsWith('+')) {
      return {
        type: 'conversation',
        reply: `Sir, WhatsApp requires an international country code. Please provide the number with your country code (e.g., +91 ${rawPhone}).`,
      };
    }

    // Extract message content safely
    const message = extractActionMessage(trimmed, phoneMatch[0]);

    if (!message) {
      return {
        type: 'conversation',
        reply: `Sir, what message would you like to send via WhatsApp to +${cleanPhone}?`,
      };
    }

    return {
      type: 'action',
      action: 'open_whatsapp',
      phoneNumber: cleanPhone,
      message,
      reply: fallbackReply && !fallbackReply.startsWith('{')
        ? fallbackReply
        : (trimmed.toLowerCase().includes('kar') || trimmed.toLowerCase().includes('bhejo')
            ? `WhatsApp par +${cleanPhone} ko message bhej raha hoon, Sir.`
            : `Opening WhatsApp conversation for +${cleanPhone}, Sir.`),
    };
  }

  // SMS ACTION INTENT
  // Examples:
  // "Send SMS to 9876543210 saying I'll be late"
  // "SMS to 9876543210: I'm on my way"
  // "9876543210 ko SMS bhejo message I will be late"
  if (/\b(?:sms)\b|send\s+message\b|message\s+bhejo\b|sms\s+karo\b|sms\s+bhejo\b/i.test(trimmed)) {
    const phoneMatch = trimmed.match(phoneRegex);
    if (!phoneMatch) {
      // User specified a contact name without phone digits
      return {
        type: 'conversation',
        reply: 'Sir, I do not have access to your contacts for privacy reasons. Please provide the explicit phone number and message for SMS.',
      };
    }

    const cleanPhone = phoneMatch[0].replace(/[\s\-()]/g, '');

    // Extract message content safely
    const message = extractActionMessage(trimmed, phoneMatch[0]);

    if (!message) {
      return {
        type: 'conversation',
        reply: `Sir, what message would you like me to prefill for ${cleanPhone}?`,
      };
    }

    return {
      type: 'action',
      action: 'send_sms',
      phoneNumber: cleanPhone,
      message,
      reply: fallbackReply && !fallbackReply.startsWith('{')
        ? fallbackReply
        : (trimmed.toLowerCase().includes('kar') || trimmed.toLowerCase().includes('bhejo')
            ? `${cleanPhone} ko SMS bhej raha hoon, Sir.`
            : `Preparing SMS to ${cleanPhone}, Sir.`),
    };
  }

  // PHONE CALL INTENT
  // Examples:
  // "Call 9876543210"
  // "Dial 9876543210"
  // "Call +919876543210"
  // "9876543210 ko call lagao"
  if (/\b(?:call|dial)\b|call\s+(?:karo|lagao|karna|kar)\b/i.test(trimmed)) {
    const phoneMatch = trimmed.match(phoneRegex);
    if (!phoneMatch) {
      // User called a contact name without providing digits
      return {
        type: 'conversation',
        reply: 'Sir, I do not have access to your contacts for privacy reasons. Please provide the phone number to call.',
      };
    }

    const cleanPhone = phoneMatch[0].replace(/[\s\-()]/g, '');
    return {
      type: 'action',
      action: 'make_call',
      phoneNumber: cleanPhone,
      reply: fallbackReply && !fallbackReply.startsWith('{')
        ? fallbackReply
        : (trimmed.toLowerCase().includes('kar') || trimmed.toLowerCase().includes('lagao')
            ? `${cleanPhone} ko call mila raha hoon, Sir.`
            : `Opening dialer for ${cleanPhone}, Sir.`),
    };
  }

  return null;
}

// Chat endpoint
app.post('/api/chat', async (req, res) => {
  try {
    const { message, history } = req.body;

    if (!message || typeof message !== 'string' || message.trim() === '') {
      return res.status(400).json({ error: 'Message cannot be empty, Sir.' });
    }

    // Refresh genAI instance if env variable updated during runtime
    const activeApiKey = process.env.GEMINI_API_KEY;
    if (!genAI && activeApiKey && activeApiKey !== 'your_gemini_api_key_here') {
      genAI = new GoogleGenerativeAI(activeApiKey);
    }

    if (!genAI) {
      return res.status(503).json({
        reply:
          'Sir, the Gemini API key is missing on the backend. Please add your GEMINI_API_KEY in the backend/.env file to initialize my cognitive systems.',
        configured: false,
      });
    }

    // Build normalized, validated context history for Gemini
    const formattedHistory = buildGeminiHistory(history, message);

    console.log(`[/api/chat] Incoming user message: "${message}"`);

    // If message is a clear rule intent, we can also ensure instant response if Gemini quota is exhausted
    const executeChatWithRetry = async (modelToUse, retries = 2) => {
      for (let attempt = 1; attempt <= retries; attempt++) {
        try {
          const model = genAI.getGenerativeModel({
            model: modelToUse,
            systemInstruction: JARVIS_SYSTEM_INSTRUCTION,
          });

          const chat = model.startChat({
            history: formattedHistory,
          });

          // 15 second timeout to prevent indefinite hangs on network hiccups
          const result = await Promise.race([
            chat.sendMessage(message),
            new Promise((_, reject) =>
              setTimeout(() => reject(new Error('Network timeout reaching Google AI')), 15000)
            ),
          ]);
          const response = await result.response;
          return response.text();
        } catch (err) {
          console.warn(`Attempt ${attempt} with ${modelToUse} failed:`, err.message);
          // If quota exhausted (429), don't waste time retrying identical free tier limits
          if (err.status === 429 || (err.message && err.message.includes('429'))) {
            throw err;
          }
          if (attempt === retries) throw err;
          // Wait 1 second before retrying
          await new Promise((r) => setTimeout(r, 1000));
        }
      }
    };

    let replyText = '';
    let usedModel = MODEL_NAME;

    try {
      replyText = await executeChatWithRetry(MODEL_NAME);
    } catch (primaryError) {
      const isQuotaExceeded = primaryError.status === 429 || (primaryError.message && primaryError.message.includes('429'));
      if (!isQuotaExceeded) {
        console.warn(`Primary model ${MODEL_NAME} failed. Testing fallbacks...`);
        const fallbackCandidates = ['gemini-3.5-flash', 'gemini-3.8-flash'].filter(
          (m) => m !== MODEL_NAME
        );

        for (const fallback of fallbackCandidates) {
          try {
            replyText = await executeChatWithRetry(fallback, 1);
            usedModel = fallback;
            break;
          } catch (e) {
            // continue
          }
        }
      }

      if (!replyText) {
        throw primaryError;
      }
    }

    replyText = replyText || 'All systems operational, Sir.';

    // Clean up excessive markdown formatting that impairs TTS flow
    replyText = replyText
      .replace(/\*\*(.*?)\*\*/g, '$1') // remove bold
      .replace(/\*(.*?)\*/g, '$1')     // remove italic
      .replace(/^#+\s+/gm, '')         // remove heading markers
      .trim();

    // Parse response for structured actions or conversation
    const parsedResult = parseAiActionResponse(replyText, message);
    console.log(`[/api/chat] Successfully parsed response: type=${parsedResult.type}, action=${parsedResult.action}, app=${parsedResult.app}, phone=${parsedResult.phoneNumber}`);

    return res.json({
      type: parsedResult.type,
      action: parsedResult.action,
      query: parsedResult.query,
      app: parsedResult.app,
      phoneNumber: parsedResult.phoneNumber,
      message: parsedResult.message,
      reply: parsedResult.reply,
      model: usedModel,
    });
  } catch (error) {
    console.error('JARVIS Chat Error:', error.message || error);

    // If an action command was issued, execute via rule intent even during quota limits or network outages
    const userMessage = req.body.message;
    const ruleAction = matchActionIntent(userMessage);
    if (ruleAction) {
      console.log(`[/api/chat] Fallback rule engine matched action: ${ruleAction.action}`);
      return res.json({
        type: ruleAction.type,
        action: ruleAction.action,
        query: ruleAction.query,
        app: ruleAction.app,
        phoneNumber: ruleAction.phoneNumber,
        message: ruleAction.message,
        reply: ruleAction.reply,
        model: 'jarvis-rule-intent-engine',
      });
    }

    const isQuota = error.status === 429 || (error.message && error.message.includes('429'));
    if (isQuota) {
      return res.json({
        type: 'conversation',
        reply: 'Apologies, Sir. My Gemini cognitive quota for today has reached its daily limit. However, all Mickey device action commands (Calling, SMS, WhatsApp, and App controls) remain fully functional.',
        model: 'mickey-offline-assistant',
      });
    }

    return res.status(500).json({
      reply: 'Apologies, Sir. I encountered a momentary disturbance in my cognitive processing. Please check connection and try again.',
      error: error.message,
    });
  }
});

import { fileURLToPath } from 'node:url';

const isMainModule = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isMainModule) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`===============================================`);
    console.log(`⚡ M.I.C.K.E.Y. Core Server is Online`);
    console.log(`⚡ Listening on port ${PORT} (0.0.0.0)`);
    console.log(`⚡ API Key Configured: ${Boolean(GEMINI_API_KEY && GEMINI_API_KEY !== 'your_gemini_api_key_here')}`);
    console.log(`⚡ Ready for POCO M7 Plus & Local Connections`);
    console.log(`===============================================`);
  });
}

export default app;

