// AmalieXI companion - a second-screen web app showing where you are and how you are doing.
//
// Two sources feed it:
//   - log/companion_<Name>.json, written once a second by the companion_exporter module, for what
//     only the running map server knows (position, vitals, target, effects). Pushed to the page
//     over server-sent events as each new snapshot lands.
//   - xidb, for what the map server already saves as it changes (EXP, crafts, gil). The page polls
//     /api/progress for it.
//
// Listens on 127.0.0.1 only: it reads your character data, and has no business on the network.

import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import zlib from 'node:zlib';

import * as config from './lib/config.js';
import { LiveSnapshots } from './lib/live.js';
import { NavmeshCache } from './lib/navmesh.js';
import { createDb } from './lib/db.js';

const HOST = '127.0.0.1';
const SSE_HEARTBEAT_MS = 15000;

const STATIC_FILES = {
    '/': ['index.html', 'text/html; charset=utf-8'],
    '/app.js': ['app.js', 'text/javascript; charset=utf-8'],
    '/map.js': ['map.js', 'text/javascript; charset=utf-8'],
    '/style.css': ['style.css', 'text/css; charset=utf-8'],
};

const live = new LiveSnapshots(config.logDir);
const navmeshes = new NavmeshCache(config.navmeshDir);
const db = createDb(config.db);

function sendJson(req, res, status, body) {
    const text = typeof body === 'string' ? body : JSON.stringify(body);
    const headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
    };

    // Navmeshes run to a few MB of JSON, and compress to a fraction of that.
    if (text.length > 4096 && /\bgzip\b/.test(req.headers['accept-encoding'] ?? '')) {
        headers['Content-Encoding'] = 'gzip';
        res.writeHead(status, headers);
        res.end(zlib.gzipSync(text));
        return;
    }

    res.writeHead(status, headers);
    res.end(text);
}

async function serveStatic(res, [file, type]) {
    try {
        const body = await fs.readFile(path.join(config.publicDir, file));
        res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-cache' });
        res.end(body);
    } catch {
        res.writeHead(404);
        res.end();
    }
}

function serveStream(req, res) {
    res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-store',
        Connection: 'keep-alive',
    });

    const send = (snapshot) => res.write(`data: ${JSON.stringify(snapshot)}\n\n`);

    // Everything known so far, so a freshly opened page does not sit blank until the next tick.
    for (const snapshot of live.all()) {
        send(snapshot);
    }

    live.on('snapshot', send);
    const heartbeat = setInterval(() => res.write(': heartbeat\n\n'), SSE_HEARTBEAT_MS);

    req.on('close', () => {
        live.off('snapshot', send);
        clearInterval(heartbeat);
    });
}

async function serveProgress(req, res, charId) {
    // Job and level come from the live snapshot rather than the request, because which job's EXP
    // column to read is exactly what the snapshot knows and the database does not track live.
    const snapshot = live.byCharacterId(charId);
    if (!snapshot) {
        sendJson(req, res, 404, { error: 'no live snapshot for that character' });
        return;
    }

    try {
        sendJson(req, res, 200, await db.progress(charId, snapshot.job.mainName, snapshot.job.mainLevel));
    } catch (err) {
        sendJson(req, res, 503, { error: err.message });
    }
}

async function serveHealth(req, res) {
    let dbStatus = 'ok';
    try {
        await db.ping();
    } catch (err) {
        dbStatus = err.message;
    }

    sendJson(req, res, 200, {
        db: dbStatus,
        dbUser: config.db.user,
        dbSource: config.db.source,
        characters: live.all().map((snapshot) => snapshot.character.name),
    });
}

async function route(req, res) {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const pathname = url.pathname;

    if (req.method !== 'GET') {
        res.writeHead(405);
        res.end();
        return;
    }

    if (STATIC_FILES[pathname]) {
        await serveStatic(res, STATIC_FILES[pathname]);
        return;
    }

    if (pathname === '/api/live') {
        sendJson(req, res, 200, live.all());
        return;
    }

    if (pathname === '/api/live/stream') {
        serveStream(req, res);
        return;
    }

    if (pathname === '/api/health') {
        await serveHealth(req, res);
        return;
    }

    const navmeshMatch = pathname.match(/^\/api\/navmesh\/(.+)$/);
    if (navmeshMatch) {
        const body = await navmeshes.get(decodeURIComponent(navmeshMatch[1]));
        if (body) {
            sendJson(req, res, 200, body);
        } else {
            sendJson(req, res, 404, { error: 'no navmesh for that zone' });
        }

        return;
    }

    const progressMatch = pathname.match(/^\/api\/progress\/(\d+)$/);
    if (progressMatch) {
        await serveProgress(req, res, Number(progressMatch[1]));
        return;
    }

    res.writeHead(404);
    res.end();
}

const server = http.createServer((req, res) => {
    route(req, res).catch((err) => {
        console.error(`[http] ${req.url}: ${err.stack ?? err}`);
        if (!res.headersSent) {
            res.writeHead(500);
        }

        res.end();
    });
});

await live.start();

server.listen(config.port, HOST, () => {
    console.log(`AmalieXI companion on http://${HOST}:${config.port}/`);
    console.log(`  live snapshots: ${config.logDir}`);
    console.log(`  navmeshes:      ${config.navmeshDir}`);
    console.log(`  database:       ${config.db.user}@${config.db.host}/${config.db.database} (from ${config.db.source})`);
});
