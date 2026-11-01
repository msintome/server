// Watches log/companion_<Name>.json, written once a second by modules/custom/lua/companion_exporter.lua,
// and emits each new snapshot.
//
// It polls rather than using fs.watch: the exporter replaces the file by remove-then-rename, which
// fs.watch on Windows reports inconsistently, and a stat of a few small files every 250 ms costs
// nothing. A file that is missing or does not parse is the exporter mid-replace, so it is skipped
// and picked up on the next pass.

import { EventEmitter } from 'node:events';
import fs from 'node:fs/promises';
import path from 'node:path';

const FILE_PATTERN = /^companion_(.+)\.json$/;
const POLL_MS = 250;

export class LiveSnapshots extends EventEmitter {
    constructor(dir) {
        super();
        this.dir = dir;
        this.mtimes = new Map();
        this.byName = new Map();
        this.timer = null;
        this.scanning = false;
    }

    start() {
        this.timer = setInterval(() => this.scan(), POLL_MS);
        return this.scan();
    }

    stop() {
        clearInterval(this.timer);
    }

    all() {
        return [...this.byName.values()];
    }

    byCharacterId(id) {
        return this.all().find((snapshot) => snapshot.character?.id === id);
    }

    async scan() {
        // A slow disk must not stack scans on top of each other.
        if (this.scanning) {
            return;
        }

        this.scanning = true;
        try {
            const entries = await fs.readdir(this.dir);
            for (const entry of entries) {
                if (FILE_PATTERN.test(entry)) {
                    await this.check(path.join(this.dir, entry));
                }
            }
        } catch (err) {
            if (err.code !== 'ENOENT') {
                console.warn(`[live] scan failed: ${err.message}`);
            }
        } finally {
            this.scanning = false;
        }
    }

    async check(file) {
        let stat;
        try {
            stat = await fs.stat(file);
        } catch {
            return;
        }

        if (this.mtimes.get(file) === stat.mtimeMs) {
            return;
        }

        let snapshot;
        try {
            snapshot = JSON.parse(await fs.readFile(file, 'utf8'));
        } catch {
            return;
        }

        // Only remember the mtime once the read worked, so a half-replaced file is retried.
        this.mtimes.set(file, stat.mtimeMs);

        const name = snapshot.character?.name;
        if (!name) {
            return;
        }

        this.byName.set(name, snapshot);
        this.emit('snapshot', snapshot);
    }
}
