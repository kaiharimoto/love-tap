#!/usr/bin/env node
// tools/capture/shot.js — a screen out of the PWA, from a real browser.
//
//   node tools/capture/shot.js --url http://127.0.0.1:8799/ --out shot.png \
//        --width 480 --height 1040 --dpr 3 --wait 20000 --browser webkit
//
// WebKit is the browser that counts (it is the engine on the iPhone); Chromium is only for a
// quick look while building. Every capture reports what it saw go wrong, so a blank page is never
// mistaken for a screen.
const path = require('path');
const PW = path.join(__dirname, '..', '..', 'toolchain', 'pw', 'node_modules', 'playwright');
// always the pinned browsers bootstrap.sh installed, never whatever the image happens to carry
process.env.PLAYWRIGHT_BROWSERS_PATH = path.join(__dirname, '..', '..', 'toolchain', 'pw-browsers');
const { chromium, webkit } = require(PW);

function arg(name, dflt) {
  const i = process.argv.indexOf('--' + name);
  return i > 0 ? process.argv[i + 1] : dflt;
}
function flag(name) {
  return process.argv.includes('--' + name);
}

(async () => {
  const browserName = arg('browser', 'webkit');
  const width = parseInt(arg('width', '480'), 10);
  const height = parseInt(arg('height', '1040'), 10);
  const dpr = parseFloat(arg('dpr', '3'));
  const wait = parseInt(arg('wait', '20000'), 10);
  const url = arg('url', 'http://127.0.0.1:8799/');
  const out = arg('out', 'shot.png');
  const script = arg('script', '');
  const type = browserName === 'chromium' ? chromium : webkit;
  const browser = await type.launch({ headless: true, channel: browserName === 'chromium' ? 'chromium' : undefined });
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: dpr,
    isMobile: true,
    hasTouch: true,
    reducedMotion: flag('reduced-motion') ? 'reduce' : 'no-preference',
  });
  const page = await context.newPage();
  const problems = [];
  page.on('pageerror', (e) => problems.push('pageerror: ' + String(e).slice(0, 300)));
  page.on('console', (m) => {
    if (m.type() === 'error' && !m.text().includes('404')) problems.push('console: ' + m.text().slice(0, 300));
  });
  await page.goto(url, { waitUntil: 'load', timeout: 120000 });
  // the app tells the harness when it has painted a screen worth capturing
  try {
    await page.waitForFunction('window.__deskReady === true', { timeout: wait });
  } catch (_) {
    await page.waitForTimeout(Math.min(wait, 20000));
  }
  // tap a list of points (CSS pixels) before the shot: the app is a canvas, so a screen is
  // reached the way a thumb reaches it
  const taps = arg('tap', '');
  if (taps) {
    for (const pair of taps.split(';')) {
      const [x, y] = pair.split(',').map(Number);
      await page.mouse.click(x, y);
      await page.waitForTimeout(parseInt(arg('tap-settle', '900'), 10));
    }
  }
  const drags = arg('drag', '');
  if (drags) {
    for (const move of drags.split(';')) {
      const [x1, y1, x2, y2] = move.split(',').map(Number);
      await page.mouse.move(x1, y1);
      await page.mouse.down();
      for (let k = 1; k <= 12; k++) {
        await page.mouse.move(x1 + (x2 - x1) * k / 12, y1 + (y2 - y1) * k / 12);
        await page.waitForTimeout(16);
      }
      await page.mouse.up();
      await page.waitForTimeout(parseInt(arg('tap-settle', '900'), 10));
    }
  }
  if (script) await page.evaluate(script);
  await page.waitForTimeout(parseInt(arg('settle', '1200'), 10));
  await page.screenshot({ path: out, fullPage: false });
  console.log(JSON.stringify({
    out, browser: browserName, width, height, dpr,
    ready: await page.evaluate('window.__deskReady === true').catch(() => false),
    problems: [...new Set(problems)].slice(0, 6),
  }, null, 1));
  await browser.close();
})().catch((e) => {
  console.error(String(e));
  process.exit(1);
});
