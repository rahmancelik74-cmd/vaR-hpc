'use strict';
const $ = id => document.getElementById(id);
let dataset = null, active = null, completed = null, info = null;
const format = n => n == null ? 'Unavailable' : Number(n).toLocaleString('en-US', {maximumFractionDigits: 8});
function notice(message, success = false) { $('notice').hidden = !message; $('notice').textContent = message; $('notice').className = success ? 'success' : ''; }
async function api(path, body) {
  const response = await fetch(path, body === undefined ? {} : {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)});
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'Service request failed');
  return result;
}
function busy(value) {
  for (const id of ['try', 'validate', 'add', 'use']) $(id).disabled = value;
  $('run').disabled = value || !dataset; $('cancel').hidden = !value;
}
function resetData() {
  dataset = null; completed = null;
  $('preview').hidden = true; $('empty').hidden = false;
  $('data-state').textContent = 'AWAITING VALIDATION';
  $('downloads').hidden = true;
  $('result-body').textContent = 'Your completed analysis will appear here.';
  $('run').disabled = true;
}
function text(tag, value, parent, cls) {
  const node = document.createElement(tag); node.textContent = value;
  if (cls) node.className = cls; if (parent) parent.append(node); return node;
}
function table(parent, headers, rows) {
  const wrap = document.createElement('div'); wrap.className = 'table-wrap'; parent.append(wrap);
  const t = document.createElement('table'); wrap.append(t);
  const head = t.createTHead().insertRow(); headers.forEach(h => text('th', h, head));
  const body = t.createTBody(); rows.forEach(row => { const tr = body.insertRow(); row.forEach(v => text('td', v, tr)); });
}
function chart(parent, asset) {
  text('p', `${asset.symbol} / actual input Close / ${dataset.unit}`, parent, 'caption');
  const rows = asset.rows, values = rows.map(r => r[1]), lo = Math.min(...values), hi = Math.max(...values);
  const ns = 'http://www.w3.org/2000/svg', svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', '0 0 800 160'); svg.classList.add('chart'); svg.setAttribute('role', 'img');
  const title = document.createElementNS(ns, 'title'); title.textContent = `${asset.symbol} uploaded Close prices, ${rows[0][0]} to ${rows.at(-1)[0]}`; svg.append(title);
  const path = document.createElementNS(ns, 'path');
  path.setAttribute('d', values.map((v, i) => `${i ? 'L' : 'M'}${55 + 720*i/(values.length-1)} ${115-90*(v-lo)/(hi-lo || 1)}`).join(' ')); svg.append(path);
  for (const [x, y, label] of [[8, 26, format(hi)], [8, 117, format(lo)], [55, 147, rows[0][0]], [685, 147, rows.at(-1)[0]]]) {
    const node = document.createElementNS(ns, 'text'); node.setAttribute('x', x); node.setAttribute('y', y); node.textContent = label; svg.append(node);
  }
  parent.append(svg);
}
function preview(data) {
  dataset = data; $('empty').hidden = true; $('preview').hidden = false; $('preview').replaceChildren();
  $('data-state').textContent = 'VALIDATED LOCALLY';
  const pills = document.createElement('div'); pills.className = 'preview-head'; $('preview').append(pills);
  for (const s of [`${data.assets.length} asset(s)`, `${data.unit} valuation unit`, `${data.start} to ${data.end}`, 'Strict session alignment']) text('span', s, pills, 'pill');
  text('p', data.provenance_status, $('preview'), 'caption');
  for (const asset of data.assets) {
    chart($('preview'), asset);
    const details = document.createElement('details'); text('summary', `${asset.symbol}: quantity ${format(asset.quantity)} / ${asset.rows.length} observations / preview & import record`, details);
    table(details, ['Date', 'Close'], asset.rows.slice(0, 8).map(r => [r[0], format(r[1])]));
    text('p', `${asset.manifest.excluded_outside_requested_range} observations explicitly excluded outside the selected interval. No reordering or filling. Raw SHA-256: ${asset.manifest.raw_sha256}`, details, 'caption');
    $('preview').append(details);
  }
  $('status').textContent = 'Data validated. Ready to run.'; busy(false);
}
function renderResults(job) {
  const parent = $('result-body'); parent.className = ''; parent.replaceChildren();
  const first = job.results[0], model = first.portfolio || first.model, unit = job.provenance.unit;
  const metrics = document.createElement('div'); metrics.className = 'metrics'; parent.append(metrics);
  for (const [label, value] of [['INITIAL VALUE', `${format(model.initial_value)} ${unit}`], ['SCENARIOS / SEED', `${format(first.scenarios)} / ${first.seed}`], ['APPLICATION ELAPSED', `${format(job.elapsed_ms)} ms`]]) {
    const m = document.createElement('div'); m.className = 'metric'; text('small', label, m); text('strong', value, m); metrics.append(m);
  }
  table(parent, ['Engine / mode', '95% VaR', '99% VaR', '95% analytical', '99% analytical', 'Engine wall ms'], job.results.map(r => [r.backend + (r.cuda ? ' / '+r.cuda.mode : ''), ...r.estimates.map(e => `${format(e.mc_var)} ${unit}`), ...r.estimates.map(e => e.analytical_var == null ? 'Unavailable' : `${format(e.analytical_var)} ${unit}`), format(r.end_to_end_ms)]));
  text('p', `Horizon: ${format(model.horizon_years)} years. Positive long holdings; negative VaR is retained. General portfolio analytical VaR is unavailable.`, parent, 'caption');
  text('p', job.timing_notice, parent, 'caption');
  for (const r of job.results) if (r.cuda) text('p', `CUDA ${r.cuda.mode}: requested batch ${r.cuda.requested_batch_size}, effective batch ${r.cuda.effective_batch_size}, ${r.cuda.batch_count} batches.`, parent, 'caption');
  text('p', `Executable SHA-256: ${job.build.sha256}. Equal seeds across backends or modes do not imply equal samples.`, parent, 'caption');
  completed = job.id; $('downloads').hidden = false;
}
async function follow(job) {
  active = job.id; busy(true); notice('');
  $('downloads').hidden = true;
  for (;;) {
    let state;
    try { state = await api('/api/jobs/'+active); }
    catch (error) { $('status').textContent = 'Connection lost. Operation state is unknown; reconnect before starting another.'; throw error; }
    $('status').textContent = `${state.kind === 'validate' ? 'Validating files' : 'Running analysis'} / ${state.state} / ${(state.elapsed_ms/1000).toFixed(1)} s`;
    if (state.state !== 'running') {
      active = null; busy(false);
      if (state.state === 'failed') throw new Error(state.error);
      if (state.state === 'cancelled') { notice('Operation cancelled. No completed analysis was produced.'); return; }
      if (state.kind === 'validate') { preview(state.dataset); notice('Input validation completed. Configure your analysis below.', true); }
      else { renderResults(state); notice('Analysis completed with genuine engine results.', true); $('results').scrollIntoView({behavior: 'smooth'}); }
      return;
    }
    await new Promise(resolve => setTimeout(resolve, 300));
  }
}
function action(fn) { return async () => { try { await fn(); } catch (error) { notice(error.message); $('status').textContent = 'Operation failed. Review the error above.'; if (!active) busy(false); } }; }
function addAsset() {
  if ($('assets').children.length >= 5) return notice('At most five assets are supported.');
  const row = document.createElement('div'); row.className = 'asset-row';
  row.innerHTML = '<div class="fields"><label>Price CSV<input type="file" class="price" accept=".csv"></label><label>Source metadata JSON<input type="file" class="metadata" accept=".json"></label><label>Quantity<input type="number" class="quantity" value="1" min="0" step="any"></label><label>Format<select class="dialect"><option value="existing_csv">Close CSV</option><option value="kibot_daily">Kibot daily</option></select></label></div>';
  const remove = text('button', 'Remove asset', row); remove.style.marginTop = '10px'; remove.addEventListener('click', () => row.remove()); $('assets').append(row);
}
async function encode(file) {
  if (!file) throw new Error('Select both a price CSV and its source metadata JSON for every asset.');
  if (!file.size || file.size > 1048576) throw new Error('Each file must be 1 byte..1 MiB.');
  const bytes = new Uint8Array(await file.arrayBuffer()); let binary = '';
  for (let i = 0; i < bytes.length; i += 8192) binary += String.fromCharCode(...bytes.subarray(i, i+8192));
  return btoa(binary);
}
$('try').onclick = action(async () => { resetData(); busy(true); await follow(await api('/api/data', {example: $('example').value})); });
$('use').onclick = () => { $('upload').hidden = false; $('data').scrollIntoView({behavior: 'smooth'}); if (!$('assets').children.length) addAsset(); };
$('add').onclick = addAsset;
$('validate').onclick = action(async () => {
  resetData();
  const assets = [];
  for (const row of $('assets').children) assets.push({csv: await encode(row.querySelector('.price').files[0]), metadata: await encode(row.querySelector('.metadata').files[0]), quantity: Number(row.querySelector('.quantity').value), format: row.querySelector('.dialect').value});
  await follow(await api('/api/data', {calendar: $('calendar').value, start: $('start-date').value, end: $('end-date').value, assets}));
});
$('cuda-mode').onchange = () => { $('batch').disabled = $('cuda-mode').value !== 'hybrid'; };
$('run').onclick = action(async () => {
  const engines = [];
  document.querySelectorAll('.engine input:checked').forEach(input => {
    const config = {backend: input.value};
    if (input.value === 'openmp') config.threads = Number($('threads').value);
    if (input.value === 'cuda') { config.mode = $('cuda-mode').value; if (config.mode === 'hybrid') config.batch_size = Number($('batch').value); }
    engines.push(config);
  });
  $('result-body').textContent = 'Analysis is running. Results will appear after all selected engines finish.';
  await follow(await api('/api/run', {dataset: dataset.id, scenarios: Number($('scenarios').value), seed: $('seed').value, horizon_days: Number($('horizon').value), engines}));
});
$('cancel').onclick = action(async () => { if (active) { await api('/api/jobs/'+active+'/cancel', {}); $('status').textContent = 'Cancellation requested. Waiting for child-process cleanup.'; } });
for (const extension of ['json', 'csv']) $(extension).onclick = () => { if (completed) { const a = document.createElement('a'); a.href = '/api/jobs/'+completed+'/'+extension; a.download = 'analysis.'+extension; a.click(); } };
(async () => {
  try {
    info = await api('/api/info'); $('threads').max = info.max_threads; $('threads').value = Math.min(4, info.max_threads);
    for (const backend of ['serial', 'openmp', 'cuda']) {
      const c = info.engines[backend], label = document.createElement('label'); label.className = 'engine'+(c.available ? '' : ' unavailable');
      const input = document.createElement('input'); input.type = 'checkbox'; input.value = backend; input.disabled = !c.available; input.checked = backend === 'serial'; label.append(input);
      text('b', backend === 'openmp' ? 'OpenMP' : backend === 'cuda' ? 'CUDA' : 'Serial CPU', label);
      text('small', c.available ? ({serial: 'Validated baseline / single thread', openmp: 'Parallel CPU / explicit thread count', cuda: 'GPU / full device or hybrid'})[backend] : 'Unavailable: '+c.reason, label); $('engines').append(label);
    }
  } catch (error) { notice('Service unavailable: '+error.message); }
})();
