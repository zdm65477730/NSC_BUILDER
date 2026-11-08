/* ── NSC_BUILDER ─ Metro info-centric dashboard ─ vanilla JS, no build ───────────── */
'use strict';

// ── State ──────────────────────────────────────────────────────────────────────────
let mode = 'info';          // 'info' | 'op' | 'jobs'
let activeFacet = 'Info';   // Info|Titles|Nacp|Npdm|Cnmt|Verify
let currentOp = null;
let _renderedOp = null;   // last op whose page was rendered; selection is cleared when this changes (per-task independence)
let expandedGroup = null;   // which 二级 menu is expanded (accordion)
let currentFile = null;     // single file for the info facets
let selectedFiles = [];     // [{name,path,size,isDir}] for operations
let lastInfo = null, lastNpdm = null;
let cachedSettings = {};
let eventSource = null;
let dirPickerCallback = null, dirPickerFileMode = false;
let allJobs = [];

// ── Catalogue ────────────────────────────────────────────────────────────────────
const FACETS = [['Info', 'mif-info'], ['Titles', 'mif-list'], ['Nacp', 'mif-tag'], ['Npdm', 'mif-lock'], ['Cnmt', 'mif-list-numbered'], ['Verify', 'mif-checkmark'], ['Database', 'mif-database']];
const OP_GROUPS = [
  { group: 'navConvert', items: ['ConvertNspToXci', 'ConvertXciToNsp', 'CompressNsz', 'DecompressNsz', 'CompressXcz', 'DecompressXcz'] },
  { group: 'navPack', items: ['PackXci', 'Extract', 'SplitTitles', 'UpdBase'] },
  { group: 'navModify', items: ['PatchRsv', 'RemoveTitleKey', 'Restore', 'SetCgame', 'SetEshop', 'SetCnmtTitleId', 'SetCnmtVersion', 'RelinkAccount'] },
  { group: 'navTidy', items: ['TrimXci', 'SuperTrimXci', 'EraseDeltas', 'GenXml', 'Rename', 'SplitFat32', 'JoinFile'] },
];
// Two selection models:
//  REPLACE (single-file-per-item ops): each "add files"/"add folder" REPLACES the whole list (you can still pick
//          many files or a whole folder at once); picking again replaces the previous batch. Submitted as one job
//          PER file so the queue runs them in parallel (bounded by workers).
//  APPEND  (combine/accumulate ops: Pack, UpdBase, JoinFile): adds accumulate into the list, de-duplicated by path.
//          Pack/UpdBase submit as ONE combined job (they need all inputs together); JoinFile fans out per unit.
const REPLACE = new Set([
  'ConvertNspToXci', 'ConvertXciToNsp', 'CompressNsz', 'DecompressNsz', 'CompressXcz', 'DecompressXcz',
  'PatchRsv', 'RemoveTitleKey', 'Restore', 'SetCgame', 'SetEshop', 'SetCnmtTitleId', 'SetCnmtVersion', 'RelinkAccount',
  'Extract', 'SplitTitles',
  'TrimXci', 'SuperTrimXci', 'EraseDeltas', 'GenXml', 'SplitFat32', 'Rename',
]);
const APPEND = new Set(['PackXci', 'UpdBase', 'JoinFile']);
const PER_FILE = new Set([...REPLACE, 'JoinFile']);   // fan out to one job per file
// Accepted input type per op: 'game' (isGameFile), 'any', 'join' (.zip or a .NN split part), or an array of
// lowercase extensions. Filters the picker, folder scans and drops so only the right type enters the list.
const ACCEPT = {
  ConvertNspToXci: ['.nsp', '.nsz'], ConvertXciToNsp: ['.xci', '.xcz'],
  CompressNsz: ['.nsp'], DecompressNsz: ['.nsz'], CompressXcz: ['.xci'], DecompressXcz: ['.xcz'],
  PatchRsv: ['.nsp', '.nsz', '.xci', '.xcz'], RemoveTitleKey: ['.nsp', '.nsz'], Restore: ['.nsp', '.nsz', '.xci', '.xcz'],
  SetCgame: ['.nsp', '.nsz', '.xci', '.xcz'], SetEshop: ['.nsp', '.nsz', '.xci', '.xcz'],
  SetCnmtTitleId: ['.nsp', '.nsz', '.xci', '.xcz'], SetCnmtVersion: ['.nsp', '.nsz', '.xci', '.xcz'], RelinkAccount: ['.nsp', '.nsz'],
  Extract: ['.nsp', '.nsz', '.xci', '.xcz'], SplitTitles: ['.nsp', '.nsz', '.xci', '.xcz'],
  TrimXci: ['.xci', '.xcz'], SuperTrimXci: ['.xci', '.xcz'], EraseDeltas: ['.xci', '.xcz'], GenXml: ['.nsp', '.nsz', '.xci', '.xcz'],
  Rename: 'game', SplitFat32: 'any', JoinFile: 'join', PackXci: 'game', UpdBase: ['.nsp', '.nsz'],
};
function acceptFn(op) {
  const a = ACCEPT[op];
  if (a === 'any') return () => true;
  if (a === 'join') return n => /\.zip$/i.test(n) || /\.\d{2}$/.test(n);
  if (a === 'game') return isGameFile;
  if (Array.isArray(a)) return n => { const l = n.toLowerCase(); return a.some(e => l.endsWith(e)); };
  return isGameFile;   // default: game containers
}
const DESC_KEYS = { UpdBase: 'hintUpdBase', Rename: 'hintRename', Database: 'hintDatabase', Restore: 'hintRestore', SetCgame: 'hintSetCgame', SetEshop: 'hintSetEshop', SetCnmtTitleId: 'hintTitleId', SetCnmtVersion: 'hintVersion', RemoveTitleKey: 'hintRemoveTitleKey' };

// ── Helpers ────────────────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
function fmtSize(b) { return fmtBytesFmt(b); }
function mk(tag, cls) { const e = document.createElement(tag); if (cls) e.className = cls; return e; }
function base(p) { return (p || '').replace(/[/\\]+$/, '').split(/[/\\]/).pop() || p || ''; }
function fileIcon(name) { const e = (name.split('.').pop() || '').toLowerCase(); return ({ nsp: '📦', nsz: '🗜', xci: '💿', xcz: '🗄', nca: '🔐', ncz: '🗝' })[e] || '📄'; }
async function readErr(r) { try { const j = await r.json(); return j.error || j.detail || (r.status + ''); } catch (_) { try { return await r.text() || (r.status + ''); } catch (__) { return r.status + ''; } } }
function mapError(m) { if (!m) return t('errGeneric'); const s = String(m);
  if (/not supported|NCA2|NCA0|ACFC|compressed/i.test(s)) return t('errUnsupported') + ' — ' + s;
  if (/keys|header_key|MissingKey|title\.keys|prod\.keys/i.test(s)) return t('errKeys') + ' — ' + s;
  if (/not an|Unsupported|InvalidData|corrupt|HFS0|PFS0|hash|magic|NCA|NPDM|main.npdm/i.test(s)) return t('errFormat') + ' — ' + s;
  if (/No inputs|at least one|No Meta|No cnmt|No readable|No rebuildable|No Program/i.test(s)) return t('errNoInput') + ' — ' + s;
  return t('errGeneric') + ' — ' + s; }
async function apiGet(u) { const r = await fetch(u); if (!r.ok) throw new Error(await readErr(r)); return r.json(); }
async function apiPost(u, b) { const r = await fetch(u, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(b) }); if (!r.ok) throw new Error(await readErr(r)); return r.json(); }
async function apiPut(u, b) { const r = await fetch(u, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(b) }); if (!r.ok) throw new Error(await readErr(r)); return r.json(); }
async function apiDelete(u) { const r = await fetch(u, { method: 'DELETE' }); return r.ok; }

// ── Init ───────────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', async () => {
  initLang();
  try { cachedSettings = JSON.parse(localStorage.getItem('nscb-settings') || 'null') || {}; } catch (_) { cachedSettings = {}; }
  bindEvents(); applyI18n(); buildViewMenu(); renderNav(); syncTabs(); setupDrop();
  openView(cachedSettings.defaultView || 'info');   // instant, from last-run cache — no waiting on the slow first /api/settings
  await loadSettings();                              // authoritative (first call can take seconds: key/title loading)
  const want = cachedSettings.defaultView || 'info';
  if (want !== currentViewValue()) openView(want);   // only switch if the server value differs from the cached one
  loadJobs(); connectSSE(); startBarEase();
});
function refreshI18n() { applyI18n(); buildViewMenu(); renderNav(); syncTabs(); syncSelView();
  if (mode === 'info') renderFacet(); else if (mode === 'op') renderOp(); else renderJobs(); }

// All pages: 'info' landing + every operation + jobs. Used by the top-right dropdown and the default-page setting.
function pageList() {
  const list = [{ v: 'info', c: t('facetInfo') }];
  for (const g of OP_GROUPS) for (const id of g.items) list.push({ v: id, c: t('act.' + id), grp: t(g.group) });
  list.push({ v: 'jobs', c: t('jobsQueue') });
  return list;
}
function fillSelect(sel) {
  sel.innerHTML = '';
  let curGrp = null, og = sel;
  for (const p of pageList()) {
    if (p.grp !== curGrp) { curGrp = p.grp; if (p.grp) { og = mk('optgroup'); og.label = p.grp; sel.appendChild(og); } else og = sel; }
    const o = mk('option'); o.value = p.v; o.textContent = p.c; og.appendChild(o);
  }
}
function buildViewMenu() { fillSelect($('set-defaultview')); }
function currentViewValue() { return mode === 'jobs' ? 'jobs' : mode === 'op' ? currentOp : 'info'; }
function syncSelView() { const sel = $('sel-view'); if (!sel) return; const v = currentViewValue(); if ([...sel.options].some(o => o.value === v)) sel.value = v; }
function openView(v) {
  if (v === 'info') { mode = 'info'; expandedGroup = null; }
  else if (v === 'jobs') { mode = 'jobs'; expandedGroup = null; }
  else { if (v !== currentOp) selectedFiles = []; mode = 'op'; currentOp = v; expandedGroup = groupOf(v); }   // each task has an independent file/folder selection; opening a 二级 keeps only its 一级 expanded
  renderNav(); syncTabs(); syncSelView();
  if (mode === 'info') renderFacet(); else if (mode === 'op') renderOp(); else renderJobs();
}

// ── Events ─────────────────────────────────────────────────────────────────────────
function bindEvents() {
  $('btn-nav-toggle').onclick = () => $('navview').classList.toggle('compact');
  $('btn-settings').onclick = openSettings; $('keys-badge').onclick = openSettings;
  $('btn-close-settings').onclick = () => $('modal-overlay').classList.add('hidden');
  $('btn-save-settings').onclick = saveSettings;
  $('btn-fetch-db').onclick = e => fetchTitlesDb(e.currentTarget);
  $('tn-update').onclick = e => fetchTitlesDb(e.currentTarget);
  $('tn-dismiss').onclick = () => { titlesDismissed = true; updateNotice(); };
  $('tn-auto').onchange = async e => { try { cachedSettings = await apiPut('/api/settings', { titlesAutoUpdate: !!e.target.checked }); updateNotice(); } catch (_) {} };
  $('btn-pick-file') && ($('btn-pick-file').onclick = () => openDirPickerEx({ fileMode: true, start: startHint(), title: t('pickFile'), onPick: p => setCurrentFile(p) }));
  $('btn-pick-folder') && ($('btn-pick-folder').onclick = () => openDirPickerEx({ fileMode: false, start: startHint(), title: t('pickFolder'), onPick: p => addFromFolder(p) }));
  $('btn-logs').onclick = openLogs; $('btn-close-logs').onclick = closeLogs; $('btn-log-refresh').onclick = fetchLogs; $('btn-log-copy').onclick = copyLogs; $('chk-log-auto').onchange = e => toggleLogAuto(e.target.checked);
  $('mat-tabs').querySelectorAll('a').forEach(a => a.onclick = () => { mode = 'info'; activeFacet = a.dataset.facet; renderNav(); syncTabs(); renderFacet(); });
  // (app-bar function dropdown removed — the left nav is the single source.)
  const langSel = $('sel-lang'); if (langSel) langSel.onchange = async e => { setLang(e.target.value); refreshI18n(); try { await apiPut('/api/settings', { language: e.target.value }); } catch (_) {} }; if (langSel) langSel.value = getLang();
  document.querySelectorAll('.btn-browse').forEach(b => b.onclick = () => openDirPicker(b.dataset.target, b.dataset.filemode === '1', b.dataset.any === '1'));
  // dir picker controls
  $('btn-close-dirpicker').onclick = closeDirPicker; $('btn-dp-go').onclick = () => dirPickerBrowse($('dp-path').value);
  $('btn-dp-up').onclick = () => dirPickerBrowse(($('dp-path').value || '').replace(/[/\\][^/\\]*[/\\]?$/, '') || undefined);
  $('dp-path').onkeydown = e => { if (e.key === 'Enter') dirPickerBrowse(e.target.value); };
  $('btn-dp-ok').onclick = () => { if (dirPickerCallback) dirPickerCallback($('dp-path').value, false); closeDirPicker(); };
}

// ── Navview ────────────────────────────────────────────────────────────────────────
function renderNav() {
  // Two-level: 6 一级 items (信息 + 4 组 + 任务). 二级 children show only under an expanded/clicked parent.
  const m = $('nv-menu'); m.innerHTML = '';
  m.appendChild(navItem(t('facetInfo'), 'mif-home', mode === 'info', () => openView('info')));
  for (const g of OP_GROUPS) {
    const hasActive = mode === 'op' && g.items.includes(currentOp);
    const open = expandedGroup === g.group;   // single source of truth → selecting/clicking another collapses the rest
    m.appendChild(navItem(t(g.group), groupIcon(g.group), hasActive, () => { expandedGroup = open ? null : g.group; renderNav(); }, open, true));
    if (open) for (const id of g.items) m.appendChild(navItem(t('act.' + id), opIcon(id), mode === 'op' && currentOp === id, () => openView(id), false, false, true));
  }
  m.appendChild(navItem(t('jobsQueue'), 'mif-stack2', mode === 'jobs', () => openView('jobs')));
}
function groupOf(id) { const g = OP_GROUPS.find(x => x.items.includes(id)); return g ? g.group : null; }
function groupIcon(grp) { return ({ navConvert: 'mif-shuffle', navModify: 'mif-wrench', navTidy: 'mif-tools', navView: 'mif-database' })[grp] || 'mif-menu'; }
function navItem(label, icon, active, onclick, open = false, isParent = false, isChild = false) {
  const a = mk('a'); a.href = '#';
  a.className = (isChild ? 'nv-child' : 'nv-item') + (isParent ? ' nv-parent' : '') + (active ? ' active' : '') + (open ? ' open' : '');
  const chev = isParent ? `<span class="chev">${open ? '▾' : '▸'}</span>` : '';
  a.innerHTML = `<span class="nv-icon"><span class="${icon}"></span></span><span class="nv-caption">${esc(label)}</span>${chev}`;
  a.onclick = e => { e.preventDefault(); onclick(); };
  const li = mk('li'); li.appendChild(a); return li;
}
function addHeader(ul, txt) { const li2 = mk('li', 'item-header'); li2.textContent = txt; ul.appendChild(li2); }
function li(a) { const l = mk('li'); l.appendChild(a); return l; }
function mkLink(kind, val, caption, icon, active) {
  const a = mk('a'); a.href = '#'; if (active) a.className = 'active';
  a.innerHTML = `<span class="nv-icon"><span class="${icon || 'mif-menu'}"></span></span><span class="nv-caption">${esc(caption)}</span>`;
  a.onclick = e => { e.preventDefault(); if (kind === 'op' || kind === 'info') openView(val); else onNav(kind, val); };
  return a;
}
// Database facet: batch-export a folder of games (moved here from the 查看 group; ReadNpdm is
// redundant with the Npdm tab and was removed). Runs a Database job on the chosen folder.
async function renderDatabase(el) {
  const facet = activeFacet;
  const dir = currentFile ? currentFile.replace(/[/\\][^/\\]*$/, '') : (cachedSettings.outputDir || '');
  el.innerHTML = `<h2 class="sec-title">${esc(t('facetDatabase'))}</h2>` +
    `<div class="file-tools" style="margin-top:10px"><input id="db-dir" type="text" value="${esc(dir)}" placeholder="${esc(t('pathPh'))}" style="flex:1;min-width:200px">` +
    `<button id="db-browse" class="btn-sm">${esc(t('browse'))}</button>` +
    `<select id="db-format"><option value="html">HTML</option><option value="csv">CSV</option><option value="tsv">TSV</option><option value="json">JSON</option></select>` +
    `<button id="db-run" class="btn-sm primary">${esc(t('submit'))}</button></div>` +
    `<div id="db-hint" class="hint" style="margin:6px 0"></div><div id="db-out" class="job-list"></div>`;
  $('db-browse').onclick = () => openDirPickerEx({ fileMode: false, start: $('db-dir').value || startHint(), title: t('addFolder'), onPick: p => { $('db-dir').value = p; } });
  $('db-run').onclick = async () => {
    const hint = $('db-hint'); const folder = ($('db-dir').value || '').trim();
    if (!folder) { hint.textContent = t('needFiles'); hint.className = 'hint warn'; return; }
    try {
      hint.textContent = t('loading'); hint.className = 'hint';
      const res = await apiPost('/api/jobs', { type: 'Database', inputs: [folder], options: { format: $('db-format').value } });
      let j;
      for (let k = 0; k < 3600; k++) {                       // poll this job to terminal state (independent of SSE)
        await new Promise(r => setTimeout(r, 1000));
        if (activeFacet !== facet) return;
        j = await apiGet('/api/jobs/' + res.id);
        if (['Done', 'Failed', 'Cancelled'].includes(j.status)) break;
        hint.textContent = `${j.status} ${j.progressPct || 0}%`; hint.className = 'hint';
      }
      if (activeFacet !== facet) return;
      const ok = j && j.status === 'Done';
      hint.textContent = ok ? (j.outputPath || 'Done') : `${j ? j.status : '?'}: ${(j && j.error) || t('verifyFail')}`;
      hint.className = 'hint ' + (ok ? 'ok' : 'err');
      await loadJobs();
    } catch (err) { if (activeFacet === facet) { hint.textContent = mapError(err.message); hint.className = 'hint err'; } }
  };
}
function opIcon(id) { return ({ ConvertNspToXci: 'mif-shuffle', ConvertXciToNsp: 'mif-shuffle', CompressNsz: 'mif-file-zip', DecompressNsz: 'mif-file-archive', CompressXcz: 'mif-file-zip', DecompressXcz: 'mif-file-archive', PackXci: 'mif-stack3', UpdBase: 'mif-inbox', PatchRsv: 'mif-equalizer', RemoveTitleKey: 'mif-unlock', Restore: 'mif-undo', SetCgame: 'mif-gamepad', SetEshop: 'mif-cloud-download', SetCnmtTitleId: 'mif-credit-card', SetCnmtVersion: 'mif-refresh', RelinkAccount: 'mif-link', TrimXci: 'mif-cut', SuperTrimXci: 'mif-cut', EraseDeltas: 'mif-bin', SplitTitles: 'mif-crop', Extract: 'mif-download2', GenXml: 'mif-file-code', Rename: 'mif-tag', Database: 'mif-database', ReadNpdm: 'mif-lock', Verify: 'mif-checkmark', Info: 'mif-info', SplitFat32: 'mif-copy', MergeFat32: 'mif-attachment', JoinFile: 'mif-link' })[id] || 'mif-menu'; }
function onNav(kind, val) {
  if (kind === 'facet') { mode = 'info'; activeFacet = val; }
  else if (kind === 'jobs') { mode = 'jobs'; }
  renderNav(); syncTabs(); syncSelView();
  if (mode === 'info') renderFacet(); else renderJobs();
}
function syncTabs() { $('mat-tabs').style.display = mode === 'info' ? 'flex' : 'none'; $('mat-tabs').querySelectorAll('a').forEach(a => a.classList.toggle('active', mode === 'info' && a.dataset.facet === activeFacet)); }

// ── Current file / folders ───────────────────────────────────────────────────────────
function startHint() { return currentFile ? (currentFile.replace(/[/\\][^/\\]*$/, '') || currentFile) : (cachedSettings.outputDir || ''); }
function setCurrentFile(p) { currentFile = p; lastInfo = null; const cf = $('cur-file'); if (cf) { cf.textContent = base(p); cf.title = p; } addEntry(p, false, true); mode = 'info'; renderNav(); syncTabs(); renderFacet(); prefetchCurrent(); }
function addEntry(path, isDir) { if (!path) return; if (isDir) { addFromFolder(path); return; } setSelection([path]); }
// Replace-or-append the selection with these file paths, filtered by the op's accepted type.
// REPLACE ops overwrite the whole list; APPEND ops accumulate (de-duplicated by full path).
function setSelection(paths) {
  const pred = acceptFn(currentOp), append = APPEND.has(currentOp);
  const files = (paths || []).filter(p => p && !/[/\\]$/.test(p) && pred(base(p)));
  if (append) { for (const p of files) if (!selectedFiles.some(f => f.path === p)) selectedFiles.push({ name: base(p), path: p, size: 0, isDir: false }); }
  else { selectedFiles = files.map(p => ({ name: base(p), path: p, size: 0, isDir: false })); }
  if (mode === 'op') renderSel();
}
// A supported game container (incl. FAT32 split parts like *.nsp.00).
function isGameFile(n) { return /\.(nsp|nsz|xci|xcz|nca|ncz)(\.\d{2,})?$/i.test(n); }
// Pick/drop a folder → load every accepted game file inside it, INCLUDING subfolders, then replace-or-append.
async function addFromFolder(dir) {
  if (!dir) return;
  try {
    const pred = acceptFn(currentOp);
    const r = await apiGet('/api/browse?path=' + encodeURIComponent(dir) + '&recurse=1');
    const paths = (r.entries || []).filter(e => !e.isDir && pred(e.name)).map(e => e.path);
    if (!paths.length) { toast(t('folderEmpty')); return; }
    setSelection(paths);
  } catch (err) { toast(mapError(err.message)); }
}
let _toastTimer = null;
function toast(msg) {
  let el = $('toast');
  if (!el) { el = mk('div'); el.id = 'toast'; el.className = 'toast'; document.body.appendChild(el); }
  el.textContent = msg; el.classList.add('show');
  clearTimeout(_toastTimer); _toastTimer = setTimeout(() => el.classList.remove('show'), 2600);
}
// Best-effort drag-drop. WebView2 usually hides the absolute path of OS files; when a runtime
// exposes File.path we use it, otherwise we tell the user to pick a folder (which loads all files).
function setupDrop() {
  const dz = $('dropzone'); let depth = 0;
  const onEnter = e => { e.preventDefault(); if (++depth === 1 && dz) { $('dz-text').textContent = t('dropHere'); dz.classList.remove('is-hidden'); } };
  const onLeave = e => { e.preventDefault(); if (--depth <= 0) { depth = 0; if (dz) dz.classList.add('is-hidden'); } };
  const onOver = e => { e.preventDefault(); if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy'; };
  window.addEventListener('dragenter', onEnter); window.addEventListener('dragover', onOver); window.addEventListener('dragleave', onLeave);
  window.addEventListener('drop', async e => {
    e.preventDefault(); depth = 0; if (dz) dz.classList.add('is-hidden');
    const files = e.dataTransfer && e.dataTransfer.files ? Array.from(e.dataTransfer.files) : [];
    if (!files.length) return;
    // WebView2: hand the File objects to the native host; it replies (window.__nativeDrop) with real absolute paths.
    const ctw = window.chrome && window.chrome.webview && window.chrome.webview.postMessageWithAdditionalObjects;
    if (ctw) {
      window.__nscbDropPending = files.length;
      try { window.chrome.webview.postMessageWithAdditionalObjects('nscb-drop', files); }
      catch (err) { window.__nscbDropPending = 0; toast('postMessage failed: ' + ((err && err.message) || err)); }
      setTimeout(() => { if (window.__nscbDropPending) { window.__nscbDropPending = 0; toast(t('dropNoPath')); } }, 3500);
      return;
    }
    const withPath = files.filter(f => f.path);   // fallback for hosts that expose File.path
    if (!withPath.length) { toast(t('dropNoPath')); return; }
    withPath.forEach(f => addFromPath(f.path)); renderSel();
  });
}
// Route a dropped path: a recognized file/container → batch-add; anything else → treat as a folder and load it.
function looksLikeFile(n) { return isGameFile(n) || /\.zip$/i.test(n) || /\.\d{2}$/.test(n); }
function addFromPath(p) { if (!p) return; if (looksLikeFile(base(p))) setSelection([p]); else addFromFolder(p); }
window.__nativeDrop = function (paths) {
  window.__nscbDropPending = 0;
  try {
    const list = paths || [];
    if (mode === 'info') { const f = list.find(p => isGameFile(base(p))); if (f) { setCurrentFile(f); return; } }
    if (mode === 'op') {
      const files = list.filter(p => looksLikeFile(base(p)));
      const dirs = list.filter(p => !looksLikeFile(base(p)));
      if (files.length) setSelection(files);           // batch: REPLACE overwrites, APPEND accumulates
      dirs.forEach(d => addFromFolder(d));             // folder(s) expand recursively
      return;
    }
    list.forEach(p => addFromPath(p));
  } catch (_) {}
};
function removeFile(i) { selectedFiles.splice(i, 1); renderSel(); }

// ── Facet rendering (info) ─────────────────────────────────────────────────────────
async function renderFacet() {
  const el = $('ws-content'); const facet = activeFacet;
  // Database is a folder operation — no current-file pick needed.
  if (facet === 'Database') { el.innerHTML = ''; const b = mk('div'); el.appendChild(b); return renderDatabase(b); }
  // No file loaded: show the load button + hint.
  if (!currentFile) { el.innerHTML = nudgeEmpty(); $('btn-empty-pick').onclick = () => openDirPickerEx({ fileMode: true, start: startHint(), title: t('pickFile'), onPick: p => setCurrentFile(p) }); return; }
  // File loaded: a slim bar lets the user pick another file; facet content renders below it.
  el.innerHTML = pickBar(); bindPickBar();
  const body = mk('div'); el.appendChild(body);
  if (facet === 'Npdm') return renderNpdm(body);
  if (facet === 'Verify') return runVerify(body);
  if (!cached(_info, currentFile)) body.innerHTML = `<div class="empty">${esc(t('loading'))}</div>`;
  let i; try { i = await ensureInfo(currentFile); } catch (err) { if (activeFacet === facet) body.innerHTML = `<div class="hint err">${esc(mapError(err.message))}</div>`; return; }
  if (activeFacet !== facet) return;
  if (facet === 'Info') body.innerHTML = infoPanel(i);
  else if (facet === 'Titles') body.innerHTML = titlesTable(i);
  else if (facet === 'Nacp') body.innerHTML = nacpPanel(i);
  else if (facet === 'Cnmt') body.innerHTML = cnmtPanel(i);
}
function nudgeEmpty() { return `<div class="nudge"><div class="nudge-icon"><span class="mif-file-empty"></span></div><p>${esc(t('pickHint'))}</p><button id="btn-empty-pick" class="btn-primary"><span class="mif-file-empty"></span> ${esc(t('pickFile'))}</button></div>`; }
function pickBar() { const cf = currentFile ? base(currentFile) : ''; return `<div class="info-bar"><button id="btn-info-pick" class="btn-sm primary"><span class="mif-file-empty"></span> ${esc(t('pickFile'))}</button>${cf ? `<span class="fb-cur" title="${esc(currentFile)}">${esc(cf)}</span>` : ''}</div>`; }
function bindPickBar() { const b = $('btn-info-pick'); if (b) b.onclick = () => openDirPickerEx({ fileMode: true, start: startHint(), title: t('pickFile'), onPick: p => setCurrentFile(p) }); }
function kv(pairs) { let h = '<div class="kv">'; for (const [k, v] of pairs) { if ((v === undefined || v === null || v === '') && v !== 0 && v !== false) continue; h += `<span class="k">${esc(k)}</span><span class="v">${esc(String(v))}</span>`; } return h + '</div>'; }
function infoPanel(i) {
  const icon = `<div class="imagebox"><img class="gameimg" src="/api/info/icon?path=${encodeURIComponent(i.path || currentFile)}" onerror="this.style.visibility='hidden'">` +
    `<p><strong>TitleId: </strong><span>${esc(i.titleId || '-')}</span></p>` +
    `<p><strong>${esc(t('lblType'))}: </strong><span>${esc(i.titleType || '-')}</span></p>` +
    `<p><strong>Genre: </strong><span>${esc(i.genre || '-')}</span></p>` +
    `<p><strong>Region: </strong><span>${esc(i.region || '-')}</span></p>` +
    `<p><strong>${esc(t('lblFwReq'))}: </strong><span>${esc(i.requiredSystemVersion || '-')}</span></p>` +
    `<p><strong>Size: </strong><span>${esc(fmtSize(i.fileSize))}</span></p></div>`;
  const fields = [
    [t('lblTitle'), i.titleName], [t('lblPublisher'), i.publisher], ['Developer', i.developer], [t('lblBaseId'), i.baseTitleId],
    [t('lblVersion'), i.titleVersion], ['Display Ver', i.displayVersion], [t('lblKeyGen'), i.keyGeneration], ['FW range', i.firmwareRangeFromKg],
    ['Format', (i.format || '').toUpperCase()], ['Rights key', i.hasTitleKeyCrypto ? 'yes' : 'no'], ['Title key', i.titleKeyAvailable ? 'available' : (i.hasTitleKeyCrypto ? 'needed' : 'n/a')],
  ];
  const warn = i.warnings?.length ? `<p class="hint warn">${esc(i.warnings.join('; '))}</p>` : '';
  return `<h2 class="sec-title">${esc(base(i.path || currentFile))}</h2><div class="info-wrap"><div style="flex:1;min-width:0">${kv(fields)}</div>${icon}</div>${warn}`;
}
function titlesTable(i) {
  const rows = (i.contents || []).map(c => `<tr><td>${esc(c.name)}</td><td>${esc(c.ncaType || c.kind || '')}</td><td>${esc(c.distribution || '')}</td><td>${c.titleId ? esc(String(c.titleId)) : ''}</td><td>${c.keyGeneration ?? ''}</td><td class="mono">${c.compressed ? 'NSZ' : ''}</td><td>${fmtSize(c.size)}</td></tr>`).join('');
  return `<h2 class="sec-title">Titles (${fmtNum((i.contents || []).length)})</h2><table class="mt"><thead><tr><th>Name</th><th>Type</th><th>Distribution</th><th>TitleId</th><th>KG</th><th>Comp</th><th>Size</th></tr></thead><tbody>${rows || '<tr><td colspan=7 class=empty>' + esc(t('noJobs')) + '</td></tr>'}</tbody></table>`;
}
function nacpPanel(i) {
  return `<h2 class="sec-title">NACP</h2>${kv([[t('lblTitle'), i.titleName], [t('lblPublisher'), i.publisher], ['Developer', i.developer], ['Genre', i.genre], ['Region', i.region], ['Display Version', i.displayVersion], [t('lblType'), i.titleType], [t('lblTitleId'), i.titleId], [t('lblVersion'), i.titleVersion]])}`;
}
function cnmtPanel(i) {
  const recs = (i.contents || []).map(c => `<tr><td>${esc(c.ncaType || c.kind || '')}</td><td>${c.titleId ? esc(String(c.titleId)) : ''}</td><td class="mono">${esc(c.name)}</td></tr>`).join('');
  return `<h2 class="sec-title">CNMT</h2>${kv([['Application Id', i.titleId], ['Owner/TitleId', i.titleId], [t('lblBaseId'), i.baseTitleId], [t('lblType'), i.titleType], [t('lblVersion'), i.titleVersion], ['Version (raw)', i.titleVersionRaw]])}
    <table class="mt" style="margin-top:16px"><thead><tr><th>Content Type</th><th>Content Id</th><th>File</th></tr></thead><tbody>${recs}</tbody></table>`;
}
// LRU caches so re-opening a recently-viewed file (Info / NPDM / Verify) is instant; those three are also
// prefetched in the background when a file is loaded. Keyed by path, capacity LRU_CAP.
const LRU_CAP = 12;
function makeLru(cap) {
  const m = new Map();
  return {
    get(p) { if (!m.has(p)) return null; const v = m.get(p); m.delete(p); m.set(p, v); return v; },   // touch = most-recent
    set(p, v) { m.set(p, v); while (m.size > cap) m.delete(m.keys().next().value); },
    del(p) { m.delete(p); },
  };
}
const _info = makeLru(LRU_CAP), _npdm = makeLru(LRU_CAP), _verify = makeLru(LRU_CAP);
function ensure(map, p, url) {
  const e0 = map.get(p);
  if (e0 && e0.data) return Promise.resolve(e0.data);
  if (e0 && e0.promise) return e0.promise;
  const e = { data: null, promise: null }; map.set(p, e);
  e.promise = apiGet(url + encodeURIComponent(p)).then(r => { e.data = r; return r; });
  e.promise.catch(() => { });
  return e.promise;
}
const ensureInfo = p => ensure(_info, p, '/api/info?path=');
const ensureNpdm = p => ensure(_npdm, p, '/api/npdm?path=');
const ensureVerify = p => ensure(_verify, p, '/api/verify?path=');
function cached(map, p) { const e = map.get(p); return e && e.data ? e.data : null; }
function prefetchCurrent() {   // background-warm the heavy reads for the loaded file
  const p = currentFile; if (!p) return;
  ensureInfo(p).then(() => { if (mode === 'info' && activeFacet === 'Info' && currentFile === p) renderFacet(); }).catch(() => { });
  ensureNpdm(p).then(() => { if (mode === 'info' && activeFacet === 'Npdm' && currentFile === p) renderFacet(); }).catch(() => { });
  ensureVerify(p).then(() => { if (mode === 'info' && activeFacet === 'Verify' && currentFile === p) renderFacet(); }).catch(() => { });
}
async function renderNpdm(el) {
  const facet = activeFacet, p = currentFile;
  if (!cached(_npdm, p)) el.innerHTML = `<div class="verify-run"><span class="spin"></span><span>${esc(t('npdmLoading'))}</span></div>`;
  try { const n = await ensureNpdm(p); if (activeFacet !== facet || currentFile !== p) return;
    const svc = (n.services || []).join(', ');
    el.innerHTML = `<h2 class="sec-title">NPDM</h2>` + kv([['Source', n.sourceFile], ['Title', n.titleName], ['Category', n.processCategory], ['TitleId', n.titleId], ['Acid Flags', n.acidFlags], ['FS Access Ver', n.fsAccessVersion], ['AllowedIdMin', n.allowedIdMin], ['AllowedIdMax', n.allowedIdMax]]) +
      (svc ? `<h3 style="margin:16px 0 4px">Services</h3><div class="v mono" style="word-break:break-all">${esc(svc)}</div>` : '');
  } catch (err) { if (activeFacet === facet) el.innerHTML = `<div class="hint err">${esc(mapError(err.message))}</div>`; }
}
async function runVerify(el) {
  const facet = activeFacet, p = currentFile;
  if (!cached(_verify, p)) el.innerHTML = `<h2 class="sec-title">${esc(t('facetVerify'))}</h2>` +
    `<div class="verify-run"><span class="spin"></span><span>${esc(t('verifyRunning'))}</span></div>`;
  try {
    const r = await ensureVerify(p);
    if (activeFacet !== facet || currentFile !== p) return;
    const cls = r.ok ? 'pass' : 'fail';
    let h = `<h2 class="sec-title">${esc(t('facetVerify'))}</h2>` +
      `<div class="vf-banner ${cls}"><span class="mif-${r.ok ? 'checkmark' : 'cross'}"></span> ${esc(r.ok ? t('verifyPass') : t('verifyFail'))}</div>` +
      `<div class="vf-meta">${esc(t('verifyChecked'))}: <strong>${fmtNum(r.checked)}</strong> / ${fmtNum(r.total)} NCA</div>`;
    if (r.files && r.files.length) {
      h += `<table class="mt"><thead><tr><th>#</th><th>File</th><th>Type</th><th>${esc(t('verifyResult'))}</th><th>Detail</th></tr></thead><tbody>` +
        r.files.map((f, i) => `<tr><td>${i + 1}</td><td class="mono">${esc(f.name)}</td><td>${esc(f.type)}</td>` +
          `<td class="${f.ok ? 'vf-ok' : 'vf-bad'}">${f.ok ? '✓ ' + esc(t('verifyOk')) : '✕ ' + esc(t('verifyBad'))}</td>` +
          `<td class="mono">${esc(f.error || '')}</td></tr>`).join('') + `</tbody></table>`;
    }
    h += `<div class="vf-actions"><button id="vf-rerun" class="btn-sm">${esc(t('verifyRerun'))}</button></div>`;
    el.innerHTML = h;
    $('vf-rerun').onclick = () => { _verify.del(currentFile); runVerify(el); };
  } catch (err) { if (activeFacet === facet) el.innerHTML = `<h2 class="sec-title">${esc(t('facetVerify'))}</h2><div class="hint err">${esc(mapError(err.message))}</div>`; }
}

// ── Operations workspace ───────────────────────────────────────────────────────────
function renderOp() {
  const op = currentOp, el = $('ws-content');
  if (op !== _renderedOp) { selectedFiles = []; _renderedOp = op; }   // each task starts with an empty, independent selection
  el.innerHTML = `<h1 class="op-title">${esc(t('act.' + op))}</h1><p class="op-desc">${esc(t('desc.' + op))}</p>
    <div class="files-sec">
      <div class="file-tools">
        <button id="btn-add-files" class="btn-sm">＋ ${esc(t('addFiles'))}</button>
        <button id="btn-add-dir" class="btn-sm">＋ ${esc(t('addFolder'))}</button>
        <button id="btn-clear-sel" class="btn-sm ghost">${esc(t('clear'))}</button>
        <input id="path-input" type="text" placeholder="${esc(t('pathPh'))}" spellcheck="false">
        <button id="btn-add-path" class="btn-sm">${esc(t('add'))}</button>
      </div>
      <ul id="selected-list" class="chips"></ul>
    </div>
    <div id="action-opts" class="opts">${(actionOptDefs[op] || (() => ''))()}</div>
    <div class="run-row"><button id="btn-submit" class="btn-primary">${esc(t('submit'))}</button><span id="submit-hint" class="hint"></span></div>
    <div id="op-jobs" class="job-list" style="margin-top:16px"></div>`;
  if (op === 'PackXci') _packnameEdited = false;
  renderSel(); renderOpJobs();
  $('btn-add-files').onclick = () => openDirPickerEx({ fileMode: true, multi: true, anyFile: ACCEPT[currentOp] === 'any', start: startHint(), title: t('addFiles'), onMany: paths => setSelection(paths) });
  if ($('btn-add-dir')) $('btn-add-dir').onclick = () => openDirPickerEx({ fileMode: false, start: startHint(), title: t('addFolder'), onPick: p => addFromFolder(p) });
  $('btn-clear-sel').onclick = () => { selectedFiles = []; renderSel(); };
  $('btn-add-path').onclick = () => { const p = $('path-input').value.trim(); if (!p) return; const isDir = /[\\/]$/.test(p) || !/\.[a-z0-9]{2,5}$/i.test(base(p)); if (isDir) addFromFolder(p); else setSelection([p]); $('path-input').value = ''; };
  $('path-input').onkeydown = e => { if (e.key === 'Enter') $('btn-add-path').click(); };
  $('btn-submit').onclick = submitJob;
}
function renderSel() {
  const ul = $('selected-list'); if (!ul) return; ul.innerHTML = '';
  selectedFiles.forEach((f, i) => {
    const li = mk('li', 'chip');
    li.innerHTML = `<span class="nv-icon">${f.isDir ? '📁' : fileIcon(f.name)}</span><span class="chip-name" title="${esc(f.path)}">${esc(f.name)}</span><button class="sel-remove">×</button>`;
    li.querySelector('.sel-remove').onclick = () => removeFile(i); ul.appendChild(li);
  });
  if (currentOp === 'PackXci') refreshPackName();
}
// Auto-fill the PackXci output name from the current selection (NSCB-style), until the user edits it.
let _packnameEdited = false, _packnameSeq = 0, _packnameTimer = null;
function refreshPackName() {
  const el = $('opt-packname'); if (!el) return;
  if (!el.oninput) el.oninput = () => { _packnameEdited = true; };
  if (_packnameEdited) return;
  clearTimeout(_packnameTimer);
  _packnameTimer = setTimeout(doPackName, 250);            // debounce bursts (folder load / multi-add)
}
async function doPackName() {
  const el = $('opt-packname'); if (!el || _packnameEdited) return;
  const paths = selectedFiles.map(f => f.path);
  if (!paths.length) { el.value = ''; return; }
  const seq = ++_packnameSeq;
  try {
    const r = await apiPost('/api/packname', { inputs: paths });
    if (seq === _packnameSeq && !_packnameEdited && document.getElementById('opt-packname') === el)  // ignore stale/out-of-order replies
      el.value = (r && r.name) ? r.name + (r.ext || '.xci') : '';
  } catch (_) {}
}

// per-op option HTML + collector (kept in sync with backend options)
const actionOptDefs = {
  Info: () => '', Verify: () => '', ReadNpdm: () => '', TrimXci: () => '', SuperTrimXci: () => '', EraseDeltas: () => '', GenXml: () => '', RelinkAccount: () => '', ConvertNspToXci: () => '', ConvertXciToNsp: () => '', DecompressNsz: () => '', DecompressXcz: () => '', SplitFat32: () => '',
  CompressNsz: () => '',
  CompressXcz: () => '',
  PatchRsv: () => `<div class="opt-row"><label>${t('optTargetFw')}</label><input id="opt-rsv" type="text" placeholder="${t('optFwPh')}"></div><div class="hint">${t('optFwHint')}</div>`,
  PackXci: () => `<div class="opt-row"><label>${t('optOutName')}</label><input id="opt-packname" type="text" placeholder="${t('optPhAuto')}"></div>`,
  MergeFat32: () => `<div class="opt-row"><label>${t('optOutName')}</label><input id="opt-mergename" type="text" placeholder="${t('optPhAuto')}"></div>`,
  SplitTitles: () => `<div class="opt-row"><label>${t('optOutDir')}</label><input id="opt-outdir" type="text" placeholder="${t('optOutDirPh')}"></div><div class="opt-row"><label class="chk"><input id="opt-basecard" type="checkbox"> ${t('optBaseAsCard')}</label><div class="hint">${t('optBaseAsCardHint')}</div></div>`,
  Extract: () => `<div class="opt-row"><label>${t('optFilter')}</label><select id="opt-filter"><option value="All">${t('optAll')}</option><option value="Program">Program</option><option value="Meta">Meta(cnmt)</option><option value="Control">Control</option><option value="Manual">Manual</option><option value="Data">Data</option><option value="PublicData">PublicData</option><option value="Ticket">Ticket</option><option value="Cert">Cert</option><option value="Xml">Xml</option></select></div><div class="opt-row"><label>${t('optOutDir')}</label><input id="opt-outdir" type="text"></div>`,
  Database: () => `<div class="opt-row"><label>${t('optFormat')}</label><select id="opt-dbformat"><option value="html">HTML</option><option value="csv">CSV</option><option value="tsv">TSV</option><option value="json">JSON</option></select></div><div class="opt-row"><label>${t('optOutDir')}</label><input id="opt-outdir" type="text" placeholder="${t('optOutDirPh')}"></div>`,
  Rename: () => `<div class="opt-row"><label class="chk"><input id="opt-rm-apply" type="checkbox" checked> ${t('optRmApply')}</label><label class="chk"><input id="opt-rm-ver" type="checkbox" checked> ${t('optRmVersion')}</label><label class="chk"><input id="opt-rm-tag" type="checkbox" checked> ${t('optRmTypeTag')}</label><label class="chk"><input id="opt-rm-name" type="checkbox" checked> ${t('optRmContentName')}</label></div><div class="opt-row"><label>${t('optOutDir')}</label><input id="opt-outdir" type="text" placeholder="${t('optOutDirPh')}"></div>`,
  UpdBase: () => `<div class="opt-row"><label class="chk"><input id="opt-ad" type="checkbox"> ${t('optApplyDeltas')}</label></div>`,
  RemoveTitleKey: () => `<div class="hint">${t('hintRemoveTitleKey')}</div>`,
  SetCnmtTitleId: () => `<div class="opt-row"><label>${t('optNewTitleId')}</label><input id="opt-cnmtval" type="text" placeholder="${t('optTitleIdPh')}"></div>`,
  SetCnmtVersion: () => `<div class="opt-row"><label>${t('optNewVersion')}</label><input id="opt-cnmtval" type="text" placeholder="${t('optVersionPh')}"></div>`,
  JoinFile: () => `<div class="opt-row"><label>${t('optOutPath')}</label><input id="opt-joinout" type="text" placeholder="${t('optPhAuto')}"></div>`,
};
function getActionOptions() {
  const op = currentOp, o = {};
  if (op === 'JoinFile') { const j = $('opt-joinout')?.value; if (j) o.outputPath = j; }
  if (op === 'SetCnmtTitleId' || op === 'SetCnmtVersion') { const v = $('opt-cnmtval')?.value; if (v) o.value = v; }
  if (op === 'PatchRsv') o.rsvStr = $('opt-rsv')?.value || '';
  if (op === 'MergeFat32') { const n = $('opt-mergename')?.value; if (n) o.outputName = n; }
  if (op === 'SplitTitles' || op === 'Extract' || op === 'Rename') { const od = $('opt-outdir')?.value; if (od) o.outDir = od; }
  if (op === 'SplitTitles' && $('opt-basecard')?.checked) o.basecard = '1';
  if (op === 'Extract') o.filter = $('opt-filter')?.value || 'All';
  if (op === 'Database') { o.format = $('opt-dbformat')?.value || 'csv'; const od = $('opt-outdir')?.value; if (od) o.outDir = od; }
  if (op === 'PackXci') { const n = $('opt-packname')?.value?.trim(); if (n) o.outName = n; }
  if (op === 'Rename') { o.apply = $('opt-rm-apply')?.checked ? '1' : '0'; o.version = $('opt-rm-ver')?.checked ? '1' : '0'; o.typetag = $('opt-rm-tag')?.checked ? '1' : '0'; o.contentname = $('opt-rm-name')?.checked ? '1' : '0'; }
  if (op === 'UpdBase' && $('opt-ad')?.checked) o.applyDeltas = '1';
  return o;
}
async function submitJob() {
  const hint = $('submit-hint'); hint.textContent = ''; hint.className = 'hint';
  if (!selectedFiles.length) { hint.textContent = t('needFiles'); hint.className = 'hint warn'; return; }
  const inputs = selectedFiles.map(f => f.path), options = getActionOptions();
  if (currentOp === 'PatchRsv') { options.rsv = rsvToU32(options.rsvStr || ''); options.rsvLabel = options.rsvStr || ''; delete options.rsvStr; }
  $('btn-submit').disabled = true;
  const perFile = PER_FILE.has(currentOp) && inputs.length > 1;   // single-file ops: one job per file → parallel via workers
  try {
    if (perFile) {
      let n = 0, lastErr = null;
      for (const f of inputs) { try { await apiPost('/api/jobs', { type: currentOp, inputs: [f], options }); n++; } catch (err) { lastErr = err; } }
      if (!n && lastErr) throw lastErr;
      hint.textContent = `${t('submittedMany')} ${n}）`; hint.className = 'hint ok';
    } else {
      const res = await apiPost('/api/jobs', { type: currentOp, inputs, options });
      hint.textContent = `${t('submitted')} ${res.id?.slice(0, 8)}）`; hint.className = 'hint ok';
    }
    await loadJobs(); renderOpJobs();
  }
  catch (err) { hint.textContent = mapError(err.message); hint.className = 'hint err'; }
  finally { $('btn-submit').disabled = false; }
}
function rsvToU32(s) { if (!s) return '0'; if (/^\d+$/.test(s)) return s; const [maj = 0, min = 0, mic = 0] = s.split('.').map(Number); if (maj <= 1) return String(mic); return String(maj * 0x4000000 + min * 0x20000 + mic); }

// ── Jobs view ──────────────────────────────────────────────────────────────────────
async function loadJobs() { try { allJobs = await apiGet('/api/jobs'); } catch (_) {} paintJobsCount(); if (mode === 'jobs') renderJobs(); else if (mode === 'op') renderOpJobs(); else if (mode === 'info' && activeFacet === 'Database') { const box = $('db-out'); if (box) { box.innerHTML = allJobs.filter(j => j.type === 'Database').slice(0, 8).map(jobItemHTML).join(''); bindJobCancels(); } } scheduleJobPoll(); }
// Fallback: while any job is active, keep re-pulling so the list flips to 完成 even if SSE 'done' is missed.
let _pollTimer = null;
function scheduleJobPoll() { clearTimeout(_pollTimer); if (allJobs.some(j => j.status === 'Running' || j.status === 'Queued')) _pollTimer = setTimeout(loadJobs, 1500); }
function renderJobs() { const el = $('ws-content'); el.innerHTML = `<h2 class="sec-title">${esc(t('jobsQueue'))}</h2><div class="job-list">${allJobs.length ? allJobs.map(jobItemHTML).join('') : `<div class="empty">${esc(t('noJobs'))}</div>`}</div>`; bindJobCancels(); }
function renderOpJobs() { const box = $('op-jobs'); if (!box) return; const mine = allJobs.filter(j => j.type === currentOp).slice(0, 6); box.innerHTML = mine.length ? mine.map(jobItemHTML).join('') : ''; bindJobCancels(); }
function stagesHTML(job) {
  const s = job.stages;
  if (!s || !s.length) return '';
  const fmt = ms => ms >= 1000 ? (ms / 1000).toFixed(1) + 's' : Math.max(0, Math.round(ms)) + 'ms';
  const rows = s.map(x => `<li><span class="st-name">${esc(x.name || '')}</span><span class="st-time">${esc(fmt(x.elapsedMs || 0))}${x.done ? '' : ' ▸'}</span></li>`).join('');
  return `<details class="job-stages" open><summary>${esc(t('stagesDetail'))}</summary><ol class="stage-list">${rows}</ol></details>`;
}
function jobItemHTML(job) {
  const st = job.status || 'Queued';
  const _bw = barWidth(job);
  return `<div class="job-item" data-job-id="${esc(job.id)}"><div class="job-top"><span class="job-type">${esc(t('act.' + job.type))}</span><span class="job-status ${esc(st)}">${esc(t('st.' + st))}</span>${(st === 'Running' || st === 'Queued') ? `<button class="job-cancel" data-id="${esc(job.id)}">${esc(t('cancel'))}</button>` : ''}</div><div class="progress-bar-wrap"><div class="progress-bar ${st === 'Done' ? 'done' : st === 'Failed' ? 'failed' : ''}" style="width:${_bw}%"></div></div>${stagesHTML(job)}${job.outputPath && job.outputPath !== 'OK' ? `<div class="job-output">→ ${esc(base(job.outputPath))}</div>` : ''}${job.error ? `<div class="job-error">${esc(mapError(job.error))}</div>` : ''}</div>`;
}
function bindJobCancels() { document.querySelectorAll('.job-cancel').forEach(b => b.onclick = () => cancelJob(b.dataset.id)); }
// Smoothly animate every job's bar: while Running it glides toward the real % (or creeps to ~95% for
// fast / low-granularity ops so the bar is never stuck), snaps to 100 on Done, freezes on Failed.
let _barEase = {}, _barTimer = null;
// Render width uses the persisted eased value (never below the server %), so a periodic list re-render
// doesn't snap the bar back toward a low/0 server value mid-file (that caused the "reset to empty" flicker).
function barWidth(job) {
  if (!job) return 0;
  const s = job.status;
  if (s === 'Done') return 100;
  const e = _barEase[job.id], srv = job.progressPct ?? 0;
  return e != null ? Math.max(e, srv) : srv;
}
function startBarEase() { if (!_barTimer) _barTimer = setInterval(paintBars, 220); }
function paintBars() {
  document.querySelectorAll('.job-item[data-job-id]').forEach(el => {
    const id = el.getAttribute('data-job-id'); const bar = el.querySelector('.progress-bar'); if (!bar) return;
    const it = allJobs.find(j => j.id === id); if (!it) return;
    const st = it.status, real = it.progressPct || 0, cur = _barEase[id] || 0;
    let target;
    if (st === 'Done') target = 100;
    else if (st === 'Failed' || st === 'Cancelled') target = cur;
    else if (st === 'Running') target = Math.max(real, Math.min(95, cur + 1.5));   // honor real per-file steps; ease toward 95 while waiting
    else target = 0;
    _barEase[id] = target; bar.style.width = target + '%';
  });
}
async function cancelJob(id) { await apiDelete('/api/jobs/' + id); await loadJobs(); }
function paintJobsCount() { const run = allJobs.filter(j => j.status === 'Running' || j.status === 'Queued').length; $('cb-jobs').textContent = `${run} ${t('jobsQueue')}`; }

// ── SSE ────────────────────────────────────────────────────────────────────────────
function connectSSE() { if (eventSource) eventSource.close(); eventSource = new EventSource('/api/events'); eventSource.onmessage = e => { try { onEvent(JSON.parse(e.data)); } catch (_) {} }; eventSource.onerror = () => setTimeout(connectSSE, 3000); }
function onEvent(evt) {
  if (evt.message) $('cb-line').textContent = evt.message;
  const j = allJobs.find(x => x.id === evt.jobId); if (j) { if (evt.type === 'progress') j.progressPct = evt.progress; if (evt.status) j.status = evt.status; }
  if (evt.type === 'done' || evt.type === 'error' || evt.type === 'queued' || evt.type === 'start') loadJobs();
  // progress: model (j.progressPct) updated above; paintBars owns the eased DOM width.
  // Do NOT write bar.style.width from the raw server % here — mid-file it's low/0 and would snap the
  // bar back to empty on every SSE tick (that caused the "advances then resets to empty" flicker).
}

// ── Info cache reset on file change (facets) ─────────────────────────────────────────
// (setCurrentFile already clears lastInfo/lastNpdm)

// ── Settings ───────────────────────────────────────────────────────────────────────
async function getSettings() { try { cachedSettings = await apiGet('/api/settings'); } catch (_) {} return cachedSettings; }
// Persist a small settings snapshot so the next launch can render instantly before the slow first /api/settings.
function snapshotSettings() { try { const s = cachedSettings || {}; localStorage.setItem('nscb-settings', JSON.stringify({ defaultView: s.defaultView, language: s.language, outputDir: s.outputDir, workers: s.workers, compressThreads: s.compressThreads, compressLevel: s.compressLevel, titlesDbPath: s.titlesDbPath })); } catch (_) {} }
async function loadSettings() { await getSettings(); const s = cachedSettings; snapshotSettings();
  let stored = null; try { stored = localStorage.getItem('nscb-lang'); } catch (_) {}
  if (!stored && s.language && s.language !== getLang()) setLang(s.language);
  const langSel = $('sel-lang'); if (langSel) langSel.value = getLang();
  $('set-prodkeys').value = s.prodKeysPath || (s.keysLoaded ? (s.resolvedProdKeys || '') : '');
  $('set-outdir').value = s.outputDir || '';
  $('set-workers').value = s.workers || 1; const st = $('set-threads'); if (st) st.value = s.compressThreads || 1; $('set-compresslevel').value = s.compressLevel || 17;
  const trec = $('set-threads-rec'); if (trec) { const n = s.recommendedThreads || (navigator.hardwareConcurrency || 4); trec.textContent = `${t('threadsRecommended')} (${n})`; trec.onclick = () => { const el = $('set-threads'); if (el) el.value = String(n); }; }
  const wrec = $('set-workers-rec'); if (wrec) { const n = s.recommendedWorkers || Math.max(2, Math.min(8, Math.floor((navigator.hardwareConcurrency || 4) / 2))); wrec.textContent = `${t('threadsRecommended')} (${n})`; wrec.onclick = () => { const el = $('set-workers'); if (el) el.value = String(n); }; }
  document.querySelectorAll('.lvl-preset').forEach(b => b.onclick = () => { const el = $('set-compresslevel'); if (el) el.value = b.dataset.lvl; });
  if ([...$('set-defaultview').options].some(o => o.value === (s.defaultView || 'info'))) $('set-defaultview').value = s.defaultView || 'info';
  const lg = $('set-logs'); if (lg) lg.checked = s.logsEnabled !== false;
  $('set-titlesdb').value = s.titlesDbPath || '';
  const dbs = $('db-status'); if (dbs) { dbs.textContent = s.titlesDbLoaded ? (t('dbLoaded') + ' ' + fmtNum(s.titlesDbCount || 0)) : t('dbNone'); dbs.className = 'hint ' + (s.titlesDbLoaded ? 'ok' : ''); }
  updateKeysBadge(s); updateNotice(); maybeAutoTitles(); }
function updateKeysBadge(s) { const b = $('keys-badge'); b.title = s.keysError || '';
  if (s.keysLoaded) { b.textContent = t('keysLoaded'); b.className = 'ab-badge ok'; }
  else if (s.prodKeysPath) { b.textContent = t('keysFailed'); b.className = 'ab-badge err'; }
  else { b.textContent = t('keysNone'); b.className = 'ab-badge'; } }
function openSettings() { $('modal-overlay').classList.remove('hidden'); }

// ── titles.json update notice (prominent, before any operation) ─────────────────────
let titlesDismissed = false, autoTried = false;
function titlesStale(s) { return !s.titlesUpdatedAt || (Date.now() - Date.parse(s.titlesUpdatedAt) > 7 * 864e5); }
function titlesNeeded(s) { return !s.titlesDbLoaded || titlesStale(s); }
function updateNotice() {
  const n = $('titles-notice'); if (!n) return;
  const s = cachedSettings;
  n.classList.toggle('is-hidden', !titlesNeeded(s) || titlesDismissed);   // only show when not-loaded or possibly-outdated
  const dt = s.titlesUpdatedAt ? new Date(s.titlesUpdatedAt).toLocaleDateString(getLang()) : '';
  $('tn-text').textContent = !s.titlesDbLoaded ? t('tnNeed') : `${t('tnStale')}${dt ? ' · ' + dt : ''}`;
  const cb = $('tn-auto'); if (cb) cb.checked = !!s.titlesAutoUpdate;
}
async function maybeAutoTitles() {
  if (autoTried) return; autoTried = true;
  if (cachedSettings.titlesAutoUpdate && titlesNeeded(cachedSettings)) await fetchTitlesDb();
}
// Shared busy wrapper: disables the button + writes a clear in-progress message so a slow
// large download never looks like "nothing happened".
async function withBusy(btn, statusEls, busyText, work) {
  const saved = btn ? btn.textContent : '';
  if (btn) { btn.disabled = true; btn.textContent = '⏳ ' + t('fetching'); }
  for (const el of statusEls) if (el) { el.textContent = busyText; el.className = el.id === 'tn-text' ? '' : 'hint'; }
  try { await work(); }
  catch (err) { const m = (err && err.friendly) ? err.message : mapError(err && err.message); for (const el of statusEls) if (el) { el.textContent = m; el.className = el.id === 'tn-text' ? '' : 'hint err'; } try { toast(m); } catch (_) {} }   // explicit failure 提示 (status line + toast)
  finally { if (btn) { btn.disabled = false; btn.textContent = saved; } }
}
async function fetchTitlesDb(btn) {
  const els = [$('tn-text'), $('db-status')];
  await withBusy(btn, els, t('fetching') + '… ' + t('tnBig'), async () => {
    const body = {}; const p = $('set-titlesdb')?.value?.trim(); if (p) body.path = p;
    // Client safety timeout, a bit above the server's 180 s bound, so a wedged connection still surfaces "超时".
    const ctrl = new AbortController(); const timer = setTimeout(() => ctrl.abort(), 210000);
    let resp, j;
    try {
      resp = await fetch('/api/titlesdb/fetch', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: ctrl.signal });
      j = await resp.json().catch(() => ({}));
    } catch (e) { const err = new Error(t('fetchTimeout')); err.friendly = true; throw err; }
    finally { clearTimeout(timer); }
    if (!resp.ok || j.code) {
      const msg = j.code === 'timeout' ? t('fetchTimeout')
        : j.code === 'http' ? `${t('fetchHttpFail')} (HTTP ${j.status || resp.status})`
        : j.code === 'net' ? `${t('fetchNetFail')}: ${j.error || ''}`
        : j.code === 'badcontent' ? t('fetchBadContent')
        : (j.error || j.detail || `${t('errGeneric')} (${resp.status})`);
      const err = new Error(msg); err.friendly = true; throw err;
    }
    for (const el of els) if (el) { el.textContent = `${t('fetched')} ${fmtNum(j.count)}`; el.className = el.id === 'tn-text' ? '' : 'hint ok'; }
    toast(`${t('fetchDbOk')} · ${fmtNum(j.count)}`);   // explicit success 提示
    titlesDismissed = false; await getSettings(); await loadSettings(); if (mode === 'info') renderFacet();
  });
}
async function saveSettings() { const hint = $('settings-hint'); hint.textContent = ''; hint.className = 'hint';
  try { const s = await apiPut('/api/settings', { prodKeysPath: $('set-prodkeys').value.trim() || null, outputDir: $('set-outdir').value.trim() || null, titlesDbPath: $('set-titlesdb').value.trim() || null, workers: Math.min(64, Math.max(1, parseInt($('set-workers').value, 10) || 1)), compressThreads: Math.min(64, Math.max(1, parseInt($('set-threads') ? $('set-threads').value : '1', 10) || 1)), compressLevel: Math.min(22, Math.max(1, parseInt($('set-compresslevel').value, 10) || 17)), defaultView: $('set-defaultview').value || 'info', logsEnabled: $('set-logs') ? $('set-logs').checked : true });
    cachedSettings = s; snapshotSettings(); updateKeysBadge(s);
    if (!s.keysLoaded) { hint.textContent = s.keysError || t('keysFailed'); hint.className = 'hint err'; return; }
    hint.textContent = t('saved'); hint.className = 'hint ok';
    // Keep the settings panel open after saving (only show the "saved" feedback); don't auto-dismiss —
    // users expect Save to persist-and-stay so they can continue adjusting. Close via the ✕ button.
  } catch (err) { hint.textContent = t('saveFailed') + err.message; hint.className = 'hint err'; } }

// ── Logs ───────────────────────────────────────────────────────────────────────────
let logsTimer = null, lastLogText = '';
function openLogs() { $('log-overlay').classList.remove('hidden'); fetchLogs(); }
function closeLogs() { $('log-overlay').classList.add('hidden'); stopLogAuto(); }
async function fetchLogs() { try { const l = await apiGet('/api/logs?limit=500'); lastLogText = (l || []).join('\n'); const el = $('log-body'); el.textContent = lastLogText || t('logEmpty'); el.scrollTop = el.scrollHeight; } catch (err) { $('log-body').textContent = t('errGeneric') + ': ' + err.message; } }
function toggleLogAuto(on) { if (on) logsTimer = setInterval(fetchLogs, 2000); else stopLogAuto(); }
function stopLogAuto() { if (logsTimer) { clearInterval(logsTimer); logsTimer = null; } const c = $('chk-log-auto'); if (c) c.checked = false; }
function copyLogs() { try { navigator.clipboard && navigator.clipboard.writeText(lastLogText); } catch (_) {} }

// ── Directory / file picker ──────────────────────────────────────────────────────────
function openDirPicker(targetInputId, fileMode, anyFile) {
  const cur = $(targetInputId)?.value || '';
  openDirPickerEx({ fileMode, anyFile, start: (fileMode && cur) ? cur.replace(/[/\\][^/\\]*$/, '') : cur, title: t('chooseDir'), onPick: p => { $(targetInputId).value = p; } });
}
function openDirPickerEx({ fileMode, start, title, onPick, onMany, multi, anyFile }) {
  // Prefer the native Windows file/folder dialog when running inside WebView2; fall back to the in-app browser otherwise.
  const emit = (paths, isDir) => { if (onMany) onMany(paths); else paths.forEach(p => onPick(p, isDir)); };
  if (nativePickAvailable()) { nativePick({ multi: !!multi, folders: !fileMode, anyFile: !!anyFile }).then(paths => emit(paths || [], !fileMode)); return; }
  dirPickerFileMode = !!fileMode; dirPickerCallback = onMany ? (p, isDir) => onMany([p]) : onPick;
  $('dirpicker-title').textContent = title || t('chooseDir'); $('dp-path').value = start || ''; $('dirpicker-overlay').classList.remove('hidden'); dirPickerBrowse(start || undefined);
}
function nativePickAvailable() { return !!(window.chrome && window.chrome.webview && window.chrome.webview.postMessage); }
let _pickResolve = null;
window.__onPick = paths => { const r = _pickResolve; _pickResolve = null; if (r) r(paths || []); };
function nativePick(opts) { return new Promise(res => { _pickResolve = res; try { window.chrome.webview.postMessage({ t: 'pick', multi: !!opts.multi, folders: !!opts.folders, anyFile: !!opts.anyFile }); } catch (_) { _pickResolve = null; res([]); } }); }
function closeDirPicker() { $('dirpicker-overlay').classList.add('hidden'); dirPickerCallback = null; dirPickerFileMode = false; }
async function dirPickerBrowse(path) {
  const qs = (path ? 'path=' + encodeURIComponent(path) + (dirPickerFileMode ? '&all=1' : '') : (dirPickerFileMode ? 'all=1' : ''));
  try { const data = await apiGet('/api/browse' + (qs ? '?' + qs : '')); $('dp-path').value = data.path;
    const list = $('dp-list'); list.innerHTML = '';
    if (data.parent) { const up = mk('div', 'fentry dp-dir'); up.innerHTML = '<span class="fe-icon">⬆</span><span class="fe-name">..</span>'; up.onclick = () => dirPickerBrowse(data.parent); list.appendChild(up); }
    for (const e of (data.entries || [])) {
      if (e.isDir) { const row = mk('div', 'fentry dp-dir'); row.innerHTML = `<span class="fe-icon">📁</span><span class="fe-name">${esc(e.name)}</span>`; row.onclick = () => dirPickerBrowse(e.path); row.ondblclick = () => { if (dirPickerFileMode) { dirPickerBrowse(e.path); } else pickInList(e.path, true); }; list.appendChild(row); }
      else if (dirPickerFileMode) { const row = mk('div', 'fentry'); row.innerHTML = `<span class="fe-icon">${fileIcon(e.name)}</span><span class="fe-name">${esc(e.name)}</span><span class="fe-size">${fmtSize(e.size)}</span>`; row.onclick = () => pickInList(e.path, false); row.ondblclick = () => pickInList(e.path, false); list.appendChild(row); }
    }
  } catch (err) { $('dp-list').innerHTML = `<div class="empty">${esc(err.message)}</div>`; }
}
function pickInList(p, isDir) { $('dp-path').value = p; if (dirPickerCallback) dirPickerCallback(p, isDir); if (dirPickerFileMode) closeDirPicker(); }
