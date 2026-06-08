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

local gearPool =
{
    head   = { 0x1000, 0x1014, 0x1019, 0x1024 },
    body   = { 0x2000, 0x2007, 0x2017, 0x2019, 0x2066, 0x2088 },
    hands  = { 0x3000, 0x3007, 0x3008, 0x3019, 0x3066, 0x3088 },
    legs   = { 0x4000, 0x4007, 0x4019, 0x4066, 0x4067, 0x4088 },
    feet   = { 0x5000, 0x5003, 0x5007, 0x5019, 0x5066, 0x5088 },
    main   = { 0x6000, 0x6005 },
    sub    = { 0x7000 },
    ranged = { 0, 0x8035 },
}

local function randomGear()
    local function pick(t) return t[math.random(#t)] end
    return
    {
        head = pick(gearPool.head), body   = pick(gearPool.body),
        hands = pick(gearPool.hands), legs  = pick(gearPool.legs),
        feet  = pick(gearPool.feet),  main  = pick(gearPool.main),
        sub   = pick(gearPool.sub),   ranged = pick(gearPool.ranged),
    }
end

local namePool =
{
    'Arith',  'Mevra',  'Kaulen', 'Siona',  'Bryce',
    'Tamlin', 'Celeste','Dorvan', 'Railis', 'Phete',
    'Ouren',  'Brann',  'Kessa',  'Morvyn', 'Aldric',
    'Caile',  'Fenris', 'Elara',  'Toven',  'Miriel',
}

local poi =
{
    { name = 'Auction House',      x =   4.284, y =  1.800, z =  59.834 },
    { name = 'Main Plaza',         x = -64.390, y =  1.000, z =  23.704 },
    { name = 'Residential Area',   x = -76.415, y = -1.199, z =  80.011 },
    { name = 'Mog House Entrance', x =  43.637, y = -5.000, z = -73.161 },
    { name = 'Home Point',         x = -52.000, y =  1.000, z =  16.000 },
    { name = "Doctor's Office",    x = -42.381, y = -0.499, z =  -1.913 },
    { name = 'Market District',    x = -55.378, y = -0.301, z =  44.873 },
    { name = 'Residential Path',   x = -75.041, y = -1.200, z =  57.281 },
    { name = 'Upper Shops',        x = -54.310, y =  8.200, z =  85.940 },
    { name = 'Chocobo Stables',    x = -61.421, y =  8.199, z =  94.162 },
}

local PNPC_COUNT      = 5
local STAND_TIME_MS   = 30000
local RESPAWN_DELAY_MS = 3000

local activeForPlayer = {}

local function spawnOnePNPC(zone, player)
    local playerId = player:getID()
    if not activeForPlayer[playerId] then return end

    local startIdx = math.random(#poi)
    local destIdx
    repeat destIdx = math.random(#poi) until destIdx ~= startIdx

    local startPoi = poi[startIdx]
    local destPoi  = poi[destIdx]

    local name = namePool[math.random(#namePool)]
    local race = math.random(1, 8)
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
        x        = startPoi.x,
        y        = startPoi.y,
        z        = startPoi.z,
        rotation = math.random(0, 255),
        namevis  = 1,
        releaseIdOnDisappear = true,

        onPathComplete = function(npc)
            player:printToPlayer(
                string.format('%s arrived at the %s.', name, destPoi.name),
                xi.msg.channel.NS_SAY
            )
            npc:setStatus(xi.status.DISAPPEAR)

            if activeForPlayer[playerId] then
                player:timer(RESPAWN_DELAY_MS, function(_)
                    spawnOnePNPC(zone, player)
                end)
            end
        end,
    })

    if npc then
        npc:initNpcAi()
        npc:timer(STAND_TIME_MS, function(n)
            n:pathTo(
                destPoi.x, destPoi.y, destPoi.z,
                xi.path.flag.WALLHACK + xi.path.flag.SCRIPT
            )
        end)
    end
end

-- ============================================================
-- Zone events
-- ============================================================

zoneObject.onInitialize = function(zone)
    xi.chocobo.initZone(zone)
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