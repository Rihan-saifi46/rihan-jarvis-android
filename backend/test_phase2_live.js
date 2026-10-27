console.log('🚀 Testing Phase 2 Commands against Live Backend...\n');

const testCases = [
  {
    name: 'Command 1: Google Search (Hinglish)',
    message: 'Google par React tutorials search kar.',
    expectedType: 'action',
    expectedAction: 'google_search',
    expectedQuery: 'React tutorials',
  },
  {
    name: 'Command 2: YouTube Search (Hinglish)',
    message: 'YouTube par latest songs search kar.',
    expectedType: 'action',
    expectedAction: 'youtube_search',
    expectedQuery: 'latest songs',
  },
  {
    name: 'Command 3: Open Chrome',
    message: 'Chrome open kar.',
    expectedType: 'action',
    expectedAction: 'open_app',
    expectedApp: 'chrome',
  },
  {
    name: 'Command 4: Open YouTube',
    message: 'YouTube open kar.',
    expectedType: 'action',
    expectedAction: 'open_app',
    expectedApp: 'youtube',
  },
  {
    name: 'Command 5: Normal Conversation',
    message: 'Hello Jarvis, how are you?',
    expectedType: 'conversation',
  },
];

async function run() {
  let passed = 0;

  for (let i = 0; i < testCases.length; i++) {
    const tc = testCases[i];
    console.log(`--- [Test ${i + 1}: ${tc.name}] ---`);
    console.log(`Input Message: "${tc.message}"`);

    const res = await fetch('http://127.0.0.1:3000/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: tc.message, history: [] }),
    });

    console.log('HTTP Status:', res.status);
    const data = await res.json();
    console.log('Response Payload:', JSON.stringify(data, null, 2));

    if (data.type !== tc.expectedType) {
      console.error(`❌ Expected type "${tc.expectedType}" but got "${data.type}"`);
    } else if (tc.expectedAction && data.action !== tc.expectedAction) {
      console.error(`❌ Expected action "${tc.expectedAction}" but got "${data.action}"`);
    } else if (tc.expectedQuery && !data.query?.toLowerCase().includes(tc.expectedQuery.toLowerCase())) {
      console.error(`❌ Expected query containing "${tc.expectedQuery}" but got "${data.query}"`);
    } else if (tc.expectedApp && data.app !== tc.expectedApp) {
      console.error(`❌ Expected app "${tc.expectedApp}" but got "${data.app}"`);
    } else {
      console.log(`✅ Passed: Correctly resolved as ${data.type} [${data.action || 'chat'}]`);
      passed++;
    }
    console.log('');
  }

  console.log(`===============================================`);
  console.log(`Test Results: ${passed} / ${testCases.length} Passed`);
  console.log(`===============================================`);

  if (passed !== testCases.length) {
    process.exit(1);
  }
}

run().catch((e) => {
  console.error('Test run error:', e);
  process.exit(1);
});
