import assert from 'node:assert';
import { parseAiActionResponse, matchActionIntent } from './server.js';

console.log('🧪 Testing Phase 2 Action Parser and Intent Matcher...\n');

// Test 1: Google search in Hinglish
{
  const cmd = "Jarvis, Google par React tutorials search kar.";
  const res = parseAiActionResponse('Searching Google for React tutorials, Sir.', cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'google_search');
  assert.strictEqual(res.query, 'React tutorials');
  console.log('✅ Test 1 Passed: Google search intent recognized ("React tutorials")');
}

// Test 2: YouTube search in Hinglish
{
  const cmd = "YouTube par latest songs search kar.";
  const res = parseAiActionResponse('Searching YouTube for latest songs, Sir.', cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'youtube_search');
  assert.strictEqual(res.query, 'latest songs');
  console.log('✅ Test 2 Passed: YouTube search intent recognized ("latest songs")');
}

// Test 3: Chrome open
{
  const cmd = "Chrome open kar.";
  const res = parseAiActionResponse('Opening Google Chrome, Sir.', cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_app');
  assert.strictEqual(res.app, 'chrome');
  console.log('✅ Test 3 Passed: Chrome app launch recognized');
}

// Test 4: YouTube open
{
  const cmd = "YouTube open kar.";
  const res = parseAiActionResponse('Opening YouTube, Sir.', cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_app');
  assert.strictEqual(res.app, 'youtube');
  console.log('✅ Test 4 Passed: YouTube app launch recognized');
}

// Test 5: Google Maps open
{
  const cmd = "Google Maps open kar.";
  const res = parseAiActionResponse('Opening Google Maps, Sir.', cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_app');
  assert.strictEqual(res.app, 'maps');
  console.log('✅ Test 5 Passed: Google Maps launch recognized');
}

// Test 6: Settings open
{
  const cmd = "Settings open kar.";
  const res = parseAiActionResponse('Opening Settings, Sir.', cmd);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_app');
  assert.strictEqual(res.app, 'settings');
  console.log('✅ Test 6 Passed: Settings launch recognized');
}

// Test 7: Normal conversation (no action)
{
  const cmd = "Hello Jarvis, how are you?";
  const res = parseAiActionResponse('I am doing well, Sir. All systems operating at peak efficiency.', cmd);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  console.log('✅ Test 7 Passed: Normal conversation does not trigger action');
}

// Test 8: Structured JSON from Gemini response
{
  const geminiJson = JSON.stringify({
    type: 'action',
    action: 'youtube_search',
    query: 'Flutter tutorial 2026',
    reply: 'Searching YouTube for Flutter tutorials, Sir.'
  });
  const res = parseAiActionResponse(geminiJson, 'Find flutter tutorial on youtube');
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'youtube_search');
  assert.strictEqual(res.query, 'Flutter tutorial 2026');
  console.log('✅ Test 8 Passed: Raw JSON response parsed accurately');
}

// Test 9: Markdown-wrapped JSON from Gemini response
{
  const geminiMarkdown = "```json\n" + JSON.stringify({
    type: 'action',
    action: 'open_app',
    app: 'chrome',
    reply: 'Opening Chrome now, Sir.'
  }) + "\n```";
  const res = parseAiActionResponse(geminiMarkdown, 'open chrome');
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_app');
  assert.strictEqual(res.app, 'chrome');
  console.log('✅ Test 9 Passed: Markdown-fenced JSON handled cleanly');
}

// Test 10: Disallowed app rejected safely
{
  const cmd = "Instagram open kar.";
  const res = parseAiActionResponse('Opening Instagram, Sir.', cmd);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  console.log('✅ Test 10 Passed: Disallowed app safely rejected (treated as conversation)');
}

console.log('\n🎉 ALL 10 ACTION PARSER UNIT TESTS PASSED!\n');
