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
  const log = { scene: scene.name, browser: browserName, viewport: vp, url, steps: [], shots: [], reports: [], blob_waits: [] };
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

  // The second readiness signal, and the reason there has to be one.
  //
  // `window.__deskReady` is set from the second post-frame callback after the first frame: the
  // material library is loaded, the spine is open, one frame is on the glass. It says nothing
  // about whether the region on screen has the pictures it asked for. `evidence/logs/04_moments`
  // timed a run at 4771 ms to ready and then 2305 and 2828 before the shutter, against a grid
  // whose blob reads took longer than that — so the still that came out showed one photograph and
  // six tiles reading "still fetching the picture.", and a still taken early is indistinguishable
  // from a still of a screen that never fills. Three of this cycle's critics read it as the
  // second and the row it caps was scored from that reading.
  //
  // So a shot waits for the reads to land. And it waits on a budget, because a scene that takes
  // longer than a person will wait is a fact about the app: the wait is written into the log
  // either way, and a scene that runs out is recorded as having run out rather than photographed
  // blank. `blobsBudgetMs` is what a person is assumed to give it.
  const blobsBudgetMs = scene.blobs_budget_ms === undefined ? 12000 : scene.blobs_budget_ms;
  async function settleBlobs(label) {
    if (blobsBudgetMs <= 0) return;
    const began = Date.now();
    let pending = null;
    for (;;) {
      pending = await page
        .evaluate(() => (window.__deskBlobsPending ? window.__deskBlobsPending() : 0))
        .catch(() => null);
      // An older build with no handle is not a failed scene; it is a still taken the way every
      // still before this one was. Said out loud so it is never mistaken for a screen that filled.
      if (pending === null) {
        problems.push('blobs: no __deskBlobsPending handle');
        return;
      }
      if (pending === 0) break;
      if (Date.now() - began >= blobsBudgetMs) break;
      await page.waitForTimeout(100);
    }
    const waited = Date.now() - began;
    log.blob_waits.push({ at: label, waited_ms: waited, pending_at_shot: pending });
    if (pending !== 0) {
      problems.push(
        `blobs: ${label} was shot with ${pending} picture(s) still being read, after waiting ` +
          `${waited} ms. The still is of a screen that had not filled yet, not of a screen that ` +
          `does not fill.`,
      );
    }
  }

  // Beside every still, what the app says it drew. tools/check/legibility.py finds writing by
  // looking for marks shaped like glyphs — its own docstring says so — and a surface that
  // acquires texture acquires glyph-shaped marks, which is how 137 runs that were torn fibre
  // arrived in one capture and outnumbered the change they were being used to judge. The app
  // knows where its text is; this writes it down at the moment of the shot, when it is true.
  //
  // Written as a sidecar rather than folded into the scene log because it is per-artifact and the
  // tool reads it per-artifact: `02_chat.png` is measured against `02_chat.text.json`.
  //
  // A shot with a `clip` is a crop of the viewport, so the declared rects are shifted into the
  // crop's own coordinates and anything outside it is dropped — otherwise the tool would be
  // handed permission to look at pixels that are not in the file.
  // Beside every still, what the app says it drew on: the asset, the size of the render it came
  // from, the size it was drawn at, and the magnification between the two.
  //
  // It is here because a PNG cannot answer that question and three review cycles tried. The flat
  // cream rectangle in `10_first_run.png` was diagnosed as a missing render and then as a
  // fallback colour showing through; it was neither. It was a 702x1500 till roll drawn as a whole
  // phone screen, and neither the 702 nor the 1.94 is a thing anyone can read off the picture.
  //
  // Written as its own file per artifact, the way the text runs are, so a tool can be pointed at
  // `10_first_run.surfaces.json` and told what the frame was made of.
  async function surfacesSidecar(out) {
    const raw = await page
      .evaluate(() => window.__deskPaperSurfaces && window.__deskPaperSurfaces())
      .catch((e) => 'threw: ' + e);
    if (!raw || typeof raw !== 'string' || raw.startsWith('threw:')) {
      problems.push('surfaces: ' + (raw ? String(raw).slice(0, 200) : 'no __deskPaperSurfaces handle'));
      return null;
    }
    let surfaces;
    try {
      surfaces = JSON.parse(raw);
    } catch (e) {
      problems.push('surfaces: unparseable: ' + String(e).slice(0, 200));
      return null;
    }
    const side = out.replace(/\.png$/, '') + '.surfaces.json';
    ensure(side);
    fs.writeFileSync(side, JSON.stringify(surfaces, null, 1));
    return surfaces.length;
  }

  async function textSidecar(out, clip) {
    const raw = await page.evaluate(() => window.__deskTextRuns && window.__deskTextRuns())
      .catch((e) => 'threw: ' + e);
    if (!raw || typeof raw !== 'string' || raw.startsWith('threw:')) {
      // An older build with no handle is not a failed scene; it is a still the tool will measure
      // the way it always did. Said out loud so it is never mistaken for an empty screen.
      problems.push('text runs: ' + (raw ? String(raw).slice(0, 200) : 'no __deskTextRuns handle'));
      return null;
    }
    let runs;
    try {
      runs = JSON.parse(raw);
    } catch (e) {
      problems.push('text runs: unparseable: ' + String(e).slice(0, 200));
      return null;
    }
    const dpr = vp.dpr;
    const box = clip
      ? { x: Math.round(clip.x * dpr), y: Math.round(clip.y * dpr),
          w: Math.round(clip.width * dpr), h: Math.round(clip.height * dpr) }
      : { x: 0, y: 0, w: Math.round(vp.width * dpr), h: Math.round(vp.height * dpr) };
    const shift = (r) => {
      const x0 = Math.max(r[0] - box.x, 0);
      const y0 = Math.max(r[1] - box.y, 0);
      const x1 = Math.min(r[0] + r[2] - box.x, box.w);
      const y1 = Math.min(r[1] + r[3] - box.y, box.h);
      return (x1 - x0) >= 1 && (y1 - y0) >= 1 ? [x0, y0, x1 - x0, y1 - y0] : null;
    };
    const kept = [];
    let clipped = 0;
    for (const run of runs) {
      const rect = shift(run.rect);
      if (!rect) continue;
      // `shift` clamps a rect into the frame, so a run the app declared partly outside it came
      // through as a smaller run rather than as a trimmed one, and `offscreen` counted only the
      // ones that were wholly outside. A message clamped from fifty-eight pixels tall to two is
      // not a fifty-eight pixel message and it is not offscreen either; it is cut, and the number
      // that says so should be in the sidecar rather than worked out by subtracting rects by hand.
      const whole = run.rect;
      if (rect[2] !== whole[2] || rect[3] !== whole[3]) clipped++;
      const lines = (run.lines || []).map(shift).filter(Boolean);
      kept.push(Object.assign({}, run, { rect, lines: lines.length ? lines : [rect] }));
    }
    const sidecar = out.replace(/\.png$/, '') + '.text.json';
    ensure(sidecar);
    fs.writeFileSync(sidecar, JSON.stringify({
      of: path.basename(out),
      size: [box.w, box.h],
      dpr,
      declared: kept.length,
      offscreen: runs.length - kept.length,
      clipped,
      runs: kept,
    }, null, 1));
    return kept.length;
  }

  for (const step of scene.steps) {
    const started = Date.now();
    switch (step.do) {
      case 'goTo':
        await hook('__deskGoTo', step.arg); break;
      case 'scrollTo':
        await hook('__deskScrollTo', String(step.arg)); break;
      // The settings page is taller than one screenful and `what may interrupt` is last on it,
      // so the top-of-page shot cannot see the interrupt matrix. This is the thumb that reaches it.
      case 'scrollSettings':
        await hook('__deskSettingsScrollBy', Number(step.arg)); break;
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
      case 'partnerTyping':
        await hook('__deskPartnerTyping', step.arg !== false); break;
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
      case 'far':
        // Make the other phone do something. It is a headless process on the far end of the
        // transport (app/tool/host_daemon.dart) watching a file for one instruction a line.
        farSay(step.arg);
        break;
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
        await settleBlobs(path.basename(out));
        await page.screenshot({ path: out, fullPage: false, clip: step.clip });
        const declared = await textSidecar(out, step.clip);
        const surfaces = await surfacesSidecar(out);
        log.shots.push({
          out: path.relative(ROOT, out), clip: step.clip || null,
          text_runs: declared, surfaces,
        });
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
        // The clock's step and the clip's frame rate are the same number, and writing it twice is
        // how one fold frame in every twenty-five came to be shot twice: the scene stepped a whole
        // 16 ms while ffmpeg assembled at 60, which is 16.667. The sequence fell one frame behind
        // every 400 ms and the shot at that moment caught the frame before it again -- recorded
        // frames 44, 94, 144, 169, 244, 269 of 06_unfolding.mp4, a cadence of exactly 25. So the
        // rate is the number written down and the step is derived from it. `ms` still overrides,
        // for a take deliberately run slower than the clip it goes into.
        const fps = step.fps || 60;
        const ms = step.ms === undefined ? 1000 / fps : step.ms;
        // A take is as long as the thing it records. `stop` names a handle that answers with the
        // microseconds still to come; the take ends on the first shot after it reaches zero, so a
        // clip cannot acquire a tail of held frames because a count was written down by hand.
        const stop = step.stop;
        let started = false;   // it has to have something to count down before zero means over
        let stopped = 0;
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
          if (stop) {
            const left = await page.evaluate((h) => (window[h] ? window[h]() : -1), stop);
            if (left === -1) { problems.push('frames: no ' + stop + ' handle'); break; }
            // A zero before the thing has started is the widget not having been built yet, not the
            // thing being over: the sequence is looked up asynchronously, so the handle answers
            // zero for the first frame or two. Taking that at face value would end the take two
            // frames in, which is a worse artifact than the held tail this replaces.
            if (left > 0) started = true;
            // then one shot past zero, so the last frame of the clip is the settled thing and not
            // the frame before it finished arriving
            if (started && left === 0 && stopped++ > 0) break;
          }
        }
        if (drive && drive.kind === 'drag' && !drive.release) await page.mouse.up();
        log.shots.push({ frames: names.length, dir: path.relative(ROOT, dir), ms, fps, stop: stop || null, drive: drive || null });
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
