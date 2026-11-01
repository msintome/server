// Page logic: takes snapshots from /api/live/stream, keeps the map and panels in step with them,
// and polls /api/progress for the database-backed figures (EXP, crafts, gil).

import { MapView } from './map.js';

const PROGRESS_POLL_MS = 5000;
const HEALTH_POLL_MS = 30000;
const STATUS_TICK_MS = 1000;

// A snapshot older than this many write intervals means the character is zoning, or the server has
// paused; one older than OFFLINE_AFTER_S means they have logged out.
const STALE_INTERVALS = 3;
const OFFLINE_AFTER_S = 60;

// Wait this long before quoting an EXP/hour figure, so one early kill does not read as a huge rate.
const EXP_RATE_MIN_MS = 2 * 60 * 1000;

const $ = (id) => document.getElementById(id);

const map = new MapView($('map'), {
    onFollowChange: (follow) => {
        $('follow').checked = follow;
    },
});

const state = {
    snapshots: new Map(),
    active: null,
    zoneName: null,
    progress: null,
    expTracker: null,
};

// Formatting

const titleCase = (text) => String(text ?? '')
    .toLowerCase()
    .split('_')
    .filter(Boolean)
    .map((word) => word[0].toUpperCase() + word.slice(1))
    .join(' ');

const zoneDisplayName = (name) => String(name ?? '').replace(/_/g, ' ');

const number = (n) => (n ?? 0).toLocaleString();

function duration(ms) {
    const total = Math.round(ms / 1000);
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    const pad = (n) => String(n).padStart(2, '0');
    return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

function ago(seconds) {
    if (seconds < 90) {
        return `${Math.round(seconds)}s ago`;
    }

    if (seconds < 5400) {
        return `${Math.round(seconds / 60)}m ago`;
    }

    return `${(seconds / 3600).toFixed(1)}h ago`;
}

function setBar(id, value, max) {
    const pct = max > 0 ? Math.max(0, Math.min(100, (value / max) * 100)) : 0;
    $(id).style.width = `${pct}%`;
}

// Live snapshots

function chooseActive() {
    // With more than one character exporting, show whoever was written most recently.
    let best = null;
    for (const snapshot of state.snapshots.values()) {
        if (!best || snapshot.time > best.time || (snapshot.time === best.time && snapshot.seq > best.seq)) {
            best = snapshot;
        }
    }

    return best;
}

async function loadZone(zoneName) {
    state.zoneName = zoneName;
    map.setMesh(null);
    $('map-empty').hidden = true;

    try {
        const response = await fetch(`/api/navmesh/${encodeURIComponent(zoneName)}`);

        // The player may have zoned again while this was loading.
        if (state.zoneName !== zoneName) {
            return;
        }

        if (!response.ok) {
            $('map-empty').textContent = `No navmesh for ${zoneDisplayName(zoneName)}`;
            $('map-empty').hidden = false;
            return;
        }

        map.setMesh(await response.json());
    } catch (err) {
        $('map-empty').textContent = `Could not load the map: ${err.message}`;
        $('map-empty').hidden = false;
    }
}

function renderSnapshot(snapshot) {
    const { character, zone, position, job, vitals, target, effects } = snapshot;

    if (zone.name !== state.zoneName) {
        loadZone(zone.name);
    }

    $('zone-name').textContent = zoneDisplayName(zone.name);
    $('zone-meta').textContent = [
        titleCase(zone.regionName),
        titleCase(zone.weatherName),
        zone.mogHouse ? 'In Mog House' : null,
    ].filter(Boolean).join(' · ');

    // The server keeps a character in the Mog House standing in the street they entered from, so
    // the marker stays put but dims rather than claiming they are out there.
    map.dimPlayer = zone.mogHouse;
    map.setPlayer(position);
    map.setTarget(target ?? null);

    $('coords').textContent =
        `x ${position.x.toFixed(1)}   z ${position.z.toFixed(1)}   height ${(-position.y).toFixed(1)}   ↑ N`;

    $('char-name').textContent = character.name;
    $('char-job').textContent = `${job.mainName}${job.mainLevel}` +
        (job.subName ? ` / ${job.subName}${job.subLevel}` : '');

    setBar('hp-bar', vitals.hp, vitals.maxHp);
    $('hp-text').textContent = `${number(vitals.hp)} / ${number(vitals.maxHp)}`;
    setBar('mp-bar', vitals.mp, vitals.maxMp);
    $('mp-text').textContent = `${number(vitals.mp)} / ${number(vitals.maxMp)}`;
    setBar('tp-bar', vitals.tp, 3000);
    $('tp-text').textContent = number(vitals.tp);

    renderTarget(target);
    renderEffects(effects ?? []);
}

function renderTarget(target) {
    $('target-card').hidden = !target;
    if (!target) {
        return;
    }

    $('target-name').textContent = target.name.replace(/_/g, ' ');
    $('target-meta').textContent = [
        target.level !== undefined ? `Lv ${target.level}` : null,
        `${target.distance.toFixed(1)}y`,
        target.hpp !== undefined ? `${target.hpp}%` : null,
    ].filter(Boolean).join(' · ');
    setBar('target-bar', target.hpp ?? 0, 100);
}

function renderEffects(effects) {
    const container = $('effects');
    container.replaceChildren();

    if (effects.length === 0) {
        container.textContent = 'None';
        container.classList.add('muted');
        return;
    }

    container.classList.remove('muted');

    // Timed effects first, soonest to wear off at the front; permanent ones after.
    const sorted = [...effects].sort((a, b) => {
        const ra = a.remainingMs || Infinity;
        const rb = b.remainingMs || Infinity;
        return ra - rb || String(a.name).localeCompare(String(b.name));
    });

    for (const effect of sorted) {
        const chip = document.createElement('span');
        chip.className = 'chip';
        chip.textContent = effect.name ? titleCase(effect.name) : `Effect ${effect.id}`;

        if (effect.remainingMs > 0) {
            const time = document.createElement('span');
            time.className = 'time';
            time.textContent = duration(effect.remainingMs);
            chip.append(time);
        }

        container.append(chip);
    }
}

function renderStatus() {
    const snapshot = state.active;
    const dot = $('status-dot');

    if (!snapshot) {
        dot.className = 'dot dot-offline';
        $('status-text').textContent = 'No snapshot yet. Is the companion_exporter module loaded?';
        return;
    }

    const age = Date.now() / 1000 - snapshot.time;
    const staleAfter = (snapshot.intervalMs / 1000) * STALE_INTERVALS + 1;

    if (age <= staleAfter) {
        dot.className = 'dot dot-live';
        dot.title = 'Live';
        $('status-text').textContent = 'Live';
    } else if (age <= OFFLINE_AFTER_S) {
        dot.className = 'dot dot-stale';
        dot.title = 'Stale';
        $('status-text').textContent = `Zoning or paused - last update ${ago(age)}`;
    } else {
        dot.className = 'dot dot-offline';
        dot.title = 'Offline';
        $('status-text').textContent = `Offline - last seen ${ago(age)}`;
    }
}

function onSnapshot(snapshot) {
    state.snapshots.set(snapshot.character.name, snapshot);

    const active = chooseActive();
    const switched = active?.character.id !== state.active?.character.id;
    state.active = active;

    if (switched) {
        state.expTracker = null;
        map.clearTrail();
        pollProgress();
    }

    if (active === snapshot) {
        renderSnapshot(snapshot);
        renderStatus();
    }
}

function connect() {
    const source = new EventSource('/api/live/stream');
    source.onmessage = (event) => onSnapshot(JSON.parse(event.data));

    // EventSource reconnects by itself; this only keeps the footer honest meanwhile.
    source.onerror = () => {
        $('db-status').textContent = 'Lost the companion server - retrying…';
    };

    source.onopen = () => pollHealth();
}

// Database-backed progress

function trackExp(progress) {
    const now = Date.now();
    const sample = { time: now, exp: progress.exp, tnl: progress.tnl, level: progress.level, job: progress.job };

    if (!state.expTracker || state.expTracker.last.job !== sample.job) {
        state.expTracker = { start: now, gained: 0, last: sample };
        return;
    }

    const tracker = state.expTracker;
    const last = tracker.last;

    if (sample.level === last.level) {
        tracker.gained += Math.max(0, sample.exp - last.exp);
    } else if (sample.level > last.level && last.tnl) {
        // A level-up resets the counter: the rest of the old level plus what is into the new one.
        tracker.gained += Math.max(0, last.tnl - last.exp) + sample.exp;
    }

    tracker.last = sample;
}

function renderProgress(progress) {
    if (progress.exp !== null && progress.tnl) {
        setBar('exp-bar', progress.exp, progress.tnl);
        $('exp-text').textContent = `${number(progress.exp)} / ${number(progress.tnl)}`;
    } else {
        setBar('exp-bar', 0, 1);
        $('exp-text').textContent = progress.exp !== null ? number(progress.exp) : '-';
    }

    const tracker = state.expTracker;
    if (tracker) {
        const elapsed = Date.now() - tracker.start;
        let text = `${number(tracker.gained)} EXP this session`;
        if (elapsed >= EXP_RATE_MIN_MS) {
            const perHour = tracker.gained / (elapsed / 3600000);
            text += ` · ${number(Math.round(perHour))}/hr`;
            if (perHour > 0 && progress.tnl) {
                text += ` · level in ${duration(((progress.tnl - progress.exp) / perHour) * 3600000)}`;
            }
        }

        $('exp-rate').textContent = text;
    }

    const crafts = $('crafts');
    crafts.replaceChildren();
    const trained = progress.crafts.filter((craft) => craft.level > 0);
    if (trained.length === 0) {
        crafts.textContent = 'None trained yet';
        crafts.classList.add('muted');
    } else {
        crafts.classList.remove('muted');
        for (const craft of trained) {
            const name = document.createElement('span');
            name.textContent = craft.name;
            const level = document.createElement('span');
            level.className = 'level';
            level.textContent = craft.level.toFixed(1);
            crafts.append(name, level);
        }
    }

    $('gil').textContent = progress.gil !== null ? `${number(progress.gil)} gil` : '';
}

async function pollProgress() {
    const id = state.active?.character.id;
    if (id === undefined) {
        return;
    }

    try {
        const response = await fetch(`/api/progress/${id}`);
        const body = await response.json();
        if (!response.ok) {
            $('db-status').textContent = `Database: ${body.error}`;
            return;
        }

        state.progress = body;
        trackExp(body);
        renderProgress(body);
    } catch (err) {
        $('db-status').textContent = `Database: ${err.message}`;
    }
}

async function pollHealth() {
    try {
        const health = await (await fetch('/api/health')).json();
        $('db-status').textContent = health.db === 'ok'
            ? `Database: ${health.dbUser} via ${health.dbSource}`
            : `Database unavailable: ${health.db}`;
    } catch {
        $('db-status').textContent = 'Companion server unreachable';
    }
}

// Controls

$('follow').addEventListener('change', (event) => map.setFollow(event.target.checked));
$('floor-only').addEventListener('change', (event) => map.setFloorOnly(event.target.checked));
$('trail').addEventListener('change', (event) => map.setShowTrail(event.target.checked));
$('recentre').addEventListener('click', () => {
    $('follow').checked = true;
    map.setFollow(true);
    map.fit();
});

connect();
setInterval(renderStatus, STATUS_TICK_MS);
setInterval(pollProgress, PROGRESS_POLL_MS);
setInterval(pollHealth, HEALTH_POLL_MS);
