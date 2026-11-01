// Read-only queries against xidb, for the data the map server already writes as it changes and the
// exporter therefore leaves out: EXP (SaveCharExp runs on every gain), crafting skills and gil.

import mysql from 'mysql2/promise';

// char_exp has one column per job, named by the job's lower-case abbreviation - the same names the
// exporter's job.mainName carries in upper case. The column name is interpolated into SQL, so it
// must come from this list and nowhere else.
const JOB_COLUMNS = new Set([
    'war', 'mnk', 'whm', 'blm', 'rdm', 'thf', 'pld', 'drk', 'bst', 'brd', 'rng',
    'sam', 'nin', 'drg', 'smn', 'blu', 'cor', 'pup', 'dnc', 'sch', 'geo', 'run',
]);

// char_skills ids for the crafts and other hobby skills, from scripts/enum/skill.lua. Their values
// are stored in tenths, so 56 is level 5.6.
const CRAFT_SKILLS = {
    48: 'Fishing',
    49: 'Woodworking',
    50: 'Smithing',
    51: 'Goldsmithing',
    52: 'Clothcraft',
    53: 'Leathercraft',
    54: 'Bonecraft',
    55: 'Alchemy',
    56: 'Cooking',
    57: 'Synergy',
    58: 'Chocobo Raising',
    59: 'Chocobo Digging',
};

// Gil is an item: id 65535 in the first slot of the main inventory.
const GIL_ITEM_ID = 65535;

export function createDb(settings) {
    const pool = mysql.createPool({
        host: settings.host,
        port: settings.port,
        user: settings.user,
        password: settings.password,
        database: settings.database,
        connectionLimit: 4,
    });

    async function progress(charId, jobName, level) {
        const job = String(jobName ?? '').toLowerCase();
        if (!JOB_COLUMNS.has(job)) {
            throw new Error(`unknown job '${jobName}'`);
        }

        const [[expRow]] = await pool.query(
            `SELECT \`${job}\` AS exp, merits, limits, mode FROM char_exp WHERE charid = ?`,
            [charId]);

        // TNL for level L is exp_base row L + 1: the server loads row N into g_ExpPerLevel[N - 1],
        // and GetExpNEXTLevel(L) reads g_ExpPerLevel[L].
        const [[tnlRow]] = await pool.query('SELECT exp FROM exp_base WHERE level = ?', [level + 1]);

        const [skillRows] = await pool.query(
            'SELECT skillid, value, `rank` FROM char_skills WHERE charid = ? AND skillid BETWEEN 48 AND 59',
            [charId]);

        const [[gilRow]] = await pool.query(
            'SELECT quantity FROM char_inventory WHERE charid = ? AND location = 0 AND slot = 0 AND itemId = ?',
            [charId, GIL_ITEM_ID]);

        return {
            job: job.toUpperCase(),
            level,
            exp: expRow?.exp ?? null,
            tnl: tnlRow?.exp ?? null,
            merits: expRow?.merits ?? null,
            limits: expRow?.limits ?? null,
            gil: gilRow ? Number(gilRow.quantity) : null,
            crafts: skillRows
                .filter((row) => CRAFT_SKILLS[row.skillid])
                .map((row) => ({
                    id: row.skillid,
                    name: CRAFT_SKILLS[row.skillid],
                    level: row.value / 10,
                    rank: row.rank,
                }))
                .sort((a, b) => a.id - b.id),
        };
    }

    async function ping() {
        await pool.query('SELECT 1');
    }

    return { progress, ping, end: () => pool.end() };
}
