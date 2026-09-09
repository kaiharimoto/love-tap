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
// The scene wins, not the command line. Fourteen of the fifteen are shot in WebKit because that is
// what an iPhone runs; one of them cannot be, and the reason is worth stating exactly because it is
// easy to state wrongly.
//
// This harness sets `isMobile: true` below, which puts WebKit into iPhone-Safari emulation, and in
// that mode `Notification` and `PushManager` are absent — measured: with a plain context or with
// deviceScaleFactor alone the same webkit-2336 build reports both present and
// `Notification.permission === 'default'`; with `isMobile: true` both are undefined. That absence
// is not a gap in the build. It is what a Safari tab on an iPhone actually has: iOS gives the push
// API only to a web app installed to the home screen.
//
// Turning the flag off would not help either. Measured on the same build: `grantPermissions
// (['notifications'])` resolves and changes nothing, `Notification.requestPermission()` returns
// 'denied', and `Notification.permission` never leaves 'default'. So no WebKit scene can produce a
// notification to photograph, and the one that has to says which browser it needs.
const browserName = scene.browser || arg('browser', 'webkit');
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
    // A notification is drawn by the browser, not by the page, so there is no headless way to
    // photograph one: the window has to exist on a display. That scene runs under Xvfb.
    headless: scene.headed ? false : true,
    ...(scene.headed ? { args: ['--window-position=0,0'] } : {}),
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
  // A scene that photographs an interruption has to be allowed to interrupt. Everything else asks
  // for nothing, so the fourteen other scenes see the same default-denied browser they always did.
  if (scene.permissions && context.grantPermissions) {
    try {
      await context.grantPermissions(scene.permissions, { origin: new URL(url).origin });
    } catch (e) {
      problems.push('permissions: ' + e);
    }
  }
  const log = { scene: scene.name, browser: browserName, viewport: vp, url, steps: [], shots: [], reports: [] };
  // What the app said about itself at the instant each shutter opened, kept by the name of the
  // picture. A report is written after the picture is on disk — encoding a full-page PNG takes
  // seconds — and in those seconds the phone goes on being a phone: 13's record said the partner
  // was not writing over a picture in which she is, because the six-second lapse on a typing frame
  // ran out between the two. A record that says `at: 13_messenger_states.png` should be an account
  // of that picture, so it is taken with it.
  const saidAtTheShutter = new Map();
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
    //
    // A handle may say 'ok' and then something worth writing down — how many feelings were on the
    // vocabulary sheet it just turned to, say. That is not a failure, and treating it as one cost
    // a whole capture of 15: the answer goes into the scene log and the step passes.
    if (answer === 'undefined' && name === '__deskStep') return;
    if (answer === 'ok') return;
    if (answer.startsWith('ok,') || answer.startsWith('ok ')) {
      log.steps.push({ at: Date.now() - t0, said: `${name}(${args.join(', ')}) ${answer}` });
      return;
    }
    throw new Error(`${name}(${args.join(', ')}) -> ${answer}`);
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

  // A frames directory belongs to the run, not to the disk. Takes append to it — the second take
  // of a clip carries on where the first stopped, and now that a take can get its length from the
  // packed library it works out that offset by counting what is already there. So anything left
  // behind by an earlier run has to go before the first take, or a debugging run with KEEP_FRAMES
  // set would silently push this run's frames past somebody else's and the clip would open on a
  // build that is no longer here.
  for (const dir of new Set(scene.steps.filter((s) => s.do === 'frames').map((s) => abs(s.dir)))) {
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir)) {
      if (f.endsWith('.png')) fs.unlinkSync(path.join(dir, f));
    }
  }

  for (const step of scene.steps) {
    const started = Date.now();
    switch (step.do) {
      case 'goTo':
        await hook('__deskGoTo', step.arg); break;
      // Ask for a sync round now rather than waiting out a backoff. An ephemeral frame — the
      // partner typing — is delivered on a pull like anything else, and a scene that says
      // `typing on` and then takes the picture is racing the poll: the record said the partner
      // was writing over a frame that did not show it.
      case 'sync':
        await hook('__deskSync'); break;
      // Wait for the app to say a thing is true before the shutter opens, rather than waiting a
      // number of milliseconds and hoping. The partner typing is an ephemeral frame delivered on a
      // pull, so `typing on` followed by a wait is a race the record loses in a particular way: it
      // says the partner was writing over a frame that does not show it.
      case 'awaitView': {
        const key = step.key;
        const want = step.value === undefined ? true : step.value;
        const until = Date.now() + (step.timeout || 8000);
        let got = null;
        while (Date.now() < until) {
          got = await page.evaluate((k) => {
            // One field, not the whole report. The report is the region's own account of every row
            // on the glass, and asking for it four times a second made this wait seconds long: the
            // shutter then opened well after the moment the scene had waited for, and 13's record
            // said the partner was not writing over a picture in which she was.
            if (window.__deskView) {
              try {
                return JSON.parse(window.__deskView(k));
              } catch (e) {
                return null;
              }
            }
            const r = window.__deskReport && JSON.parse(window.__deskReport());
            // `video.playing` as well as `partner_typing`: a region reports what it is showing in
            // whatever shape that thing has, and a scene should be able to wait for a thing two
            // deep without the report having to flatten itself for the harness.
            let v = r && r.view;
            for (const part of String(k).split('.')) {
              if (v == null) return null;
              v = v[part];
            }
            return v === undefined ? null : v;
          }, key);
          if (got === want) break;
          await page.evaluate(() => window.__deskSync && window.__deskSync()).catch(() => {});
          await page.waitForTimeout(step.every || 250);
        }
        log.steps.push({ awaited: key, want, got });
        // Not fatal by default. The thing waited for is something the app is *also* showing —
        // a partner typing, a picture decoded — and a scene that throws here loses the whole
        // artifact over a detail of it. What the record says is what was actually waited for and
        // what it got, so a reader can see that the frame does not carry it. `required: true` for
        // a scene whose whole subject is the thing.
        if (got !== want) {
          if (step.required) throw new Error(`${key} never became ${want} (it is ${got})`);
          log.not_shown = log.not_shown || [];
          log.not_shown.push(`${key} never became ${want} before the shutter (it is ${got})`);
          break;
        }
        // The app knowing a thing and the glass showing it are two moments. In capture mode a
        // frame is drawn when the clock is stepped, so a scene that waits for the report to say
        // the partner is writing and then opens the shutter photographs the frame before it: the
        // record said writing over a picture that did not. Give it a beat and two frames.
        await page.waitForTimeout(step.settle || 600);
        for (let i = 0; i < 2; i++) {
          await page.evaluate(() => window.__deskStep && window.__deskStep(16));
          await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
        }
        break;
      }
      case 'scrollTo':
        await hook('__deskScrollTo', String(step.arg)); break;
      case 'sendFeeling':
        await hook('__deskSendFeeling', step.feeling, step.intensity === undefined ? 0.7 : step.intensity); break;
      case 'openCorner':
        await hook('__deskOpenCorner', step.arg !== false); break;
      case 'showFamily':
        await hook('__deskShowFamily', String(step.arg)); break;
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
      case 'slowSend':
        // One message written into a link that has been slowed for a few seconds, so the shot
        // catches it while its push is actually in flight. `sending` lasts exactly as long as a
        // push does, which on a loopback is nothing at all.
        await hook('__deskSendSlowly', step.text || 'ok — leaving now', step.ms || 5000); break;
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
          if (Date.now() > deadline) {
            // say what the phone thought was happening, not only that nothing did
            const rep = await page.evaluate(() => (window.__deskReport ? window.__deskReport() : '{}')).catch(() => '{}');
            let where = '';
            try {
              const r = JSON.parse(rep);
              where = ` — link ${r.link}, events ${r.events}, sync ${JSON.stringify(r.sync)}`;
            } catch (e) {}
            throw new Error(`awaitArrival: the log stood at ${now} after ${timeout}ms, waiting for ${want} (said again ${saidAgain}x)${where}`);
          }
          if (Date.now() > nextRetry && lastFarLine && saidAgain < 3) {
            farSay(lastFarLine);
            saidAgain += 1;
            nextRetry = Date.now() + Math.min(8000, timeout / 3);
          }
          await page.waitForTimeout(step.every || 100);
          // ask for a round rather than waiting out a backoff
          await page.evaluate(() => window.__deskSync && window.__deskSync()).catch(() => {});
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
        // read first, photograph second: nothing between them steps the clock or touches the app
        const said = await page.evaluate(() => window.__deskReport && window.__deskReport()).catch(() => null);
        await page.screenshot({ path: out, fullPage: false, clip: step.clip });
        if (said) {
          saidAtTheShutter.set(path.relative(ROOT, out), said);
          saidAtTheShutter.set(path.basename(out), said);
        }
        log.shots.push({ out: path.relative(ROOT, out), clip: step.clip || null });
        break;
      }
      case 'frames': {
        // Nothing still being decoded before the first grab. A piece keeps its room and paints
        // nothing until its paper has arrived, so a run that opens on the frame a note was
        // inserted in opens on a hole where the note should be — which is the light jump 07 has
        // failed on from both sides. This waits for the app to say it is ready rather than for a
        // number of milliseconds somebody guessed at.
        await page.waitForFunction(() => !window.__deskQuiet || window.__deskQuiet() === 'ok',
            { timeout: 15000 }).catch(() => {});
        // One frame at a time, with the clock stepped between them, and — when the clip is of
        // something being done rather than something happening — the thumb moved a little between
        // each one too. A drag spread across three hundred frames is a real recording of a scroll:
        // the app draws every frame of it, and none of them is invented afterwards.
        const dir = abs(step.dir);
        fs.mkdirSync(dir, { recursive: true });
        // `count: "fold:<sequence>"` means one grab per packed frame of that fold sequence, read
        // from the manifest the packer wrote. The fold clip grabs one frame per frame of the
        // sequence, so its length is a fact about the packed library and not a number to type into
        // a scene: the packer trims each sequence where it stops moving, and a re-render that moves
        // that point used to leave the scene either cutting the fold short or running it into held
        // frames the frame check then fails the artifact on.
        let count = step.count || 30;
        if (typeof count === 'string' && count.startsWith('fold:')) {
          // The number of frames to grab is the number the app is going to play, so it is asked of
          // the app. Reading the repo's app/assets/INDEX.json instead was reading a different file
          // from the one the build carries: the build is a copy taken when it was made, `--no-build`
          // runs against builds already on disk, and app/assets is whatever the last pack left. An
          // index one frame longer than the build gives held frames at the end of the fold; one
          // frame shorter cuts it off mid-motion. Neither says anything.
          const seq = count.slice(5);
          const n = await page.evaluate(() => {
            const r = window.__deskReport && JSON.parse(window.__deskReport());
            return r && r.fold ? { sequence: r.fold.sequence, length: r.fold.length } : null;
          });
          if (!n || !n.length) throw new Error(`the build has no fold sequence loaded to grab`);
          if (n.sequence !== seq) {
            throw new Error(`the build has ${n.sequence} loaded and the scene asks for ${seq}`);
          }
          count = n.length;
          log.steps.push({ frames_from_the_build: seq, count });
        }
        const ms = step.ms || 33;
        // Where this step's frames start in the directory, so one clip can be made of two takes: a
        // note opening, and then the thread it opened in. Left out, it carries on from whatever is
        // already in the directory — which is what a run whose length came from the index needs,
        // because the take after it cannot know its own offset in advance.
        const from = step.from !== undefined
          ? step.from
          : fs.readdirSync(dir).filter((f) => f.endsWith('.png')).length;
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
          // The headless compositor runs at about four frames a second and slower when the
          // machine is busy: four tries ninety milliseconds apart is a third of a second, which is
          // less than one of its frames. Two clips of the same scroll, shot an hour apart on the
          // same build, came back with three and then five frames identical to the one before —
          // and at different frames each time, which is what a race looks like rather than a
          // picture that did not change. Ten tries a fifth of a second apart is two seconds, and a
          // frame still identical after that is a frame in which nothing moved; frames.py says so.
          for (let tries = 0; tries < 10 && lastPng && png.equals(lastPng); tries++) {
            await page.waitForTimeout(200);
            png = await page.screenshot({ fullPage: false, clip: step.clip });
          }
          // A grab can land halfway through a composite: the frame comes back part drawn, much
          // darker than its neighbours on both sides, and reads as the light jumping and jumping
          // back. Such a frame compresses to a very different size from the one before it, so a
          // large jump in size is taken again — a real cut in the picture costs one extra grab.
          if (lastPng && Math.abs(png.length - lastPng.length) > lastPng.length * 0.2) {
            await page.waitForTimeout(60);
            const again = await page.screenshot({ fullPage: false, clip: step.clip });
            if (!again.equals(lastPng)) png = again;
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
      case 'flingLog': {
        // Every frame of every throw: what the simulation asked the thread to move, what it
        // actually moved, and where it was sitting. A frame of the clip identical to the one
        // before it is either a race in the grab or a thread that stood still, and only this
        // says which.
        const raw = await page.evaluate(() => window.__deskFlingLog && window.__deskFlingLog());
        const out = abs(step.out || 'evidence/logs/fling.json');
        ensure(out);
        const body = raw ? JSON.parse(raw) : { missing: 'no fling handle' };
        body.browser = browserName;
        fs.writeFileSync(out, JSON.stringify(body, null, 1));
        break;
      }
      case 'push': {
        // A real push, delivered to the real worker, with the app not in front of anyone. The
        // browser draws the notification; nothing in the app is asked to draw a picture of one.
        // CDP's Push is the only way in without a push service to mint an endpoint — the payload
        // arrives at the worker's own `push` listener exactly as a subscribed one would.
        const cdp = await context.newCDPSession(page);
        await cdp.send('ServiceWorker.enable');
        const seen = [];
        cdp.on('ServiceWorker.workerRegistrationUpdated', (p) => seen.push(...(p.registrations || [])));
        await page.waitForTimeout(step.settle || 1500);
        const target = seen.find((r) => /\/push\/?$/.test(r.scopeURL || '')) || seen[0];
        if (!target) {
          problems.push('push: no service worker registration to deliver to');
          break;
        }
        await cdp.send('ServiceWorker.deliverPushMessage', {
          origin: new URL(target.scopeURL).origin,
          registrationId: target.registrationId,
          data: JSON.stringify(step.payload || { kind: 'message', from: 'noor' }),
        });
        log.steps.push({ push: step.payload || null, scope: target.scopeURL });
        break;
      }
      case 'closeApp': {
        // The claim is that something reaches a phone nobody is looking at, so the app has to not
        // be on the glass. Navigating away is the closest a browser gets to that: the page is gone,
        // the service worker is not — which is the whole point of a service worker.
        await page.goto('about:blank', { waitUntil: 'load' });
        const where = await page.evaluate(() => location.href);
        log.app_open = where !== 'about:blank' ? where : false;
        if (where !== 'about:blank') problems.push('closeApp: still on ' + where);
        break;
      }
      case 'screen': {
        // The notification is the browser's own chrome on the display, outside the page, so the
        // page cannot photograph it. This grabs the root window instead.
        const { execFileSync } = require('child_process');
        const out = abs(step.out || 'evidence/crops/reception.png');
        ensure(out);
        try {
          execFileSync(path.join(ROOT, 'toolchain', 'ffmpeg', 'ffmpeg'), [
            '-y', '-loglevel', 'error', '-f', 'x11grab',
            '-video_size', step.size || '1600x1200',
            '-i', process.env.DISPLAY || ':99', '-frames:v', '1', out,
          ]);
          log.shots.push({ out: step.out, of: 'the display, not the page' });
        } catch (e) {
          problems.push('screen: ' + String(e).slice(0, 200));
        }
        break;
      }
      case 'notifications': {
        // What the browser is holding, read from the browser. The app's own record says what it
        // asked for; this says what arrived.
        //
        // `from` is a path on the app's own origin that is not the app: the worker's own scope
        // directory. getNotifications() is origin-scoped, so after the app has been navigated away
        // from there has to be some document on that origin to ask through — and it must not be
        // the app, or reading the record would re-open the thing whose absence is the point.
        if (step.from) {
          await page.goto(new URL(step.from, url).href, { waitUntil: 'load' });
          await page.waitForTimeout(400);
        }
        const recs = await page.evaluate(async () => {
          const out = { permission: null, records: [] };
          try { out.permission = Notification.permission; } catch (e) { out.permission = 'no Notification: ' + e; }
          try {
            for (const r of await navigator.serviceWorker.getRegistrations()) {
              for (const n of await r.getNotifications()) {
                out.records.push({ scope: r.scope, title: n.title, body: n.body, tag: n.tag,
                                   silent: n.silent, data: n.data });
              }
            }
          } catch (e) { out.records = 'unreadable: ' + e; }
          // and the phone's own side of it: what the worker was asked to show, what it decided,
          // and what it showed. The browser draws the notification and a machine with no
          // notification presenter draws nothing, which is not the same as nothing having
          // arrived — this is the difference, written by the worker itself.
          try {
            const profile = new URL(location.href).searchParams.get('profile') || 'default';
            out.shown_by_the_worker = await new Promise((resolve) => {
              const open = indexedDB.open('spine_' + profile);
              open.onerror = () => resolve('no store');
              open.onupgradeneeded = () => { try { open.transaction.abort(); } catch (_) {} };
              open.onsuccess = () => {
                const db = open.result;
                let got;
                try { got = db.transaction('meta', 'readonly').objectStore('meta').get('push.shown'); }
                catch (e) { db.close(); return resolve('no meta: ' + e); }
                got.onerror = () => { db.close(); resolve('unreadable'); };
                got.onsuccess = () => {
                  db.close();
                  try { resolve(got.result ? JSON.parse(got.result) : []); } catch (_) { resolve([]); }
                };
              };
            });
          } catch (e) { out.shown_by_the_worker = 'unreadable: ' + e; }
          // and what this phone was set to, which is what decides whether it says anything at all
          try {
            const profile = new URL(location.href).searchParams.get('profile') || 'default';
            out.settings = await new Promise((resolve) => {
              const open = indexedDB.open('spine_' + profile);
              open.onerror = () => resolve('no store');
              open.onupgradeneeded = () => { try { open.transaction.abort(); } catch (_) {} };
              open.onsuccess = () => {
                const db = open.result;
                let store;
                try { store = db.transaction('meta', 'readonly').objectStore('meta'); }
                catch (e) { db.close(); return resolve('no meta'); }
                const prefs = store.get('notify.prefs');
                const words = store.get('push.words');
                prefs.onsuccess = () => {
                  words.onsuccess = () => {
                    db.close();
                    let p = null, w = null;
                    try { p = prefs.result ? JSON.parse(prefs.result) : null; } catch (_) {}
                    try { w = words.result ? JSON.parse(words.result) : null; } catch (_) {}
                    resolve({ prefs: p, words_for_kinds: w ? Object.keys(w).length : 0 });
                  };
                  words.onerror = () => { db.close(); resolve('unreadable'); };
                };
                prefs.onerror = () => { db.close(); resolve('unreadable'); };
              };
            });
          } catch (e) { out.settings = 'unreadable: ' + e; }
          return out;
        });
        recs.browser = browserName;
        recs.app_open = log.app_open === undefined ? true : log.app_open;
        recs.note = 'Chromium on a Linux virtual display. WebKit is what the other fourteen '
          + 'scenes are shot in, and under the iPhone-Safari emulation this harness uses it has no '
          + 'Notification and no PushManager — which is what a Safari tab on an iPhone has, since '
          + 'iOS gives the push API only to a home-screen web app; and even without that emulation '
          + 'the permission cannot be granted there. So this is not an iPhone banner, there is no '
          + 'lock screen in evidence, and what an installed iOS web app does with the same call is '
          + 'not shown anywhere in this build.';
        const out = abs(step.out || 'evidence/logs/reception.json');
        ensure(out);
        fs.writeFileSync(out, JSON.stringify(recs, null, 1));
        log.reception = recs;
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
      case 'searchFacet': {
        await hook('__deskSearchFacet', step.arg || '');
        await settle(step.settle || 500);
        break;
      }
      case 'report': {
        const named = step.at ? saidAtTheShutter.get(step.at) : null;
        const raw = named || await page.evaluate(() => window.__deskReport && window.__deskReport());
        const report = raw ? JSON.parse(raw) : { missing: 'no report handle' };
        report.at = step.at || step.out || 'report';
        // a record of a picture is read at the picture; a record of the run is read now
        report.read_at = named ? 'the shutter' : 'the end of the scene';
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
