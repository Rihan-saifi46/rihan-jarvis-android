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
   - Always maintain a secure, privacy-first attitude.`;

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

    // Build context history (limit to last 6 messages for efficiency & privacy)
    const formattedHistory = [];
    if (Array.isArray(history)) {
      const recent = history.slice(-6);
      for (const item of recent) {
        if (item.role && item.text) {
          formattedHistory.push({
            role: item.role === 'user' ? 'user' : 'model',
            parts: [{ text: item.text }],
          });
        }
      }
    }

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

    return res.json({
      reply: replyText,
      model: usedModel,
    });
  } catch (error) {
    console.error('JARVIS Chat Error:', error);

    return res.status(500).json({
      reply: 'Apologies, Sir. I encountered a momentary disturbance in my cognitive processing. Please check connection and try again.',
      error: error.message,
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`===============================================`);
  console.log(`⚡ J.A.R.V.I.S. Core Server is Online`);
  console.log(`⚡ Listening on port ${PORT} (0.0.0.0)`);
  console.log(`⚡ API Key Configured: ${Boolean(GEMINI_API_KEY && GEMINI_API_KEY !== 'your_gemini_api_key_here')}`);
  console.log(`⚡ Ready for POCO M7 Plus & Local Connections`);
  console.log(`===============================================`);
});
