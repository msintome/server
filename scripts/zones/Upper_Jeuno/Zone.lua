-----------------------------------
-- Zone: Upper_Jeuno (244)
-----------------------------------
---@type TZone
local zoneObject = {}

-- ============================================================
-- XI_LIFE: PlayerNPC population system
-- ============================================================

local function buildLook(p)
    local function u16(v) return string.format('%02x%02x', v % 256, math.floor(v / 256) % 256) end
    return u16(1)
        .. u16((p.face or 0) + (p.race or 1) * 256)
        .. u16(p.head or 0x1000) .. u16(p.body or 0x2000) .. u16(p.hands or 0x3000)
        .. u16(p.legs or 0x4000) .. u16(p.feet or 0x5000)
        .. u16(p.main or 0x6000) .. u16(p.sub or 0x7000) .. u16(p.ranged or 0)
end

local function pick(t)
    return t[math.random(#t)]
end

local gearPool =
{
    head   = { 0x1000, 0x1014, 0x1019, 0x1024 },
    body   = { 0x2000, 0x2007, 0x2017, 0x2019, 0x2066, 0x2088 },
    hands  = { 0x3000, 0x3007, 0x3008, 0x3019, 0x3066, 0x3088 },
    legs   = { 0x4000, 0x4007, 0x4019, 0x4066, 0x4067, 0x4088 },
    feet   = { 0x5000, 0x5003, 0x5007, 0x5019, 0x5066, 0x5088 },

    -- Model 0 is an empty slot. Townspeople walking around with a weapon drawn in each hand
    -- looks wrong, so main and sub stay empty; a slung ranged weapon reads fine.
    main   = { 0 },
    sub    = { 0 },
    ranged = { 0, 0x8035 },
}

local function randomGear()
    return
    {
        head = pick(gearPool.head), body   = pick(gearPool.body),
        hands = pick(gearPool.hands), legs  = pick(gearPool.legs),
        feet  = pick(gearPool.feet),  main  = pick(gearPool.main),
        sub   = pick(gearPool.sub),   ranged = pick(gearPool.ranged),
    }
end

-- ============================================================
-- Name generation
--
-- Names are built from syllable tables rather than a fixed list, so the population does not
-- visibly repeat. The style is picked from the race the PNPC rolled, following retail naming:
-- Tarutaru names double or hyphenate their syllables (Shantotto, Ajido-Marujido), Galka names
-- are short and hard-consonant (Zeid, Gumbah), Mithra names lean on soft syllables and vowel
-- endings (Perih, Nanaa), and Hume/Elvaan names are the general fantasy mix.
--
-- The client renders at most 15 characters (PacketNameLength in common/utils.h is 16 including
-- the terminator), so anything longer is rejected and re-rolled.
-- ============================================================

local MAX_NAME_LENGTH = 15

local nameParts =
{
    -- Hume and Elvaan: prefix + optional middle + suffix
    common =
    {
        head = {
            'Ald', 'Al', 'Ar', 'Bran', 'Bry', 'Cae', 'Cal', 'Cel', 'Cor', 'Dor',
            'Edr', 'El', 'Fen', 'Gar', 'Hal', 'Iv', 'Jor', 'Kae', 'Kes', 'Lyn',
            'Mar', 'Mer', 'Mir', 'Mor', 'Nol', 'Or', 'Per', 'Quen', 'Rael', 'Rho',
            'Sel', 'Sil', 'Tal', 'Tam', 'Thor', 'Tov', 'Ul', 'Val', 'Wyn', 'Yr',
        },
        mid  = { '', '', '', 'a', 'e', 'i', 'o', 'ia', 'we', 'ae', 'au', 'ei' },
        tail = {
            'ric', 'wyn', 'dan', 'lis', 'mir', 'ven', 'ron', 'sel', 'thas', 'dor',
            'na', 'ra', 'sa', 'la', 'ne', 'lyn', 'wen', 'ta', 'da', 'mund',
            'garde', 'ric', 'bert', 'wald', 'lian', 'rin', 'via', 'ce', 'iel', 'is',
        },
    },

    -- Tarutaru: syllables that read well doubled or hyphenated
    taru =
    {
        head = {
            'Aji', 'Chal', 'Kupi', 'Mora', 'Nana', 'Piku', 'Robo', 'Shan', 'Taru', 'Toto',
            'Wawa', 'Yoyo', 'Zuzu', 'Chomo', 'Fufu', 'Gigi', 'Hoho', 'Kiki', 'Momo', 'Pipi',
        },
        tail = { 'do', 'to', 'ru', 'ko', 'mi', 'na', 'pa', 'lo', 'ho', 'ma' },
    },

    -- Galka: single blunt word
    galka =
    {
        head = {
            'Ba', 'Ber', 'Dor', 'Grim', 'Gum', 'Hor', 'Kro', 'Mog', 'Nag', 'Rao',
            'Rok', 'Thok', 'Ug', 'Vor', 'Wer', 'Zeid', 'Zog', 'Dur', 'Gral', 'Muk',
        },
        tail = { 'bah', 'grimm', 'dak', 'thar', 'gor', 'nak', 'rum', 'dun', 'ok', 'ei' },
    },

    -- Mithra: soft syllables, vowel-leaning endings
    mithra =
    {
        head = {
            'Ari', 'Chi', 'Jaka', 'Kiri', 'Lha', 'Mia', 'Nari', 'Peri', 'Rhi', 'Sasa',
            'Shi', 'Tira', 'Uka', 'Vira', 'Yara', 'Zhi', 'Mihg', 'Kuha', 'Nala', 'Tsu',
        },
        tail = { 'h', 'ha', 'ra', 'na', 'ka', 'sa', 'la', 'mi', 'ya', 'ko' },
    },
}

local function buildName(race)
    local parts = nameParts.common
    local name

    if race == xi.race.TARU_M or race == xi.race.TARU_F then
        parts = nameParts.taru
        local head = pick(parts.head)

        if math.random(2) == 1 then
            -- Doubled: Shantotto, Kupipi
            name = head .. pick(parts.tail) .. pick(parts.tail)
        else
            -- Hyphenated: Ajido-Marujido
            name = head .. pick(parts.tail) .. '-' .. pick(parts.head) .. pick(parts.tail)
        end
    elseif race == xi.race.GALKA then
        parts = nameParts.galka
        name  = pick(parts.head) .. pick(parts.tail)
    elseif race == xi.race.MITHRA then
        parts = nameParts.mithra
        name  = pick(parts.head) .. pick(parts.tail)
    else
        name = pick(parts.head) .. pick(parts.mid) .. pick(parts.tail)
    end

    return name
end

local function randomName(race)
    -- Re-roll rather than truncate: a clipped name would read as a typo on the nameplate.
    for _ = 1, 10 do
        local name = buildName(race)

        if #name >= 3 and #name <= MAX_NAME_LENGTH then
            return name
        end
    end

    return 'Wanderer'
end

-- ============================================================
-- Points of interest
--
-- 'wander' points are places a PNPC loiters at before moving on. 'homepoint' and 'exit' are the
-- ways a real player actually leaves the zone, so arriving at one of those is what ends a PNPC's
-- life, rather than a fixed number of hops. The two differ only in how they look on arrival: a
-- player stands at a crystal for a moment working the menu, but walks straight through a zone
-- line, so home points get a short idle and exits vanish on the spot.
--
-- Home point positions come from npc_list (HomePoint#1-#3; #4 and #5 are unplaced placeholders at
-- the origin) and the zone line positions from the zonelines table, both for zone 244. The
-- 244 -> 244 zone line is the Mog House door.
-- ============================================================

local poi =
{
    { name = 'Shop',                 kind = 'wander',  x = -44.2267, y = -1.2200, z = 136.8933 },
    { name = 'Commercial District',  kind = 'wander',  x =  -5.8746, y =  2.0002, z =  69.0719 },
    { name = 'Chocobo Stables',      kind = 'wander',  x = -52.6679, y =  8.2001, z =  90.4535 },
    { name = 'Auction House',        kind = 'wander',  x = -53.5065, y =  0.9999, z =  17.7009 },

    { name = 'Home Point #1',        kind = 'homepoint', x = -98.981,  y =  0.000, z = 167.569 },
    { name = 'Home Point #2',        kind = 'homepoint', x =  32.000,  y = -1.000, z = -44.000 },
    { name = 'Home Point #3',        kind = 'homepoint', x = -52.000,  y =  1.000, z =  16.000 },

    { name = 'Batallia Downs exit',  kind = 'exit',      x = -106.095, y = -4.637, z = 189.999 },
    { name = 'Ru\'Lude Gardens exit', kind = 'exit',     x =   46.000, y = -6.542, z = -30.915 },
    { name = 'Lower Jeuno exit',     kind = 'exit',      x =    4.763, y = -1.796, z = -54.883 },
    { name = 'Mog House door',       kind = 'exit',      x =   49.180, y = -9.642, z = -82.946 },
}

local PNPC_COUNT       = 10
local STAND_TIME_MS    = 8000
local WANDER_PAUSE_MS  = 15000
local HOMEPOINT_IDLE_MS = 3000
local RESPAWN_DELAY_MS = 3000

-- Destinations are shared, so without a nudge everyone heading to the same point ends up standing
-- inside each other. Yalms of slop applied to x and z only; y is left alone so nobody is pushed
-- off a ledge or into the floor.
local DEST_JITTER = 1.5

local function jitter(value)
    return value + ((math.random() * 2) - 1) * DEST_JITTER
end

local activeForPlayer = {}

-- Forward declaration: walkToRandomPoi and the onPathComplete handler in spawnOnePNPC call
-- each other, and spawnOnePNPC is itself re-entered when a PNPC is replaced.
local walkToRandomPoi

local function spawnOnePNPC(zone, player)
    local playerId = player:getID()
    if not activeForPlayer[playerId] then return end

    local startIdx = math.random(#poi)
    local startPoi = poi[startIdx]

    local race = math.random(xi.race.HUME_M, xi.race.GALKA)
    local name = randomName(race)
    local face = math.random(0, 7)
    local gear = randomGear()

    local look = buildLook(
    {
        race = race, face = face,
        head = gear.head, body   = gear.body,  hands  = gear.hands,
        legs = gear.legs, feet   = gear.feet,  main   = gear.main,
        sub  = gear.sub,  ranged = gear.ranged,
    })

    local npc = zone:insertDynamicEntity(
    {
        objtype  = xi.objType.NPC,
        name     = name,
        look     = look,
        x        = jitter(startPoi.x),
        y        = startPoi.y,
        z        = jitter(startPoi.z),
        rotation = math.random(0, 255),

        -- namevis 0, not VIS_ICON: the (I) icon marks a talkable NPC and gives the game away.
        namevis  = 0,
        releaseIdOnDisappear = true,

        onPathComplete = function(npc)
            local arrived = poi[npc:getLocalVar('pnpcPoi')]
            local kind    = arrived and arrived.kind or 'exit'

            -- Loiter, then move on. A PNPC only stops travelling once it happens to pick a home
            -- point or a zone line, the same two ways a real player leaves the zone.
            if kind == 'wander' then
                npc:timer(WANDER_PAUSE_MS, function(n)
                    walkToRandomPoi(n)
                end)

                return
            end

            local leave = function(n)
                n:setStatus(xi.status.DISAPPEAR)

                if activeForPlayer[playerId] then
                    player:timer(RESPAWN_DELAY_MS, function(_)
                        spawnOnePNPC(zone, player)
                    end)
                end
            end

            -- A player pauses at a crystal to work the menu before warping out, but walks
            -- straight through a zone line.
            if kind == 'homepoint' then
                npc:timer(HOMEPOINT_IDLE_MS, leave)
            else
                leave(npc)
            end
        end,
    })

    if npc then
        npc:initNpcAi()
        npc:setLocalVar('pnpcPoi', startIdx)
        npc:timer(STAND_TIME_MS, function(n)
            walkToRandomPoi(n)
        end)
    end
end

walkToRandomPoi = function(npc)
    local currentIdx = npc:getLocalVar('pnpcPoi')
    local destIdx

    repeat
        destIdx = math.random(#poi)
    until destIdx ~= currentIdx

    local destPoi = poi[destIdx]

    npc:setLocalVar('pnpcPoi', destIdx)
    npc:pathTo(
        jitter(destPoi.x), destPoi.y, jitter(destPoi.z),
        xi.path.flag.WALLHACK + xi.path.flag.SCRIPT
    )
end

-- ============================================================
-- Zone events
-- ============================================================

zoneObject.onInitialize = function(zone)
    xi.chocobo.initZone(zone)

    -- XI_LIFE: the home point and zone line positions come straight out of the database rather
    -- than being walked to by hand, so confirm they are on the navmesh before PNPCs path to them.
    -- An off-mesh point would leave a PNPC stuck part-way, never arriving and never despawning.
    for _, point in ipairs(poi) do
        if not zone:isNavigablePoint({ x = point.x, y = point.y, z = point.z }) then
            printf('[XI_LIFE] Upper Jeuno PNPC point is off the navmesh: %s', point.name)
        end
    end
end

zoneObject.onZoneIn = function(player, prevZone)
    return xi.moghouse.onMoghouseZoneEvent(player, prevZone)
end

zoneObject.afterZoneIn = function(player)
    local playerId = player:getID()
    if activeForPlayer[playerId] then return end

    activeForPlayer[playerId] = true

    for i = 1, PNPC_COUNT do
        player:timer((i - 1) * 1000, function(_)
            local zone = player:getZone()  -- safe here, player fully loaded
            if zone then
                spawnOnePNPC(zone, player)
            end
        end)
    end
end

zoneObject.onZoneOut = function(player)
    -- XI_LIFE: stop spawning replacements when player leaves
    activeForPlayer[player:getID()] = nil
end

zoneObject.onConquestUpdate = function(zone, updatetype, influence, owner, ranking, isConquestAlliance)
    xi.conquest.onConquestUpdate(zone, updatetype, influence, owner, ranking, isConquestAlliance)
end

zoneObject.onTriggerAreaEnter = function(player, triggerArea)
end

zoneObject.onEventUpdate = function(player, csid, option, npc)
end

zoneObject.onEventFinish = function(player, csid, option, npc)
end

return zoneObject