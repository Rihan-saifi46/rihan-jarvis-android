import assert from 'node:assert';
import { buildGeminiHistory } from './server.js';

console.log('🧪 Testing buildGeminiHistory implementation...\n');

// Test 1: Empty history
{
  const result = buildGeminiHistory([], 'Hello');
  assert.deepStrictEqual(result, [], 'Empty history should return empty array');
  console.log('✅ Test 1 Passed: Empty history returns []');
}

// Test 2: History starting with model message (JARVIS initial greeting)
{
  const rawHistory = [
    { role: 'model', text: 'Greetings, Sir. J.A.R.V.I.S. is online and ready.' }
  ];
  const result = buildGeminiHistory(rawHistory, 'Hello JARVIS');
  assert.deepStrictEqual(result, [], 'Leading model message should be stripped');
  console.log('✅ Test 2 Passed: Leading model message stripped, returns []');
}

// Test 3: History with leading model message followed by full turns
{
  const rawHistory = [
    { role: 'model', text: 'Greetings, Sir.' },
    { role: 'user', text: 'Status report' },
    { role: 'assistant', text: 'All systems green, Sir.' }
  ];
  const result = buildGeminiHistory(rawHistory, 'Thank you');
  assert.strictEqual(result.length, 2);
  assert.strictEqual(result[0].role, 'user');
  assert.strictEqual(result[0].parts[0].text, 'Status report');
  assert.strictEqual(result[1].role, 'model');
  assert.strictEqual(result[1].parts[0].text, 'All systems green, Sir.');
  console.log('✅ Test 3 Passed: Leading model stripped, assistant mapped to model, first is user');
}

// Test 4: Deduplication of current user message if passed at the end of history
{
  const rawHistory = [
    { role: 'user', text: 'Who made you?' },
    { role: 'model', text: 'Tony Stark inspired, Sir.' },
    { role: 'user', text: 'Can you speak Hinglish?' } // matches current message
  ];
  const result = buildGeminiHistory(rawHistory, 'Can you speak Hinglish?');
  assert.strictEqual(result.length, 2);
  assert.strictEqual(result[0].role, 'user');
  assert.strictEqual(result[1].role, 'model');
  console.log('✅ Test 4 Passed: Current user message not duplicated in history');
}

// Test 5: Strict alternation with consecutive messages of the same role
{
  const rawHistory = [
    { role: 'user', text: 'Part 1' },
    { role: 'user', text: 'Part 2' },
    { role: 'model', text: 'Reply A' },
    { role: 'model', text: 'Reply B' }
  ];
  const result = buildGeminiHistory(rawHistory, 'Next question');
  assert.strictEqual(result.length, 2);
  assert.strictEqual(result[0].role, 'user');
  assert.strictEqual(result[0].parts[0].text, 'Part 1\nPart 2');
  assert.strictEqual(result[1].role, 'model');
  assert.strictEqual(result[1].parts[0].text, 'Reply A\nReply B');
  console.log('✅ Test 5 Passed: Consecutive same-role messages merged into valid alternating turns');
}

console.log('\n🎉 All buildGeminiHistory unit tests passed successfully!\n');
