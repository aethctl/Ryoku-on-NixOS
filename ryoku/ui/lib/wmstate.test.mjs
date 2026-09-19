import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('./wmstate.js', import.meta.url), 'utf8'), ctx);
const copy = value => JSON.parse(JSON.stringify(value));

test('focus snapshot preserves unrelated section identities', () => {
 const target = {};
 const frame = {ready:true,caps:{workspaces:true},outputs:[{name:'DP-1'}],workspaces:[{id:'1'}],windows:[{id:'a',focusOrder:0}]};
 ctx.applyFrame(target,copy(frame));
 const {caps,outputs,workspaces,windows}=target;
 const writes=[];
 ctx.applyFrame(new Proxy(target,{set(o,k,v){writes.push(k);o[k]=v;return true;}}),{...copy(frame),windows:[{id:'a',focusOrder:1}]});
 assert.deepEqual(writes,['windows']);
 assert.equal(target.outputs,outputs);assert.equal(target.workspaces,workspaces);assert.equal(target.caps,caps);
 assert.notEqual(target.windows,windows);
});
test('empty snapshots clear windows and outputs',()=>{
 const target={};ctx.applyFrame(target,{windows:[{id:'a'}],outputs:[{name:'DP-1'}]});
 ctx.applyFrame(target,{});assert.deepEqual(copy(target.windows),[]);assert.deepEqual(copy(target.outputs),[]);
});
test('dynamic workspace IDs survive duplicate labels and occupancy changes',()=>{
 const rows=copy(ctx.workspaceRows([{id:'12',name:'1',output:'DP-1',active:true,windows:2},{id:'34',name:'1',output:'HDMI-A-1',active:true,windows:0}],[],true));
 assert.deepEqual(rows.map(w=>w.id),['12','34']);assert.equal(rows[0].occupied,true);assert.equal(rows[1].occupied,false);
});
test('fixed workspace activity comes from Wayland protocol',()=>{
 const rows=copy(ctx.workspaceRows([{id:'1',name:'1',windows:2,output:'DP-1'}],[{name:'1',active:true,canActivate:true}],false));
 assert.equal(rows[0].active,true);assert.equal(rows[0].id,'1');assert.equal(rows[0].windows,2);
});
