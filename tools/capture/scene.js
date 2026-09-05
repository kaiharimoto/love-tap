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
// The far phone: where it wrote its six words, and where to leave it an instruction.
const pairPath = arg('pair', '');
// The far phone is on the tailnet and this browser is not. In userspace networking there is no
// route to 100.64.0.0/10 from the machine at all — only through the node's own proxy — so a page
// that fetches from a tailnet address gets "could not connect" until the browser is told the way.
// Everything served from loopback stays off it, or the page itself would go through the tailnet
// to reach the file server three ports away.
const proxy = arg('proxy', '');
const controlPath = arg('control', pairPath ? pairPath + '.do' : '');
function farSay(line) {
  if (!controlPath) throw new Error('no --control path, so nothing can be asked of the far phone');
  fs.appendFileSync(controlPath, line + '\n');
}

function abs(p) {
  return path.isAbsolute(p) ? p : path.join(outDir, p);
}
function ensure(p) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
}

(async () => {
  const vp = Object.assign({ width: 440, height: 956, dpr: 3 }, scene.viewport || {});
  const type = browserName === 'chromium' ? chromium : webkit;
  const browser = await type.launch({
    headless: true,
    channel: browserName === 'chromium' ? 'chromium' : undefined,
    ...(proxy ? { proxy: { server: proxy, bypass: '127.0.0.1,localhost' } } : {}),
  });
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
  // how many rows the thread holds right now, from the app itself; -1 when the build has no handle
  async function count() {
    const raw = await page.evaluate(() => (window.__deskCount ? String(window.__deskCount()) : '-1'));
    const n = parseInt(raw, 10);
    return Number.isFinite(n) ? n : -1;
  }
  let countBeforeFar = -1;

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
      case 'pair': {
        // The six words the far phone is showing, read out of the file it wrote.
        const pair = JSON.parse(fs.readFileSync(abs(step.from || pairPath), 'utf8'));
        await hook('__deskPair', pair.base, pair.words);
        break;
      }
      case 'far': {
        // Make the other phone do something. It is a headless process on the far end of the
        // transport (app/tool/host_daemon.dart) watching a file for one instruction a line.
        // The thread's length is noted first, so `awaitArrival` can tell when what was asked for
        // has actually crossed the wire and landed in this phone's log.
        countBeforeFar = await count();
        farSay(step.arg);
        break;
      }
      case 'awaitArrival': {
        // Wait until something the far phone was told to send has arrived here — the log has grown
        // past where it stood at the last `far`. Frames grabbed before that would be frames in
        // which nothing has happened yet, and a clip of an arrival that opens on a run of
        // identical frames is a clip with a hole in the front of it. Fails rather than proceeding
        // if nothing arrives: an arrival that never came is not something to photograph.
        const deadline = Date.now() + (step.timeout || 30000);
        const want = step.over === undefined ? countBeforeFar + 1 : step.over;
        let now = await count();
        while (now < want) {
          if (Date.now() > deadline) throw new Error(`awaitArrival: the log stood at ${now} after ${step.timeout || 30000}ms, waiting for ${want}`);
          await page.waitForTimeout(step.every || 100);
          now = await count();
        }
        log.arrivals = log.arrivals || [];
        log.arrivals.push({ before: countBeforeFar, after: now, waited_ms: Date.now() - (deadline - (step.timeout || 30000)) });
        break;
      }
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
        // where this step's frames start in the directory, so one clip can be made of two takes:
        // a note opening, and then the thread it opened in
        const from = step.from || 0;
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
          if (drive && drive.kind === 'far' && i === (drive.at || 0)) {
            // at this exact frame, and no other: the clip has to show the arrival, so the far
            // phone is told to send at a known frame rather than at a hopeful moment
            farSay(drive.line);
          }
          if (drive && drive.kind === 'scrollBy') {
            // The thread's own scroller, a step per frame. Dragging a note is a long press as
            // far as the app is concerned, which is how a clip of the year scrolling past became
            // five seconds of a reply sheet sitting open.
            await page.evaluate((d) => window.__deskScrollBy(d), drive.per || -10);
          }
          const name = path.join(dir, String(from + i).padStart(4, '0') + '.png');
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
