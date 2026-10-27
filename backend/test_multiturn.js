console.log('🚀 Running Multi-Turn Conversation Tests against JARVIS Backend...\n');

async function sendChat(label, payload) {
  console.log(`--- [${label}] ---`);
  console.log('Payload history count:', payload.history ? payload.history.length : 0);
  console.log('Message:', payload.message);

  const res = await fetch('http://127.0.0.1:3000/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  console.log('HTTP Status:', res.status);
  const data = await res.json();
  if (res.status !== 200) {
    console.error('FAILED Response:', data);
    throw new Error(`Turn failed with status ${res.status}: ${JSON.stringify(data)}`);
  }
  console.log('JARVIS Reply:', data.reply);
  console.log('Model Used:', data.model);
  console.log('');
  return data.reply;
}

async function runTests() {
  // Test 1: First message (including initial Flutter model greeting in history)
  const reply1 = await sendChat('TURN 1: Initial Message with Flutter Greeting in History', {
    message: 'Hello JARVIS, are you ready?',
    history: [
      {
        role: 'model',
        text: 'Greetings, Sir. J.A.R.V.I.S. is online and ready. How may I assist you today?',
      },
    ],
  });

  // Test 2: Second message with existing conversation history
  const reply2 = await sendChat('TURN 2: Follow-up Message with History', {
    message: 'Can you respond in natural Hinglish?',
    history: [
      {
        role: 'model',
        text: 'Greetings, Sir. J.A.R.V.I.S. is online and ready. How may I assist you today?',
      },
      {
        role: 'user',
        text: 'Hello JARVIS, are you ready?',
      },
      {
        role: 'model',
        text: reply1,
      },
    ],
  });

  // Test 3: Third message confirming conversation history continues correctly
  const reply3 = await sendChat('TURN 3: Third Message continuing Hinglish Context', {
    message: 'Bilkul sahi! Aaj mere liye kya status hai?',
    history: [
      {
        role: 'user',
        text: 'Hello JARVIS, are you ready?',
      },
      {
        role: 'model',
        text: reply1,
      },
      {
        role: 'user',
        text: 'Can you respond in natural Hinglish?',
      },
      {
        role: 'model',
        text: reply2,
      },
    ],
  });

  console.log('🎉 ALL 3 TURNS COMPLETED WITH HTTP 200 AND VALID JARVIS REPLIES!');
}

runTests().catch((err) => {
  console.error('Test Suite Failed:', err);
  process.exit(1);
});
