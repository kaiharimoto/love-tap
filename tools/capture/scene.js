#!/usr/bin/env node
// tools/capture/scene.js — drive the PWA through a scene and take what it looks like.
//
//   node tools/capture/scene.js evidence/scenes/03_thread.json
//
// A scene is a list of steps. Steps that reach the app go through the capture handles the app
// exposes on window (app/lib/capture/), which are the same code paths a thumb reaches; steps that
// are taps and drags are literal pointer input. Frames for a clip are taken one at a time with the
// driven clock stepped between them, so a clip is a recording of the app rather than a video of a
// browser trying to keep up.
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..', '..');
const PW = path.join(ROOT, 'toolchain', 'pw', 'node_modules', 'playwright');
process.env.PLAYWRIGHT_BROWSERS_PATH = path.join(ROOT, 'toolchain', 'pw-browsers');
const { chromium, webkit } = require(PW);

function arg(name, dflt) {
  const i = process.argv.indexOf('--' + name);
  return i > 0 ? process.argv[i + 1] : dflt;
}

const scenePath = process.argv[2];
if (!scenePath) {
  console.error('usage: scene.js <scene.json> [--url ...] [--browser webkit|chromium]');
  process.exit(2);
}
const scene = JSON.parse(fs.readFileSync(scenePath, 'utf8'));
const url = arg('url', scene.url || 'http://127.0.0.1:8799/');
const browserName = arg('browser', scene.browser || 'webkit');
const outDir = arg('out-dir', ROOT);

function abs(p) {
  return path.isAbsolute(p) ? p : path.join(outDir, p);
}
function ensure(p) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
}

(async () => {
  const vp = Object.assign({ width: 440, height: 956, dpr: 3 }, scene.viewport || {});
  const type = browserName === 'chromium' ? chromium : webkit;
  const browser = await type.launch({ headless: true, channel: browserName === 'chromium' ? 'chromium' : undefined });
  const context = await browser.newContext({
    viewport: { width: vp.width, height: vp.height },
    deviceScaleFactor: vp.dpr,
    isMobile: true,
    hasTouch: true,
    reducedMotion: 'no-preference',
  });
  const page = await context.newPage();
  const problems = [];
  const log = { scene: scene.name, browser: browserName, viewport: vp, url, steps: [], shots: [], reports: [] };
  page.on('pageerror', (e) => problems.push('pageerror: ' + String(e).slice(0, 300)));
  page.on('console', (m) => {
    if (m.type() === 'error' && !m.text().includes('404')) problems.push('console: ' + m.text().slice(0, 300));
  });

  const t0 = Date.now();
  await page.goto(url, { waitUntil: 'load', timeout: 120000 });
  await page.waitForFunction('window.__deskReady === true', { timeout: scene.wait || 60000 });
  log.cold_ms = Date.now() - t0;

  // Every handle answers with a sentence: 'ok', or what was missing. A step that did not land is
  // a failed scene, not a screenshot of the wrong screen.
  async function hook(name, ...args) {
    const answer = await page.evaluate(
      ([n, a]) => Promise.resolve(window[n] && window[n](...a)).then((r) => String(r)).catch((e) => 'threw: ' + e),
      [name, args],
    );
    if (answer !== 'ok' && answer !== 'undefined') throw new Error(`${name}(${args.join(', ')}) -> ${answer}`);
  }
  async function settle(ms) {
    await page.waitForTimeout(ms === undefined ? (scene.settle || 700) : ms);
  }

  for (const step of scene.steps) {
    const started = Date.now();
    switch (step.do) {
      case 'goTo':
        await hook('__deskGoTo', step.arg); break;
      case 'scrollTo':
        await hook('__deskScrollTo', String(step.arg)); break;
      case 'sendFeeling':
        await hook('__deskSendFeeling', step.feeling, step.intensity === undefined ? 0.7 : step.intensity); break;
      case 'openCorner':
        await hook('__deskOpenCorner', step.arg !== false); break;
      case 'setSignal':
        await hook('__deskSetSignal', step.signal, String(step.value)); break;
      case 'openSender':
        await hook('__deskOpenSender', step.arg !== false); break;
      case 'openViewer':
        await hook('__deskOpenViewer', step.arg); break;
      case 'search':
        await hook('__deskSearch', step.arg); break;
      case 'unfold':
        await hook('__deskUnfold'); break;
      case 'stage':
        await hook('__deskStage'); break;
      case 'showWords':
        await hook('__deskShowWords'); break;
      case 'step':
        await page.evaluate((ms) => window.__deskStep(ms), step.ms || 16); break;
      case 'tap':
        await page.mouse.click(step.x, step.y); break;
      case 'press':
        await page.mouse.move(step.x, step.y);
        await page.mouse.down();
        break;
      case 'release':
        await page.mouse.up(); break;
      case 'drag': {
        const n = step.steps || 14;
        await page.mouse.move(step.from[0], step.from[1]);
        await page.mouse.down();
        for (let k = 1; k <= n; k++) {
          await page.mouse.move(
            step.from[0] + (step.to[0] - step.from[0]) * k / n,
            step.from[1] + (step.to[1] - step.from[1]) * k / n,
          );
          await page.waitForTimeout(step.hold ? Math.round(step.hold / n) : 16);
        }
        await page.mouse.up();
        break;
      }
      case 'wait':
        await settle(step.ms); break;
      case 'shot': {
        const out = abs(step.out);
        ensure(out);
        await settle(step.settle);
        await page.screenshot({ path: out, fullPage: false, clip: step.clip });
        log.shots.push({ out: path.relative(ROOT, out), clip: step.clip || null });
        break;
      }
      case 'frames': {
        // One frame at a time, with the clock stepped between them, and — when the clip is of
        // something being done rather than something happening — the thumb moved a little between
        // each one too. A drag spread across three hundred frames is a real recording of a scroll:
        // the app draws every frame of it, and none of them is invented afterwards.
        const dir = abs(step.dir);
        fs.mkdirSync(dir, { recursive: true });
        const count = step.count || 30;
        const ms = step.ms || 33;
        const drive = step.drive;
        const names = [];
        if (drive && drive.kind === 'drag') {
          await page.mouse.move(drive.from[0], drive.from[1]);
          await page.mouse.down();
        }
        for (let i = 0; i < count; i++) {
          if (drive && drive.kind === 'drag') {
            // ease it, the way a thumb does: slow at the start, quick through the middle
            const t = count === 1 ? 1 : i / (count - 1);
            const e = t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);
            await page.mouse.move(
              drive.from[0] + (drive.to[0] - drive.from[0]) * e,
              drive.from[1] + (drive.to[1] - drive.from[1]) * e,
            );
            if (drive.release && i === Math.round(count * (drive.release || 0.7))) {
              await page.mouse.up();   // let go part way, so the rest is the thread's own momentum
            }
          }
          if (drive && drive.kind === 'scrollBy') {
            // The thread's own scroller, a step per frame. Dragging a note is a long press as
            // far as the app is concerned, which is how a clip of the year scrolling past became
            // five seconds of a reply sheet sitting open.
            await page.evaluate((d) => window.__deskScrollBy(d), drive.per || -10);
          }
          const name = path.join(dir, String(i).padStart(4, '0') + '.png');
          await page.screenshot({ path: name, fullPage: false, clip: step.clip });
          names.push(path.relative(ROOT, name));
          await page.evaluate((m) => window.__deskStep(m), ms);
        }
        if (drive && drive.kind === 'drag' && !drive.release) await page.mouse.up();
        log.shots.push({ frames: names.length, dir: path.relative(ROOT, dir), ms, drive: drive || null });
        break;
      }
      case 'report': {
        const raw = await page.evaluate(() => window.__deskReport && window.__deskReport());
        const report = raw ? JSON.parse(raw) : { missing: 'no report handle' };
        report.at = step.at || step.out || 'report';
        log.reports.push(report);
        if (step.out) {
          const out = abs(step.out);
          ensure(out);
          fs.writeFileSync(out, JSON.stringify(report, null, 1));
        }
        break;
      }
      default:
        throw new Error('unknown step: ' + step.do);
    }
    if (step.do !== 'frames' && step.do !== 'shot') await settle(step.after);
    log.steps.push({ do: step.do, ms: Date.now() - started });
  }

  log.problems = [...new Set(problems)].slice(0, 8);
  log.ok = log.problems.length === 0;
  if (scene.log) {
    const out = abs(scene.log);
    ensure(out);
    fs.writeFileSync(out, JSON.stringify(log, null, 1));
  }
  console.log(JSON.stringify(log, null, 1));
  await browser.close();
  if (!log.ok) process.exitCode = 1;
})().catch((e) => {
  console.error(String(e && e.stack ? e.stack : e));
  process.exit(1);
});
