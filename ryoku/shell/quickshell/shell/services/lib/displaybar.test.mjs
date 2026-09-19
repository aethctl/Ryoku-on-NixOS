import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('./displaybar.js', import.meta.url), 'utf8'), ctx);

test('a per-output style overrides the global style', () => {
    const displays = {bar_style: {'DP-1': 'chroma', 'HDMI-A-1': ''}};
    assert.equal(ctx.styleFor(displays, 'DP-1', 'qsbar'), 'chroma');
    assert.equal(ctx.styleFor(displays, 'HDMI-A-1', 'qsbar'), 'qsbar');
    assert.equal(ctx.styleFor(displays, 'DP-2', 'sumi'), 'sumi');
});

test('a per-output widget override falls back to the style default', () => {
    const displays = {
        bar_widgets: {
            'DP-1': {chroma: {media: false, clock: true}}
        }
    };
    assert.equal(ctx.widgetEnabled(displays, 'DP-1', 'chroma', 'media', true), false);
    assert.equal(ctx.widgetEnabled(displays, 'DP-1', 'chroma', 'clock', false), true);
    assert.equal(ctx.widgetEnabled(displays, 'DP-1', 'chroma', 'network', true), true);
    assert.equal(ctx.widgetEnabled(displays, 'HDMI-A-1', 'chroma', 'media', false), false);
});
