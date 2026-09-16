#!/usr/bin/env node
// Machine bootstrap: no dependency on the private workflow repository.
import {spawnSync} from 'node:child_process';
import {mkdirSync, readFileSync, writeFileSync, renameSync} from 'node:fs';
import {homedir} from 'node:os';
import {join} from 'node:path';

const plugins = [
    {id: 'cloudmanic.herdr-plus', source: 'cloudmanic/herdr-plus', ref: 'v0.1.24'},
    {id: 'herdr-navigator', source: 'thanhdat77/herdr-navigator', ref: 'v0.3.6'}
];
const state = join(process.env.XDG_STATE_HOME || join(homedir(), '.local/state'), 'herdr-setup');
const receiptPath = join(state, 'plugins.json');

function run(program, args, capture = false) {
    const result = spawnSync(program, args, {encoding: 'utf8', stdio: capture ? ['ignore', 'pipe', 'inherit'] : 'inherit'});
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(`${program} ${args.join(' ')} exited ${result.status}`);
    return capture ? result.stdout.trim() : undefined;
}

function integrations() {
    // Herdr merges its own hooks; unrelated hooks stay owned by their installers.
    for (const agent of ['opencode', 'codex']) run('herdr', ['integration', 'install', agent]);
    run('herdr', ['integration', 'status']);
}

function ensurePlugins() {
    let receipts = {};
    try { receipts = JSON.parse(readFileSync(receiptPath, 'utf8')); }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
    const installed = JSON.parse(run('herdr', ['plugin', 'list', '--json'], true)).result.plugins;
    for (const plugin of plugins.filter(p => process.platform !== 'win32' || p.id !== 'herdr-navigator')) {
        const exists = installed.some(entry => (entry.id || entry.plugin_id || entry.manifest?.id) === plugin.id);
        const actual = installed.find(entry => (entry.id || entry.plugin_id) === plugin.id);
        if (exists && actual.source?.requested_ref === plugin.ref && actual.source?.owner + '/' + actual.source?.repo === plugin.source && receipts[plugin.id] === `${plugin.source}@${plugin.ref}`) {
            console.info(`Already installed: ${plugin.source}@${plugin.ref}`);
            continue;
        }
        run('herdr', ['plugin', 'install', plugin.source, '--ref', plugin.ref, '--yes']);
        receipts[plugin.id] = `${plugin.source}@${plugin.ref}`;
        mkdirSync(state, {recursive: true});
        writeFileSync(`${receiptPath}.tmp`, JSON.stringify(receipts, null, 2) + '\n');
        renameSync(`${receiptPath}.tmp`, receiptPath);
    }
}

function status() {
    for (const program of ['herdr', 'opencode', 'codex']) run(program, ['--version']);
    run('herdr', ['integration', 'status']);
    run('herdr', ['plugin', 'list']);
}

try {
    const command = process.argv[2] || 'status';
    if (command === 'setup') { integrations(); ensurePlugins(); status(); }
    else if (command === 'integrations') integrations();
    else if (command === 'plugins') ensurePlugins();
    else if (command === 'status') status();
    else throw new Error('Usage: herdr-setup.mjs setup|integrations|plugins|status');
} catch (error) {
    console.error(error.message);
    process.exitCode = 1;
}
