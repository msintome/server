-----------------------------------
-- Companion exporter
--
-- Writes a live snapshot of each logged-in character to a JSON file once a second, for the
-- second-screen companion app to read. It covers what the database cannot: the database only learns
-- a character's position when they zone or log out (SaveCharPosition), so anything reading `chars`
-- mid-session sees where they last zoned in, not where they are standing.
--
-- What is deliberately left out is anything the map server already writes to xidb as it changes:
-- EXP (SaveCharExp runs on every gain), skills and crafts, inventory, gil, quests and missions. The
-- app reads those straight from the database, so this file stays small and about the moment.
--
-- One file per character, log/companion_<Name>.json, replaced whole on every tick by writing a
-- temp file and renaming it over the old one, so a reader never sees half a snapshot. On Windows the
-- rename cannot overwrite, so the old file is removed first, and for that instant the file is
-- missing: a reader should treat a missing or unparseable file as "try again next tick".
--
-- There is no logout hook to say a character has gone, so the file simply stops changing. `time` is
-- the Unix second it was written and `intervalMs` the cadence it is written at; a snapshot more than
-- a few intervals old means the character is offline or mid-zone.
--
-- Snapshot shape (schema 1):
--   schema, seq, time, intervalMs
--   character { id, name, nation }
--   zone      { id, name, region, regionName, weather, weatherName, mogHouse }
--   position  { x, y, z, rot }       server coordinates; rot is 0-255, and negative y is up
--   job       { main, mainName, mainLevel, sub, subName, subLevel }
--   vitals    { hp, maxHp, mp, maxMp, tp }
--   state     { status, statusName, animation, animationName, engaged, speed }
--   target    null, or { id, targId, name, kind, hpp, level, distance, x, y, z }
--   effects   [ { id, name, power, remainingMs } ]   remainingMs is 0 for effects with no duration
-----------------------------------
require('modules/module_utils')
require('scripts/globals/interaction/interaction_global')
-----------------------------------
local m = Module:new('companion_exporter')

-----------------------------------
-- Tuning
-----------------------------------

-- How often each character's snapshot is rewritten. A second is smooth enough for a position dot on
-- a map, and the file is a few hundred bytes, so the cost is nothing.
local EXPORT_INTERVAL_MS = 1000

-- Relative to the server's working directory, which is the repo root. log/ already exists and is
-- gitignored, so nothing needs creating or ignoring.
local OUTPUT_DIR = 'log/'

local SCHEMA_VERSION = 1

-----------------------------------
-- JSON
--
-- There is no JSON library on the Lua side, and the snapshot only ever holds strings, numbers,
-- booleans, nil and tables, so a small encoder covers it. Lua cannot tell an empty array from an
-- empty object, so arrays are marked with jsonArray; every other table is written as an object.
-----------------------------------

local arrayMeta = {}

local function jsonArray(t)
    return setmetatable(t or {}, arrayMeta)
end

-- A nil value removes its key from a Lua table, so a field the app should see as null rather than
-- missing is set to this instead.
local jsonNull = {}

local escapes =
{
    ['"']  = '\\"',
    ['\\'] = '\\\\',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
}

local function escapeChar(c)
    return escapes[c] or string.format('\\u%04x', string.byte(c))
end

local function encodeString(s)
    return '"' .. (s:gsub('[%c"\\]', escapeChar)) .. '"'
end

local function encodeNumber(n)
    -- NaN and the infinities have no JSON spelling.
    if n ~= n or n == math.huge or n == -math.huge then
        return 'null'
    end

    if n == math.floor(n) and math.abs(n) < 2 ^ 53 then
        return string.format('%d', n)
    end

    return string.format('%.3f', n)
end

local encode

local function encodeTable(t)
    local parts = {}

    if getmetatable(t) == arrayMeta then
        for i = 1, #t do
            parts[i] = encode(t[i])
        end

        return '[' .. table.concat(parts, ',') .. ']'
    end

    -- Sorted so the file reads the same way every tick, which makes it easy to eyeball a diff.
    local keys = {}
    for key, _ in pairs(t) do
        table.insert(keys, tostring(key))
    end

    table.sort(keys)

    for _, key in ipairs(keys) do
        table.insert(parts, encodeString(key) .. ':' .. encode(t[key]))
    end

    return '{' .. table.concat(parts, ',') .. '}'
end

encode = function(value)
    local valueType = type(value)

    if valueType == 'string' then
        return encodeString(value)
    elseif valueType == 'number' then
        return encodeNumber(value)
    elseif valueType == 'boolean' then
        return tostring(value)
    elseif value == jsonNull then
        return 'null'
    elseif valueType == 'table' then
        return encodeTable(value)
    end

    return 'null'
end

-----------------------------------
-- Enum names
--
-- The app could map ids to names itself, but the enums are right here, so the snapshot carries
-- both. Reverse tables are built on first use rather than at load, so this module does not depend
-- on the order enums and modules are loaded in. Where an enum has aliases for one value, whichever
-- name pairs() reaches first wins.
-----------------------------------

local reverseCache = {}

local function enumName(enumTable, value)
    if enumTable == nil or value == nil then
        return nil
    end

    local reverse = reverseCache[enumTable]
    if reverse == nil then
        reverse = {}
        for name, id in pairs(enumTable) do
            if type(id) == 'number' and reverse[id] == nil then
                reverse[id] = name
            end
        end

        reverseCache[enumTable] = reverse
    end

    return reverse[value]
end

-----------------------------------
-- Snapshot
-----------------------------------

local sequence = 0

local function describeTarget(player)
    local target = player:getTarget()
    if target == nil then
        return nil
    end

    local kind = 'other'
    if target:isMob() then
        kind = 'mob'
    elseif target:isPC() then
        kind = 'pc'
    elseif target:isNPC() then
        kind = 'npc'
    end

    local described =
    {
        id       = target:getID(),
        targId   = target:getTargID(),
        name     = target:getName(),
        kind     = kind,
        distance = player:checkDistance(target),
        x        = target:getXPos(),
        y        = target:getYPos(),
        z        = target:getZPos(),
    }

    -- HP and level are battle-entity calls, and warn when an NPC makes them.
    if kind ~= 'npc' then
        described.hpp   = target:getHPP()
        described.level = target:getMainLvl()
    end

    return described
end

local function describeEffects(player)
    local effects = jsonArray()

    for _, effect in ipairs(player:getStatusEffects() or {}) do
        local id = effect:getEffectType()

        table.insert(effects,
        {
            id          = id,
            name        = enumName(xi.effect, id),
            power       = effect:getPower(),
            remainingMs = effect:getTimeRemaining(),
        })
    end

    return effects
end

local function buildSnapshot(player)
    sequence = sequence + 1

    local region    = player:getCurrentRegion()
    local weather   = player:getWeather()
    local mainJob   = player:getMainJob()
    local subJob    = player:getSubJob()
    local status    = player:getStatus()
    local animation = player:getAnimation()

    return
    {
        schema     = SCHEMA_VERSION,
        seq        = sequence,
        time       = GetSystemTime(),
        intervalMs = EXPORT_INTERVAL_MS,

        character =
        {
            id     = player:getID(),
            name   = player:getName(),
            nation = player:getNation(),
        },

        -- In a Mog House the server still has the character standing in the street outside, so
        -- position is where they went in, and mogHouse is what tells the app not to draw it.
        zone =
        {
            id          = player:getZoneID(),
            name        = player:getZoneName(),
            region      = region,
            regionName  = enumName(xi.region, region),
            weather     = weather,
            weatherName = enumName(xi.weather, weather),
            mogHouse    = player:inMogHouse(),
        },

        position =
        {
            x   = player:getXPos(),
            y   = player:getYPos(),
            z   = player:getZPos(),
            rot = player:getRotPos(),
        },

        job =
        {
            main      = mainJob,
            mainName  = enumName(xi.job, mainJob),
            mainLevel = player:getMainLvl(),
            sub       = subJob,
            subName   = enumName(xi.job, subJob),
            subLevel  = player:getSubLvl(),
        },

        vitals =
        {
            hp    = player:getHP(),
            maxHp = player:getMaxHP(),
            mp    = player:getMP(),
            maxMp = player:getMaxMP(),
            tp    = player:getTP(),
        },

        -- animation is what says resting, fishing, sitting, crafting and so on; status is the
        -- entity's coarser lifecycle state.
        state =
        {
            status        = status,
            statusName    = enumName(xi.status, status),
            animation     = animation,
            animationName = enumName(xi.animation, animation),
            engaged       = player:isEngaged(),
            speed         = player:getSpeed(),
        },

        target  = describeTarget(player) or jsonNull,
        effects = describeEffects(player),
    }
end

-----------------------------------
-- Writing
-----------------------------------

-- Reported once per server run, so a missing directory or a locked file does not repeat every
-- second for every character.
local warnedAboutWrite = false

local function warnOnce(message)
    if not warnedAboutWrite then
        warnedAboutWrite = true
        printf('[COMPANION] %s', message)
    end
end

local function writeSnapshot(player)
    local path = OUTPUT_DIR .. 'companion_' .. player:getName() .. '.json'
    local temp = path .. '.tmp'

    local handle, err = io.open(temp, 'w')
    if not handle then
        warnOnce(string.format('cannot write %s: %s', temp, tostring(err)))
        return
    end

    handle:write(encode(buildSnapshot(player)))
    handle:close()

    -- os.rename will not replace an existing file on Windows. Removing first leaves a moment with no
    -- file at all, which readers are told to expect; a failed remove just means it did not exist.
    os.remove(path)
    local renamed, renameErr = os.rename(temp, path)
    if not renamed then
        warnOnce(string.format('cannot replace %s: %s', path, tostring(renameErr)))
    end
end

-----------------------------------
-- Loop
--
-- One chain of player timers per character. Timers belong to the entity and may or may not survive
-- a zone change, so the chain is restarted on every zone-in, and a per-character generation number
-- retires whichever chain was running before - an old one finds it is out of date on its next tick
-- and stops, so a zone change can never leave two chains writing the same file.
-----------------------------------

local generations = {}

local function exportNow(player)
    local ok, err = pcall(writeSnapshot, player)
    if not ok then
        warnOnce(string.format('export failed for %s: %s', player:getName(), tostring(err)))
    end
end

local function scheduleExport(player, generation)
    player:timer(EXPORT_INTERVAL_MS, function(playerArg)
        if generations[playerArg:getID()] ~= generation then
            return
        end

        -- Reschedule before exporting, so a snapshot that throws cannot end the chain.
        scheduleExport(playerArg, generation)
        exportNow(playerArg)
    end)
end

-----------------------------------
-- Hooks
--
-- afterZoneIn runs for every zone, including the first one after logging in, once the character is
-- fully loaded and getZone() is valid. Call super first and hand its result back: the return value
-- is consumed upstream.
-----------------------------------

m:addOverride('InteractionGlobal.afterZoneIn', function(player, fallbackFn)
    local result = super(player, fallbackFn)

    local id         = player:getID()
    local generation = (generations[id] or 0) + 1
    generations[id]  = generation

    -- Write straight away rather than a second from now, so the app sees a zone change the moment
    -- it lands.
    exportNow(player)
    scheduleExport(player, generation)

    return result
end)

return m
