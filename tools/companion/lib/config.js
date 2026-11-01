// Where things are, and how to reach the database.
//
// The app lives at tools/companion inside the LSB checkout, so the repo root - and with it log/
// (where the exporter writes) and navmeshes/ - is two levels up.
//
// Database credentials come from tools/companion/config.json when it exists. Without one, the app
// reads the same SQL_* settings the servers use from settings/network.lua, so it works out of the
// box. A read-only user is the better choice: the app only ever issues SELECTs, and config.json
// (gitignored) is where to put one.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

export const appRoot = path.resolve(here, '..');
export const repoRoot = path.resolve(appRoot, '..', '..');
export const logDir = path.join(repoRoot, 'log');
export const navmeshDir = path.join(repoRoot, 'navmeshes');
export const publicDir = path.join(appRoot, 'public');

function readServerSqlSettings() {
    // The local override first, then the tracked default - the same order the servers use.
    for (const relative of ['settings/network.lua', 'settings/default/network.lua']) {
        const file = path.join(repoRoot, relative);
        if (!fs.existsSync(file)) {
            continue;
        }

        const text = fs.readFileSync(file, 'utf8');
        const pick = (key) => {
            const match = text.match(new RegExp(`${key}\\s*=\\s*(?:'([^']*)'|"([^"]*)"|(\\d+))`));
            return match ? (match[1] ?? match[2] ?? match[3]) : undefined;
        };

        return {
            host: pick('SQL_HOST'),
            port: Number(pick('SQL_PORT') ?? 3306),
            user: pick('SQL_LOGIN'),
            password: pick('SQL_PASSWORD'),
            database: pick('SQL_DATABASE'),
            source: relative,
        };
    }

    return {};
}

function readConfigFile() {
    const file = path.join(appRoot, 'config.json');
    if (!fs.existsSync(file)) {
        return {};
    }

    return JSON.parse(fs.readFileSync(file, 'utf8'));
}

const fileConfig = readConfigFile();

export const port = Number(process.env.COMPANION_PORT ?? fileConfig.port ?? 8095);

export const db = fileConfig.db
    ? { ...fileConfig.db, source: 'tools/companion/config.json' }
    : readServerSqlSettings();
