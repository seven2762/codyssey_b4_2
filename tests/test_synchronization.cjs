'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(path.join(__dirname, '../visualizations/synchronization.html'), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script); // Validate the complete browser script's syntax.
const sandbox = {};
vm.createContext(sandbox);
vm.runInContext(script.slice(0, script.indexOf('const $=')), sandbox);
const build = sandbox.buildScenario;
for (const [kind, capacities] of [['mutex', [1]], ['semaphore', [1, 2, 3, 4]]]) {
  for (const capacity of capacities) {
    const frames = build(kind, capacity);
    for (const frame of frames) {
      const users = frame.tokens.filter(Boolean);
      assert.ok(users.length <= capacity);
      assert.equal(users.length, new Set(users).size, 'one token per task in this example');
      assert.equal(frame.tokens.length, capacity);
      assert.equal(frame.tasks.filter(t => t.status === 'running').length, users.length);
      assert.equal(frame.tasks.filter(t => t.status === 'waiting').length, frame.queue.length);
      for (const t of frame.tasks) {
        assert.equal(users.includes(t.name), t.status === 'running');
        assert.equal(frame.queue.includes(t.name), t.status === 'waiting');
      }
    }
    const final = frames.at(-1);
    assert.ok(final.tasks.every(t => t.status === 'done'));
    assert.ok(final.tokens.every(t => t === null));
    assert.equal(final.queue.length, 0);
    const peak = Math.max(...frames.map(f => f.tokens.filter(Boolean).length));
    assert.equal(peak, capacity);
    console.log(`PASS: ${kind}, capacity=${capacity}: exclusion, token conservation, queue and completion`);
  }
}
const conflict = build('deadlock', 2, false);
const blocked = conflict.at(-1);
assert.equal(blocked.deadlock, true);
assert.equal(blocked.locks.A, 'T1');
assert.equal(blocked.locks.B, 'T2');
assert.equal(blocked.tasks[0].wants, 'B');
assert.equal(blocked.tasks[1].wants, 'A');
assert.ok(blocked.tasks.every(t => t.status === 'waiting'));
assert.equal(JSON.stringify(conflict.at(-2).locks), JSON.stringify(blocked.locks));
assert.equal(JSON.stringify(conflict.at(-2).tasks), JSON.stringify(blocked.tasks));
console.log('PASS: deadlock: opposing ownership/waits, cycle and no progress');
const ordered = build('deadlock', 2, true);
assert.ok(ordered.every(f => !f.deadlock));
for (const f of ordered) {
  for (const t of f.tasks) {
    if (t.held.includes('B')) assert.ok(t.held.includes('A'), 'A must precede B');
    for (const key of t.held) assert.equal(f.locks[key], t.name);
  }
}
assert.ok(ordered.at(-1).tasks.every(t => t.status === 'done'));
assert.ok(Object.values(ordered.at(-1).locks).every(l => l === null));
console.log('PASS: consistent lock order: no cycle, all tasks complete, all locks returned');
assert.ok(!/<(?:script|link)[^>]+(?:src|href)=["']https?:/.test(html));
console.log('PASS: self-contained page and JavaScript syntax');
