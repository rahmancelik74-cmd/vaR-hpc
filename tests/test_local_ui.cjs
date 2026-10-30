// Controller-level regression with a minimal DOM double; not browser evidence.
const assert = require('node:assert/strict');
const {test} = require('node:test');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

class Element {
  constructor() { this.children = []; this.textContent = ''; this.hidden = false; this.value = ''; this.style = {}; }
  append(...nodes) { this.children.push(...nodes); }
  replaceChildren() { this.children = []; this.textContent = ''; }
  createTHead() { const e = new Element(); this.append(e); return e; }
  createTBody() { return this.createTHead(); }
  insertRow() { return this.createTHead(); }
  scrollIntoView() {}
  setAttribute(name, value) { this[name] = value; }
}
async function controller() {
  const nodes = new Map(), downloads = [];
  const document = {
    getElementById(id) { if (!nodes.has(id)) nodes.set(id, new Element()); return nodes.get(id); },
    querySelectorAll() { return []; },
    createElement(tag) { const e = new Element(); e.click = () => { if (tag === 'a') downloads.push(e.href); }; return e; }
  };
  const context = vm.createContext({document, console, setTimeout,
    fetch: async () => ({ok:true, json:async () => ({max_threads:4, engines:Object.fromEntries(['serial','openmp','cuda'].map(k=>[k,{available:false, reason:'Test double'}]))})})});
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../local_app/static/app.js'), 'utf8'), context);
  await new Promise(setImmediate);
  return {context, nodes, downloads, run:code=>vm.runInContext(code,context)};
}
function contents(element) { return [element.textContent,...element.children.map(contents)].join(' '); }
function fixture() {
  // Artificial controller fixture, never presented as a real engine execution.
  return {id:'successful',elapsed_ms:469.00000004,settings:{scenarios:10003},provenance:{unit:'USD'},build:{sha256:'test'},timing_notice:'Test double',results:[{
    backend:'serial',model:{initial_value:100,horizon_years:1},scenarios:10003,seed:'42',cuda:null,end_to_end_ms:12.345678,
    estimates:[{mc_var:-1.12345678,analytical_var:null},{mc_var:2,analytical_var:null}]}]};
}
test('result presentation rounds only timing and leaves export identity/data intact',async()=>{
  const ui=await controller(); ui.context.job=fixture(); const before=JSON.stringify(ui.context.job);
  ui.run('renderResults(job)');
  const result=contents(ui.nodes.get('result-body'));
  assert.match(result,/469\.00 ms/); assert.match(result,/12\.35/);
  assert.match(result,/-1\.12345678 USD/); assert.match(result,/Unavailable/);
  assert.equal(JSON.stringify(ui.context.job),before);
  ui.nodes.get('json').onclick(); ui.nodes.get('csv').onclick();
  assert.deepEqual(ui.downloads,['/api/jobs/successful/json','/api/jobs/successful/csv']);
});
test('rejected replacement request immediately invalidates prior downloads',async()=>{
  const ui=await controller(); ui.context.job=fixture(); ui.run('renderResults(job); dataset={id:"validated"}');
  ui.context.fetch=async()=>({ok:false,json:async()=>({error:'Another operation is running'})});
  await ui.nodes.get('run').onclick();
  assert.equal(ui.nodes.get('downloads').hidden,true);
  ui.nodes.get('json').onclick(); ui.nodes.get('csv').onclick();
  assert.deepEqual(ui.downloads,[]); assert.match(ui.nodes.get('notice').textContent,/Another operation/);
  assert.equal(ui.nodes.get('notice').role,'alert');
  assert.equal(ui.nodes.get('notice')['aria-atomic'],'true');
});
test('failed and cancelled operations cannot reuse an earlier successful export',async()=>{
  for (const state of ['failed','cancelled']) {
    const ui=await controller(); ui.context.job=fixture(); ui.run('renderResults(job)');
    ui.context.fetch=async()=>({ok:true,json:async()=>({state,kind:'run',elapsed_ms:100,error:'Rejected synthetic input'})});
    await assert.doesNotReject(async()=>{try { await ui.run('follow({id:"replacement"})'); } catch(e) { assert.equal(state,'failed'); }});
    assert.equal(ui.nodes.get('downloads').hidden,true); ui.nodes.get('json').onclick(); assert.deepEqual(ui.downloads,[]);
    ui.run('resetData()'); assert.equal(ui.nodes.get('run').disabled,true);
  }
});
