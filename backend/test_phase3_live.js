import assert from 'node:assert';

console.log('🧪 Testing Live Phase 3 API endpoint: POST http://127.0.0.1:3000/api/chat...\n');

async function testEndpoint(message) {
  const response = await fetch('http://127.0.0.1:3000/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message, history: [] })
  });
  return await response.json();
}

// Live Test 1: Call command
{
  const res = await testEndpoint("Call 9876543210");
  console.log('Live Call Response:', res);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'make_call');
  assert.strictEqual(res.phoneNumber, '9876543210');
  console.log('✅ Live Test 1 Passed: make_call returned from API\n');
}

// Live Test 2: SMS command
{
  const res = await testEndpoint("Send SMS to 9876543210 saying I'll be late");
  console.log('Live SMS Response:', res);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'send_sms');
  assert.strictEqual(res.phoneNumber, '9876543210');
  assert.strictEqual(res.message, "I'll be late");
  console.log('✅ Live Test 2 Passed: send_sms returned from API\n');
}

// Live Test 3: WhatsApp command with country code
{
  const res = await testEndpoint("Open WhatsApp and message +919876543210 saying Hello");
  console.log('Live WhatsApp Response:', res);
  assert.strictEqual(res.type, 'action');
  assert.strictEqual(res.action, 'open_whatsapp');
  assert.strictEqual(res.phoneNumber, '919876543210');
  assert.strictEqual(res.message, "Hello");
  console.log('✅ Live Test 3 Passed: open_whatsapp returned from API\n');
}

// Live Test 4: Privacy enforcement for contact names
{
  const res = await testEndpoint("Call Sam");
  console.log('Live Privacy Call Response:', res);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  assert.match(res.reply, /privacy reasons|contacts/i);
  console.log('✅ Live Test 4 Passed: Privacy preserved for contact name\n');
}

// Live Test 5: WhatsApp country code requirement
{
  const res = await testEndpoint("Open WhatsApp and message 9876543210 saying Hello");
  console.log('Live WhatsApp Country Code Response:', res);
  assert.strictEqual(res.type, 'conversation');
  assert.strictEqual(res.action, undefined);
  assert.match(res.reply, /country code/i);
  console.log('✅ Live Test 5 Passed: WhatsApp country code prompt working\n');
}

console.log('🎉 ALL 5 LIVE API ENDPOINT TESTS PASSED!\n');
