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

// System prompt defining JARVIS personality & bilingual English/Hinglish capability
const JARVIS_SYSTEM_INSTRUCTION = `You are J.A.R.V.I.S., an advanced, highly intelligent, calm, loyal, and witty personal AI assistant created for Sir (Rihan).
Your persona is inspired by Tony Stark's JARVIS: composed, polite, resourceful, and sharp.

Core conversational rules:
1. Tone: Professional yet warm, confident, respectful, addressing the user as "Sir" naturally when appropriate.
2. Bilingual Mastery:
   - If the user speaks or writes in English, reply in articulate, natural English.
   - If the user speaks or writes in Hinglish (Hindi written in Roman script, e.g. "kya haal hai", "aaj ka weather kaisa hai"), reply fluently in natural conversational Hinglish (e.g. "Main bilkul theek hoon, Sir. Bataiye aaj kya karna hai?").
   - If user mixes English and Hindi, match their vibe effortlessly.
3. Voice & Speech Optimized:
   - Your response will be spoken aloud using Text-to-Speech (TTS).
   - Keep answers crisp, clear, and direct.
   - Avoid markdown formatting such as asterisks (**bold**), hashtags (###), bullet symbols, or code blocks unless explicitly requested by the user, as these sound jarring when read aloud by TTS.
4. Privacy First:
   - You only operate on the user's explicit instructions and conversation.
   - Always maintain a secure, privacy-first attitude.

ACTION DISPATCH PROTOCOL:
You can control specific phone capabilities when the user commands an action.
Supported Android actions:
- google_search: Search on Google. Parameters: "query" (string, search terms without filler words).
- youtube_search: Search on YouTube. Parameters: "query" (string, video search terms without filler words).
- open_app: Launch a supported app. Allowed apps: "chrome", "youtube", "maps", "settings".

When the user asks you to perform one of these actions (in English or Hinglish, e.g. "Google par ... search kar", "YouTube par ... search karo", "Chrome open kar", "Settings kholo", "Google Maps open kar"):
You MUST respond with a single JSON object in this exact schema:
{
  "type": "action",
  "action": "google_search" | "youtube_search" | "open_app",
  "query": "<clean search query string if search action>",
  "app": "chrome" | "youtube" | "maps" | "settings" (if open_app),
  "reply": "<Crisp verbal confirmation to speak aloud to Sir, e.g. 'Searching Google for React tutorials, Sir.' or 'Opening YouTube, Sir.' or in Hinglish if asked in Hinglish>"
}

For all other messages (greetings, general chat, normal conversation, questions where no action is requested):
Reply with normal conversational text for JARVIS (or JSON {"type": "conversation", "reply": "..."}).`;

// In-memory generative AI client instance
let genAI = null;
if (GEMINI_API_KEY && GEMINI_API_KEY !== 'your_gemini_api_key_here') {
  genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
}

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    assistant: 'J.A.R.V.I.S. Core',
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
 */
export function parseAiActionResponse(rawAiReply, userMessage = '') {
  const allowedActions = ['google_search', 'youtube_search', 'open_app'];
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
 * Regex-based intent matcher for bilingual English & Hinglish commands
 */
export function matchActionIntent(userText, fallbackReply = '') {
  if (!userText) return null;
  const trimmed = userText.trim();

  // YouTube search: "YouTube par latest songs search kar", "search latest songs on youtube", "youtube search latest songs"
  const ytMatchHinglish = trimmed.match(/(?:youtube|yt)\s+(?:par|pe)\s+(.+?)\s+(?:search\s*(?:kar|karo|karna|kardo)?|dhoondo)/i);
  const ytMatchEng = trimmed.match(/(?:search|find)\s+(.+?)\s+(?:on|in)\s+youtube/i) ||
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

  // Google search: "Google par React tutorials search kar", "search react tutorials on google", "google search react tutorials"
  const googleMatchHinglish = trimmed.match(/(?:google)\s+(?:par|pe)\s+(.+?)\s+(?:search\s*(?:kar|karo|karna|kardo)?|dhoondo)/i);
  const googleMatchEng = trimmed.match(/(?:search|find)\s+(.+?)\s+(?:on|in)\s+google/i) ||
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


    // Helper for calling Gemini with retry on transient network/demand spikes
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
      console.warn(`Primary model ${MODEL_NAME} failed. Testing fallbacks...`);
      const fallbackCandidates = ['gemini-3.5-flash', 'gemini-3.8-flash'].filter(
        (m) => m !== MODEL_NAME
      );

      let fallbackSuccess = false;
      for (const fallback of fallbackCandidates) {
        try {
          replyText = await executeChatWithRetry(fallback, 1);
          usedModel = fallback;
          fallbackSuccess = true;
          break;
        } catch (e) {
          // continue
        }
      }

      if (!fallbackSuccess) {
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

    return res.json({
      type: parsedResult.type,
      action: parsedResult.action,
      query: parsedResult.query,
      app: parsedResult.app,
      reply: parsedResult.reply,
      model: usedModel,
    });
  } catch (error) {
    console.error('JARVIS Chat Error:', error);

    // If an action command was issued, execute via rule intent even during quota limits or network outages
    const userMessage = req.body.message;
    const ruleAction = matchActionIntent(userMessage);
    if (ruleAction) {
      return res.json({
        type: ruleAction.type,
        action: ruleAction.action,
        query: ruleAction.query,
        app: ruleAction.app,
        reply: ruleAction.reply,
        model: 'jarvis-rule-intent-engine',
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
    console.log(`⚡ J.A.R.V.I.S. Core Server is Online`);
    console.log(`⚡ Listening on port ${PORT} (0.0.0.0)`);
    console.log(`⚡ API Key Configured: ${Boolean(GEMINI_API_KEY && GEMINI_API_KEY !== 'your_gemini_api_key_here')}`);
    console.log(`⚡ Ready for POCO M7 Plus & Local Connections`);
    console.log(`===============================================`);
  });
}

export default app;

