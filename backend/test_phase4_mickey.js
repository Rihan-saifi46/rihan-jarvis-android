import { matchActionIntent } from './server.js';

console.log('🧪 Testing Phase 4 Mickey Wake Word & Voice Intent Matching...\n');

let passed = 0;
let failed = 0;

function assert(condition, testName, details = '') {
  if (condition) {
    console.log(`✅ ${testName}`);
    passed++;
  } else {
    console.error(`❌ ${testName} FAILED: ${details}`);
    failed++;
  }
}

// 1. Standalone wake word produces natural response
const r1 = matchActionIntent('Hey Mickey');
assert(
  r1?.type === 'conversation' && r1?.reply.includes("Yes Sir? I'm listening."),
  'Test 1: "Hey Mickey" returns natural conversational response ("Yes Sir? I\'m listening.")',
  JSON.stringify(r1)
);

const r2 = matchActionIntent('mickey');
assert(
  r2?.type === 'conversation' && r2?.reply.includes("Yes Sir? I'm listening."),
  'Test 2: "mickey" (lowercase) returns wake word acknowledgment',
  JSON.stringify(r2)
);

const r3 = matchActionIntent('suno mickey');
assert(
  r3?.type === 'conversation' && r3?.reply.includes("Yes Sir? I'm listening."),
  'Test 3: "suno mickey" (Hinglish) returns wake word acknowledgment',
  JSON.stringify(r3)
);

// 2. Wake word prefix stripped from app commands
const r4 = matchActionIntent('Hey Mickey, open YouTube');
assert(
  r4?.action === 'open_app' && r4?.app === 'youtube',
  'Test 4: "Hey Mickey, open YouTube" launches YouTube',
  JSON.stringify(r4)
);

const r5 = matchActionIntent('Hey Mickey open chrome');
assert(
  r5?.action === 'open_app' && r5?.app === 'chrome',
  'Test 5: "Hey Mickey open chrome" launches Chrome',
  JSON.stringify(r5)
);

// 3. Wake word prefix stripped from call commands
const r6 = matchActionIntent('Hey Mickey, call 9876543210');
assert(
  r6?.action === 'make_call' && r6?.phoneNumber === '9876543210',
  'Test 6: "Hey Mickey, call 9876543210" initiates phone call',
  JSON.stringify(r6)
);

// 4. Wake word prefix stripped from Google search
const r7 = matchActionIntent("Hey Mickey, search Google for today's news");
assert(
  r7?.action === 'google_search' && r7?.query === "today's news",
  'Test 7: "Hey Mickey, search Google for today\'s news" searches Google',
  JSON.stringify(r7)
);

const r8 = matchActionIntent('Hey Mickey Google par AI news search kar');
assert(
  r8?.action === 'google_search' && r8?.query === 'AI news',
  'Test 8: "Hey Mickey Google par AI news search kar" Hinglish Google search',
  JSON.stringify(r8)
);

// 5. Wake word prefix stripped from SMS
const r9 = matchActionIntent("Hey Mickey, send SMS to 9876543210 saying I'll be late");
assert(
  r9?.action === 'send_sms' && r9?.phoneNumber === '9876543210' && r9?.message === "I'll be late",
  'Test 9: "Hey Mickey, send SMS to 9876543210 saying I\'ll be late" prepares SMS',
  JSON.stringify(r9)
);

// 6. Wake word prefix stripped from WhatsApp
const r10 = matchActionIntent('Hey Mickey open WhatsApp and message +919876543210 saying test');
assert(
  r10?.action === 'open_whatsapp' && r10?.phoneNumber === '919876543210' && r10?.message === 'test',
  'Test 10: "Hey Mickey open WhatsApp and message +919876543210 saying test" prepares WhatsApp',
  JSON.stringify(r10)
);

// 7. Normal conversation does not trigger an action
const r11 = matchActionIntent('Hey Mickey, what is the weather today?');
assert(
  r11 === null,
  'Test 11: "Hey Mickey, what is the weather today?" passes through to conversational AI',
  JSON.stringify(r11)
);

console.log(`\n========================================`);
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log(`========================================\n`);

if (failed > 0) {
  process.exit(1);
}
