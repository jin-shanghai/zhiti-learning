const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    viewport: { width: 1440, height: 980 },
    deviceScaleFactor: 1,
  });
  const base = 'http://127.0.0.1:8765/index.html';
  const output = path.resolve('docs/images');
  fs.mkdirSync(output, { recursive: true });

  await page.goto(base, { waitUntil: 'networkidle' });
  await page.screenshot({ path: path.join(output, 'zhiti-home.png') });

  await page.evaluate(() => {
    const now = Date.now();
    const history = {
      1: [{ at: now - 7200000, answer: 'A', ok: false }, { at: now - 3600000, answer: 'B', ok: true }],
      2: [{ at: now - 6900000, answer: 'A', ok: false }],
      3: [{ at: now - 6600000, answer: 'B', ok: true }],
      4: [{ at: now - 6300000, answer: 'D', ok: false }],
      5: [{ at: now - 6000000, answer: 'B', ok: true }],
      6: [{ at: now - 5700000, answer: 'A', ok: false }],
      J001: [{ at: now - 5400000, answer: 'A', ok: true }],
      J002: [{ at: now - 5100000, answer: 'A', ok: false }],
      J003: [{ at: now - 4800000, answer: 'A', ok: true }],
      J004: [{ at: now - 4500000, answer: 'A', ok: false }],
    };
    const demo = {
      version: 6,
      judgmentBankVersion: 'zhiti-demo-v1',
      history,
      bookmarks: [2, 4, 'J002'],
      multiQuestions: [],
      correctEver: { 1: true, 3: true, 5: true, J001: true, J003: true },
      session: null,
      exams: [],
      sessions: [{
        id: 'readme-demo', at: now - 3600000, name: '混合训练', mode: 'mixed',
        filter: null, kind: 'mixed', total: 10, answered: 10, correct: 5,
        wrongIds: [2, 4, 6, 'J002', 'J004'], unanswered: [],
        ids: [1, 2, 3, 4, 5, 6, 'J001', 'J002', 'J003', 'J004'],
        answers: { 1: 'B', 2: 'A', 3: 'B', 4: 'D', 5: 'B', 6: 'A', J001: 'A', J002: 'A', J003: 'A', J004: 'A' },
        startedAt: now - 4500000, durationMs: 900000,
      }],
      lastSessionId: 'readme-demo',
      comments: { 2: [{ id: 'demo-note', name: '我', text: '把相近概念并列比较，重点记录边界条件。', at: now - 3000000 }] },
      nickname: '我', seqCursor: 0, seqCursorJudge: 0, seqCursorMixed: 0,
      joinedAt: now - 86400000, legacyJudgments: [],
    };
    localStorage.setItem('zhiti_public_v1', JSON.stringify(demo));
  });
  await page.reload({ waitUntil: 'networkidle' });

  await page.evaluate(() => {
    startSession('choice', 'all');
    chooseAnswer('A');
  });
  await page.screenshot({ path: path.join(output, 'zhiti-practice.png') });

  await page.evaluate(() => setPage('report'));
  await page.screenshot({ path: path.join(output, 'zhiti-report.png') });

  await page.evaluate(() => setPage('settings'));
  await page.screenshot({ path: path.join(output, 'zhiti-data-settings.png') });

  await browser.close();
})();
