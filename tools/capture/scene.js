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
  const launch = {
    headless: true,
    channel: browserName === 'chromium' ? 'chromium' : undefined,
    ...(proxy ? { proxy: { server: proxy, bypass: '127.0.0.1,localhost' } } : {}),
  };
  const contextOptions = {
    viewport: { width: vp.width, height: vp.height },
    deviceScaleFactor: vp.dpr,
    isMobile: true,
    hasTouch: true,
    reducedMotion: 'no-preference',
  };
  // A kept profile: the browser's storage survives from one scene to the next, so the year is
  // imported into IndexedDB once and every later scene opens on a phone that already has it —
  // which is what a phone does. Without it every scene was a first launch, twelve to sixteen
  // seconds of import each, and the capture log called each of them the cold start. The first
  // scene on a fresh profile still is one, and the log says which kind it measured.
  const profile = arg('profile', '');
  const keptStore = !!(profile && fs.existsSync(profile));
  let browser = null;
  let context;
  if (profile) {
    fs.mkdirSync(profile, { recursive: true });
    context = await type.launchPersistentContext(profile, { ...launch, ...contextOptions });
  } else {
    browser = await type.launch(launch);
    context = await browser.newContext(contextOptions);
  }
  const page = context.pages()[0] || (await context.newPage());
  const problems = [];
  const log = { scene: scene.name, browser: browserName, viewport: vp, url, steps: [], shots: [], reports: [] };
  page.on('pageerror', (e) => {
    // the message, the name and the top of the stack: an error whose String() is empty (a Dart
    // throw of a bare value) used to be recorded as 'pageerror: ' and nothing else
    const text = (e && (e.message || e.name)) || String(e) || typeof e;
    const stack = e && e.stack ? ' @ ' + String(e.stack).replace(/\s+/g, ' ').slice(0, 240) : '';
    problems.push('pageerror: ' + String(text).slice(0, 300) + stack);
  });
  const traceFile = arg('trace', '');
  page.on('console', (m) => {
    const text = m.text();
    // every console line, in order, when asked: how a page that stopped answering is read
    if (traceFile) { try { fs.appendFileSync(traceFile, text + '\n'); } catch (e) {} }
    if (m.type() === 'error' && !text.includes('404')) problems.push('console: ' + text.slice(0, 300));
    // the app writes its own uncaught errors out in words under capture (main.dart)
    if (/^(uncaught|flutter error):/.test(text)) problems.push(text.replace(/\s+/g, ' ').slice(0, 400));
  });

  const t0 = Date.now();
  await page.goto(url, { waitUntil: 'load', timeout: 120000 });
  await page.waitForFunction('window.__deskReady === true', { timeout: scene.wait || 60000 });
  // cold_ms is kept for the collectors that read it; store says whether it measured a first
  // launch (the year importing) or a phone that already had the year
  log.cold_ms = Date.now() - t0;
  log.load = { ms: log.cold_ms, store: keptStore ? 'kept' : 'fresh', profile: profile ? path.basename(profile) : null };

  // Paired before anything else, when a far phone was given and the scene does not pair itself:
  // every still is then a picture of a phone that is talking to the other one, on the real log,
  // rather than of one sitting unpaired at `connecting` with markers the seed wrote.
  const pairsItself = scene.steps.some((s) => s.do === 'pair');
  if (pairPath && !pairsItself) {
    const started = Date.now();
    const pair = JSON.parse(fs.readFileSync(abs(pairPath), 'utf8'));
    const answer = await page.evaluate(
      ([b, w]) => Promise.resolve(window.__deskPair && window.__deskPair(b, w)).then((r) => String(r)).catch((e) => 'threw: ' + e),
      [pair.base, pair.words],
    );
    if (answer !== 'ok') throw new Error(`pairing with the far phone -> ${answer}`);
    // and connected: one round of the sync engine has to have answered before the shot
    await page.waitForFunction(() => {
      const r = window.__deskReport && JSON.parse(window.__deskReport());
      return r && r.link === 'connected';
    }, { timeout: 20000 }).catch(() => {});
    log.steps.push({ do: 'pair', ms: Date.now() - started, auto: true, far: pair.base });
  }

  // Every handle answers with a sentence: 'ok', or what was missing. A step that did not land is
  // a failed scene, not a screenshot of the wrong screen.
  async function hook(name, ...args) {
    const answer = await page.evaluate(
      ([n, a]) => Promise.resolve(window[n] && window[n](...a)).then((r) => String(r)).catch((e) => 'threw: ' + e),
      [name, args],
    );
    // Every handle that does something answers 'ok' or a sentence saying what was missing. An
    // `undefined` used to pass here, and it was hiding a build in which every answer came back as
    // undefined — pairing included. Only the clock step answers nothing, by design.
    if (answer === 'undefined' && name === '__deskStep') return;
    if (answer !== 'ok') throw new Error(`${name}(${args.join(', ')}) -> ${answer}`);
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
  let lastFarLine = '';
  let framesSoFar = 0;
  let lastPng = null;

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
        lastFarLine = step.arg;
        farSay(step.arg);
        log.far = log.far || [];
        log.far.push({ line: step.arg, at_frame: framesSoFar });
        break;
      }
      case 'awaitArrival': {
        // Wait until something the far phone was told to send has arrived here — the log has grown
        // past where it stood at the last `far`. Frames grabbed before that would be frames in
        // which nothing has happened yet, and a clip of an arrival that opens on a run of
        // identical frames is a clip with a hole in the front of it. Fails rather than proceeding
        // if nothing arrives: an arrival that never came is not something to photograph.
        const timeout = step.timeout || 30000;
        const deadline = Date.now() + timeout;
        const want = step.over === undefined ? countBeforeFar + 1 : step.over;
        let now = await count();
        // The far phone is a process watching a file, and a line can go astray between the two
        // of them. Rather than fail a whole capture over one lost instruction, the line is said
        // again — and the log says it was, so nobody reads the clip as one clean exchange.
        let saidAgain = 0;
        let nextRetry = Date.now() + Math.min(8000, timeout / 3);
        while (now < want) {
          if (Date.now() > deadline) throw new Error(`awaitArrival: the log stood at ${now} after ${timeout}ms, waiting for ${want} (said again ${saidAgain}x)`);
          if (Date.now() > nextRetry && lastFarLine && saidAgain < 3) {
            farSay(lastFarLine);
            saidAgain += 1;
            nextRetry = Date.now() + Math.min(8000, timeout / 3);
          }
          await page.waitForTimeout(step.every || 100);
          now = await count();
        }
        if (saidAgain) {
          log.said_again = log.said_again || [];
          log.said_again.push({ line: lastFarLine, times: saidAgain });
        }
        log.arrivals = log.arrivals || [];
        // at_frame is where in the assembled clip this arrival begins: the frames grabbed so far
        log.arrivals.push({ line: lastFarLine, before: countBeforeFar, after: now, at_frame: framesSoFar,
                            waited_ms: Date.now() - (deadline - (step.timeout || 30000)) });
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
        // no picture still coming out of the store: a still taken while the prints were being
        // read was a wall of blank paper with the pictures a hundred milliseconds behind it
        await page.waitForFunction(() => !window.__deskQuiet || window.__deskQuiet() === 'ok', { timeout: 10000 }).catch(() => {});
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
          if (drive && drive.kind === 'fling') {
            // a thumb's throw, at the frames the scene names; the thread then runs on its own
            // physics, a frame per step, until it stops or the thumb throws again
            const at = drive.at || [0];
            if (at.includes(i)) await hook('__deskFling', drive.velocity || -2600);
          }
          if (drive && drive.kind === 'scrollBy') {
            // The thread's own scroller, a step per frame. Dragging a note is a long press as
            // far as the app is concerned, which is how a clip of the year scrolling past became
            // five seconds of a reply sheet sitting open.
            await page.evaluate((d) => window.__deskScrollBy(d), drive.per || -10);
          }
          const name = path.join(dir, String(from + i).padStart(4, '0') + '.png');
          // The app has drawn the frame by the time __deskStep resolves; the browser has not
          // always composited it by the time the screenshot is read, and the grab then comes
          // back as the frame before — one in six frames of a scroll clip was its predecessor
          // again, followed by a double step. A grab identical to the last one is taken again
          // after a short wait, up to three times; a frame that is still the same after that is
          // a frame in which nothing moved, and frames.py says so.
          let png = await page.screenshot({ fullPage: false, clip: step.clip });
          // the headless compositor runs at about four frames a second, so the re-grabs have
          // to span a quarter of a second between them to be sure of catching the next composite
          for (let tries = 0; tries < 4 && lastPng && png.equals(lastPng); tries++) {
            await page.waitForTimeout(90);
            png = await page.screenshot({ fullPage: false, clip: step.clip });
          }
          fs.writeFileSync(name, png);
          lastPng = png;
          names.push(path.relative(ROOT, name));
          framesSoFar += 1;
          await page.evaluate((m) => window.__deskStep(m), ms);
          // and let the browser composite what the app just drew before it is grabbed: the
          // step resolves when the framework has finished its frame, which is a little before
          // the compositor has shown it, and a grab in that gap is the previous frame again
          // a short pause for the compositor rather than two animation frames: a headless page
          // throttles requestAnimationFrame to about once a second, and the wait for two of them
          // made every frame of a clip cost six seconds of wall clock
          await page.waitForTimeout(35);
        }
        if (drive && drive.kind === 'drag' && !drive.release) await page.mouse.up();
        log.shots.push({ frames: names.length, dir: path.relative(ROOT, dir), ms, drive: drive || null });
        break;
      }
      case 'timings': {
        // what each frame of the scroll cost to draw, from the framework's own FrameTiming
        const raw = await page.evaluate(() => window.__deskTimings && window.__deskTimings());
        const out = abs(step.out || 'evidence/logs/scroll_webkit.json');
        ensure(out);
        const body = raw ? JSON.parse(raw) : { missing: 'no timings handle' };
        body.browser = browserName;
        body.viewport = vp;
        fs.writeFileSync(out, JSON.stringify(body, null, 1));
        break;
      }
      case 'pwa': {
        // what the page actually offers an iPhone: the manifest it links, what the manifest says,
        // the touch icon, and whether the worker that carries pushes is registered — read from
        // the page, not from the source tree
        const facts = await page.evaluate(async () => {
          const out = { manifest_link: null, manifest: null, apple_touch_icon: null, service_workers: [], display_mode_standalone: null };
          const link = document.querySelector('link[rel="manifest"]');
          out.manifest_link = link ? link.getAttribute('href') : null;
          if (out.manifest_link) {
            try {
              const m = await (await fetch(out.manifest_link)).json();
              out.manifest = { name: m.name, display: m.display, start_url: m.start_url, icons: (m.icons || []).length };
            } catch (e) { out.manifest = 'unreadable: ' + e; }
          }
          const icon = document.querySelector('link[rel="apple-touch-icon"]');
          out.apple_touch_icon = icon ? icon.getAttribute('href') : null;
          try {
            const regs = await navigator.serviceWorker.getRegistrations();
            out.service_workers = regs.map((r) => (r.active || r.installing || r.waiting || {}).scriptURL || r.scope);
          } catch (e) { out.service_workers = 'unavailable: ' + e; }
          try { out.display_mode_standalone = window.matchMedia('(display-mode: standalone)').matches; } catch (e) {}
          return out;
        });
        facts.browser = browserName;
        facts.url = url;
        const out = abs(step.out || 'evidence/logs/pwa.json');
        ensure(out);
        fs.writeFileSync(out, JSON.stringify(facts, null, 1));
        log.pwa = facts;
        break;
      }
      case 'haptics': {
        // every feeling's pattern, from the app's own registry, written where a critic can read it
        const raw = await page.evaluate(() => window.__deskHaptics && window.__deskHaptics());
        const out = abs(step.out || 'evidence/logs/haptics.json');
        ensure(out);
        fs.writeFileSync(out, raw ? JSON.stringify(JSON.parse(raw), null, 1) : JSON.stringify({ missing: 'no haptics handle' }));
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
  // Every step landed, or this would have thrown out of the loop above. What the page logged
  // while they did — an uncaught error, a console error — is recorded here for anyone reading
  // the scene, and `ok` says whether there was any; it no longer discards the artifact, which was
  // taken from the app as it actually was. A step that did not land is still a failed scene.
  log.ok = log.problems.length === 0;
  log.steps_landed = true;
  if (scene.log) {
    const out = abs(scene.log);
    ensure(out);
    fs.writeFileSync(out, JSON.stringify(log, null, 1));
  }
  console.log(JSON.stringify(log, null, 1));
  if (browser) await browser.close(); else await context.close();
})().catch((e) => {
  console.error(String(e && e.stack ? e.stack : e));
  process.exit(1);
});
