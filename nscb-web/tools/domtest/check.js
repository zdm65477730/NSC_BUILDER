/* Headless render check for the NSCB SPA: asserts every facet/operation/jobs view renders.
   Run: node tools/domtest/check.js   (needs jsdom: npm i jsdom --prefix /tmp/domtest) */
const fs = require('fs');
const path = require('path');
const { JSDOM } = require('/tmp/domtest/node_modules/jsdom');
process.on('unhandledRejection', r => console.log('UNHANDLED REJECTION:', r && (r.stack || r.message || String(r))));

const W = path.resolve(__dirname, '../../src/NscbServer/wwwroot');
let html = fs.readFileSync(path.join(W, 'index.html'), 'utf8').replace(/<script src=[^>]+><\/script>/g, '');
const i18n = fs.readFileSync(path.join(W, 'i18n.js'), 'utf8');
const app = fs.readFileSync(path.join(W, 'app.js'), 'utf8');

const info = {
  path: 'D:/x/base.nsp', format: 'nsp', fileSize: 12345678, titleName: 'Sample Game', publisher: 'Acme',
  developer: 'Acme Studio', genre: 'Action', region: 'US', displayVersion: '1.0.0', titleId: '0100AA000000A000',
  baseTitleId: '0100AA000000A000', titleType: 'Application', titleVersion: '0.0.0', titleVersionRaw: 0,
  requiredSystemVersion: '(16.0.0)', keyGeneration: 9, hasTitleKeyCrypto: true, hasTicket: true, titleKeyAvailable: true,
  hasIcon: true, keysAvailable: true, warnings: [],
  contents: [
    { name: 'a.nca', ncaType: 'Program', kind: 'nca', size: 1000, distribution: 'Download', titleId: '0100AA000000A000', keyGeneration: 9, compressed: false },
    { name: 'b.cnmt.nca', ncaType: 'Meta', kind: 'nca', size: 20, distribution: 'Download' },
    { name: 'icon.png', kind: 'png', size: 5 }],
};
const npdm = { sourceFile: 'a.nca', titleName: 'Sample', productCode: null, processCategory: 'Regular title', titleId: '0100AA000000A000', allowedIdMin: '0100000000000000', allowedIdMax: '01FFFFFFFFFFFFFF', acidFlags: 3, fsAccessVersion: 1, fsPermissions: 1, services: ['acc:u0', 'apm', 'ns'] };

const dom = new JSDOM(html, { runScripts: 'outside-only', url: 'http://localhost/' });
const { window } = dom;
window.fetch = (url, opt) => {
  const u = String(url);
  let body = {};
  if (u.startsWith('/api/info?')) body = info;
  else if (u.startsWith('/api/npdm')) body = npdm;
  else if (u.startsWith('/api/verify')) body = { ok: false, total: 6, checked: 2, failures: ['b.nca: bad'], files: [{ name: 'a.nca', type: 'Program', ok: true, error: null }, { name: 'b.nca', type: 'Meta', ok: false, error: 'bad' }] };
  else if (u.startsWith('/api/settings')) body = { prodKeysPath: '', titleKeysPath: '', outputDir: '', language: 'zh-CN', theme: 'dark', workers: 1, compressLevel: 17, defaultView: 'info', titlesDbPath: '', titlesDbLoaded: false, titlesDbCount: 0, titlesAutoUpdate: false, titlesUpdatedAt: '', titleKeysFromJson: 0, keysLoaded: true, keysError: null };
  else if (u.startsWith('/api/browse')) body = { path: 'D:/', parent: null, entries: [{ name: 'x', path: 'D:/x', isDir: true, size: 0 }, { name: 'base.nsp', path: 'D:/x/base.nsp', isDir: false, size: 1 }] };
  else if (u.startsWith('/api/jobs/')) body = { id: 'j1', type: 'Verify', status: 'Done', inputs: ['D:/x/base.nsp'], outputPath: 'OK', error: null, progressPct: 100 };
  else if (u.startsWith('/api/jobs')) body = opt && opt.method === 'POST' ? { id: 'j1' } : [{ id: 'j1', type: 'UpdBase', status: 'Done', inputs: ['D:/x/base.nsz'], outputPath: 'OK', error: null, progressPct: 99, detail: '[3/3] 重新压缩为 NSZ（等级 12）', stages: [{ name: '[1/3] 解压输入 1/1', elapsedMs: 1500, done: true }, { name: '[3/3] 重新压缩为 NSZ', elapsedMs: 800, done: true }] }];
  else if (u.startsWith('/api/logs')) body = ['log line'];
  else body = {};
  return Promise.resolve({ ok: true, json: () => Promise.resolve(body), text: () => Promise.resolve('') });
};
window.EventSource = function () { this.close = () => {}; };
const errors = [];
window.addEventListener('error', e => errors.push('onerror: ' + ((e.error && e.error.stack) || e.message)));

// Run both scripts in ONE sloppy-mode global eval so their top-level function
// declarations (t, initLang, openView, setCurrentFile, …) become callable globals.
const src = (i18n + '\n' + app).replace(/^\s*['"]use strict['"];?\s*$/gm, '');
window.eval(src);
window.document.dispatchEvent(new window.Event('DOMContentLoaded'));

const OPS = ['Info','ConvertNspToXci','ConvertXciToNsp','CompressNsz','DecompressNsz','CompressXcz','DecompressXcz','PackXci','UpdBase','PatchRsv','RemoveTitleKey','Restore','SetCgame','SetEshop','SetCnmtTitleId','SetCnmtVersion','RelinkAccount','TrimXci','SuperTrimXci','EraseDeltas','SplitTitles','Extract','GenXml','Rename','Database','ReadNpdm','Verify','SplitFat32','MergeFat32','JoinFile'];
const FACETS = ['Info','Titles','Nacp','Npdm','Cnmt','Verify'];
const sleep = ms => new Promise(r => setTimeout(r, ms));

(async () => {
  await sleep(150);
  const doc = window.document, $ = id => doc.getElementById(id);
  const out = [];
  const selOpts = Array.from($('set-defaultview').options).map(o => o.value);
  // app-bar function dropdown removed (left nav is the source)
  out.push([$('sel-view') === null, 'app-bar sel-view removed', $('sel-view') ? 'still present' : 'gone']);
  // The default-page select lists the landing + every operation + jobs; Info/Verify are facets (tabs), not items.
  const DROPDOWN_OPS = OPS.filter(o => o !== 'Info' && o !== 'Verify' && o !== 'Database' && o !== 'ReadNpdm' && o !== 'PatchKeygen');   // Database is a facet; ReadNpdm/PatchKeygen removed (merged into PatchRsv)
  const missing = DROPDOWN_OPS.filter(o => !selOpts.includes(o));
  out.push([missing.length === 0 && selOpts.includes('info') && selOpts.includes('jobs'), 'default-page select has all ' + DROPDOWN_OPS.length + ' ops +info+jobs', 'missing=' + missing.join(',') + ' n=' + selOpts.length]);

  // titles.json update notice must be prominent when not loaded
  const notice = $('titles-notice');
  out.push([!!notice && !notice.classList.contains('is-hidden') && $('tn-text').textContent.trim().length > 3, 'titles notice shown', notice ? $('tn-text').textContent.trim().slice(0, 40) : 'no #titles-notice']);

  // left nav must have a 信息/Info home entry (return from any page)
  out.push([/mif-home/.test($('nv-menu').innerHTML), 'nav has 信息 home entry', $('nv-menu').textContent.slice(0, 20)]);

  window.setCurrentFile('D:/x/base.nsp'); await sleep(150);
  out.push([$('ws-content').textContent.trim().length > 10, 'info after pick', $('ws-content').textContent.trim().slice(0, 40)]);

  for (const f of FACETS) {
    doc.querySelector(`#mat-tabs a[data-facet="${f}"]`).dispatchEvent(new window.Event('click', { bubbles: true })); await sleep(160);
    const t = $('ws-content').textContent.trim();
    const ok = f !== 'Verify' ? t.length > 4 : /校验失败|Verification failed|b\.nca/.test(t) && /a\.nca/.test(t);   // must list each file
    out.push([ok, 'facet ' + f, t.slice(0, 40).replace(/\n/g, ' ')]);
  }
  for (const op of OPS) { window.openView(op); await sleep(60); const t = $('ws-content').textContent.trim(); out.push([t.length > 3, 'op ' + op, t.slice(0, 28).replace(/\n/g, ' ')]); }
  window.openView('jobs'); await sleep(60);
  out.push([$('ws-content').textContent.trim().length > 3, 'jobs view', $('ws-content').textContent.trim().slice(0, 28)]);
  const jhtml = $('ws-content').innerHTML;
  out.push([/class="job-stages"/.test(jhtml) && /解压输入/.test(jhtml) && /1\.5s/.test(jhtml) && !/class="job-detail"/.test(jhtml), 'job card: expandable stage/time, no duplicate step line', /job-stages/.test(jhtml) ? (/class="job-detail"/.test(jhtml) ? 'DUP job-detail' : 'stages only ✓') : 'missing']);

  let fail = 0;
  for (const [ok, label, detail] of out) { if (!ok) fail++; console.log((ok ? 'PASS ' : 'FAIL ') + label.padEnd(26) + ' | ' + detail); }

  // ── Global i18n + menu parity (source-level; independent of the DOM) ──────────────────
  const px = [];
  const grpRe = /group:\s*'(\w+)',\s*items:\s*\[([^\]]*)\]/g;
  const groups = {}; let gm;
  while ((gm = grpRe.exec(app))) groups[gm[1]] = (gm[2].match(/'([^']+)'/g) || []).map(s => s.slice(1, -1));
  const navIds = Object.values(groups).flat();
  px.push([!!groups.navConvert && groups.navConvert.length === 6 && !groups.navConvert.some(x => ['PackXci', 'Extract', 'SplitTitles', 'UpdBase'].includes(x)), 'menu: navConvert = 6 convert-only', JSON.stringify(groups.navConvert)]);
  px.push([!!groups.navPack && ['PackXci', 'Extract', 'SplitTitles', 'UpdBase'].every(x => groups.navPack.includes(x)), 'menu: navPack = pack/split ops', JSON.stringify(groups.navPack)]);

  const locales = ['en-US', 'zh-CN', 'ja-JP', 'ko-KR'];
  const anchors = [i18n.indexOf("'en-US'"), i18n.indexOf("I18N['zh-CN']"), i18n.indexOf("I18N['ja-JP']"), i18n.indexOf("I18N['ko-KR']"), i18n.length];
  const slice = l => i18n.slice(anchors[locales.indexOf(l)], anchors[locales.indexOf(l) + 1]);
  px.push([anchors.every(a => a >= 0), 'i18n: 4 locale blocks found', anchors.join(',')]);
  px.push([locales.every(l => ['navConvert', 'navPack', 'navModify', 'navTidy'].every(k => slice(l).includes(k + ':'))), 'i18n: nav* labels in all locales', '']);

  // collect act.<id> values per id (value is always single-quoted)
  const actVals = {};
  const avRe = /['"]act\.([A-Za-z0-9]+)['"]\s*:\s*'([^']*)'/g; let av;
  while ((av = avRe.exec(i18n))) (actVals[av[1]] ||= []).push(av[2]);

  const missAct = navIds.filter(id => locales.some(l => !new RegExp("act\\." + id + "['\"]").test(slice(l)))).map(id => id);
  px.push([missAct.length === 0, 'i18n: act.* present for every menu op ×4 locales', 'missing=' + missAct.join(',')]);
  px.push([/act\.PatchKeygen|desc\.PatchKeygen/.test(i18n) ? false : true, 'i18n: no PatchKeygen leftovers', '']);
  const paren = navIds.filter(id => (actVals[id] || []).some(v => /[()（）]/.test(v)));
  px.push([paren.length === 0, 'i18n: menu labels free of parentheses', 'offenders=' + paren.join(',')]);

  let pxfail = 0;
  for (const [ok, label, detail] of px) { if (!ok) pxfail++; console.log((ok ? 'PASS ' : 'FAIL ') + ('PARITY ' + label).padEnd(48) + ' | ' + detail); }
  fail += pxfail;
  if (errors.length) { fail += errors.length; console.log('JS ERRORS:\n' + errors.join('\n')); }
  console.log(fail ? `\n${fail} PROBLEM(S)` : '\nALL PAGES RENDER — OK (' + out.length + ' checks)');
  process.exit(fail ? 1 : 0);
})();
