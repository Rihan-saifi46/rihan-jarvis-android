import assert from 'node:assert';
import { parseAiActionResponse, matchActionIntent } from './server.js';

console.log('🧪 Testing Phase 3 Phone Actions (Calling, SMS, WhatsApp) & Privacy...\n');

// 1. Phone Call: Standard English
{
  const cmd = "Call 9876543210";
  const res = parseAiActionResponse('Opening dialer for 9876543210, Sir.', cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'make_call');
  assert.strictEqual(res.phoneNumber, '9876543210');
  console.log('✅ Test 1 Passed: Call with 10-digit number recognized');
}

// 2. Phone Call: International format
{
  const cmd = "Call +919876543210";
  const res = parseAiActionResponse('Opening dialer for +919876543210, Sir.', cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'make_call');
  assert.strictEqual(res.phoneNumber, '+919876543210');
  console.log('✅ Test 2 Passed: Call with international +91 prefix recognized');
}

// 3. Phone Call: Hinglish
{
  const cmd = "9876543210 ko call lagao";
  const res = parseAiActionResponse('9876543210 ko call mila raha hoon, Sir.', cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'make_call');
  assert.strictEqual(res.phoneNumber, '9876543210');
  console.log('✅ Test 3 Passed: Hinglish call command recognized');
}

// 4. Privacy: Call contact name without number rejected
{
  const cmd = "Call Sam";
  const res = parseAiActionResponse('I will check contacts', cmd);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  assert.match(res.reply, /privacy reasons|access to your contacts/i);
  console.log('✅ Test 4 Passed: Contact name call rejected for privacy');
}

// 5. SMS: Standard English with "saying"
{
  const cmd = "Send SMS to 9876543210 saying I'll be late";
  const res = parseAiActionResponse("Preparing SMS to 9876543210, Sir.", cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'send_sms');
  assert.strictEqual(res.phoneNumber, '9876543210');
  assert.strictEqual(res.message, "I'll be late");
  console.log('✅ Test 5 Passed: SMS command with "saying" parsed correctly');
}

// 6. SMS: Colon format
{
  const cmd = "SMS to 9876543210: I'm on my way";
  const res = parseAiActionResponse("Preparing SMS to 9876543210, Sir.", cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'send_sms');
  assert.strictEqual(res.phoneNumber, '9876543210');
  assert.strictEqual(res.message, "I'm on my way");
  console.log('✅ Test 6 Passed: SMS colon format parsed correctly');
}

// 7. SMS: Hinglish
{
  const cmd = "9876543210 ko SMS bhejo message I will be late";
  const res = parseAiActionResponse("SMS bhejo", cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'send_sms');
  assert.strictEqual(res.phoneNumber, '9876543210');
  assert.strictEqual(res.message, "I will be late");
  console.log('✅ Test 7 Passed: Hinglish SMS command recognized');
}

// 8. Privacy: SMS contact name without number rejected
{
  const cmd = "Send SMS to Dad saying hello";
  const res = parseAiActionResponse('Sending message', cmd);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  assert.match(res.reply, /privacy reasons|access to your contacts/i);
  console.log('✅ Test 8 Passed: Contact name SMS rejected for privacy');
}

// 9. SMS without message prompts for clarification
{
  const cmd = "Send SMS to 9876543210";
  const res = parseAiActionResponse('Preparing SMS', cmd);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  assert.match(res.reply, /what message would you like/i);
  console.log('✅ Test 9 Passed: SMS missing message prompts clarification');
}

// 10. WhatsApp: International number with country code
{
  const cmd = "Open WhatsApp and message +919876543210 saying Hello";
  const res = parseAiActionResponse("Opening WhatsApp, Sir.", cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_whatsapp');
  assert.strictEqual(res.phoneNumber, '919876543210');
  assert.strictEqual(res.message, "Hello");
  console.log('✅ Test 10 Passed: WhatsApp with country code +91 recognized');
}

// 11. WhatsApp: Colon format
{
  const cmd = "WhatsApp message to +919876543210: I'm on my way";
  const res = parseAiActionResponse("Opening WhatsApp, Sir.", cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_whatsapp');
  assert.strictEqual(res.phoneNumber, '919876543210');
  assert.strictEqual(res.message, "I'm on my way");
  console.log('✅ Test 11 Passed: WhatsApp colon format recognized');
}

// 12. WhatsApp: 10-digit number without country code prompts for clarification
{
  const cmd = "Open WhatsApp and message 9876543210 saying Hello";
  const res = parseAiActionResponse("Opening WhatsApp, Sir.", cmd);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  assert.match(res.reply, /country code/i);
  console.log('✅ Test 12 Passed: WhatsApp missing country code prompts clarification');
}

// 13. Privacy: WhatsApp contact name without number rejected
{
  const cmd = "WhatsApp message to John saying Hello";
  const res = parseAiActionResponse("Opening WhatsApp, Sir.", cmd);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  assert.match(res.reply, /privacy reasons|access to your contacts/i);
  console.log('✅ Test 13 Passed: Contact name WhatsApp rejected for privacy');
}

// 14. WhatsApp without message prompts for clarification
{
  const cmd = "Open WhatsApp and message +919876543210";
  const res = parseAiActionResponse("Opening WhatsApp, Sir.", cmd);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  assert.match(res.reply, /what message would you like/i);
  console.log('✅ Test 14 Passed: WhatsApp missing message prompts clarification');
}

// 15. Raw JSON from Gemini: make_call
{
  const geminiJson = JSON.stringify({
    type: 'action',
    action: 'make_call',
    phoneNumber: '9876543210',
    reply: 'Opening dialer for 9876543210, Sir.'
  });
  const res = parseAiActionResponse(geminiJson, 'Call 9876543210');
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'make_call');
  assert.strictEqual(res.phoneNumber, '9876543210');
  console.log('✅ Test 15 Passed: Raw JSON make_call parsed accurately');
}

// 16. Raw JSON from Gemini: send_sms
{
  const geminiJson = JSON.stringify({
    type: 'action',
    action: 'send_sms',
    phoneNumber: '9876543210',
    message: "I'll be there in 5 minutes",
    reply: 'Preparing SMS to 9876543210, Sir.'
  });
  const res = parseAiActionResponse(geminiJson, 'SMS to 9876543210');
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'send_sms');
  assert.strictEqual(res.phoneNumber, '9876543210');
  assert.strictEqual(res.message, "I'll be there in 5 minutes");
  console.log('✅ Test 16 Passed: Raw JSON send_sms parsed accurately');
}

// 17. Raw JSON from Gemini: open_whatsapp
{
  const geminiJson = JSON.stringify({
    type: 'action',
    action: 'open_whatsapp',
    phoneNumber: '919876543210',
    message: 'Hello, are we still meeting?',
    reply: 'Opening WhatsApp conversation for 919876543210, Sir.'
  });
  const res = parseAiActionResponse(geminiJson, 'WhatsApp 919876543210');
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_whatsapp');
  assert.strictEqual(res.phoneNumber, '919876543210');
  assert.strictEqual(res.message, 'Hello, are we still meeting?');
  console.log('✅ Test 17 Passed: Raw JSON open_whatsapp parsed accurately');
}

// 18. Markdown-fenced JSON from Gemini
{
  const markdownJson = "```json\n" + JSON.stringify({
    type: 'action',
    action: 'open_whatsapp',
    phoneNumber: '919876543210',
    message: 'On my way!',
    reply: 'Opening WhatsApp, Sir.'
  }) + "\n```";
  const res = parseAiActionResponse(markdownJson, 'Message on whatsapp');
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_whatsapp');
  assert.strictEqual(res.phoneNumber, '919876543210');
  assert.strictEqual(res.message, 'On my way!');
  console.log('✅ Test 18 Passed: Markdown-fenced open_whatsapp handled cleanly');
}

console.log('\n🎉 ALL 18 PHASE 3 PHONE ACTIONS & PRIVACY TESTS PASSED!\n');
