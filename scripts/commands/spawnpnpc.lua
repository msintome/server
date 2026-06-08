-----------------------------------
-- func: spawnpnpc
-- desc: Spawns a random player-looking NPC in Upper Jeuno that walks
--       to the Mog House entrance and then despawns.
-- usage: !spawnpnpc (name defaults to "Fade")
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops = { permission = 1, parameters = 's' }

-- Build the 40-char equipped look string.
-- Each field is a uint16, written low-byte then high-byte.
-- Gear fields use slot-index encoding: value = (slot_index << 12) | model_id
-- Empty slot sentinels: head=0x1000, body=0x2000, hands=0x3000,
--                       legs=0x4000, feet=0x5000, main=0x6000, sub=0x7000
local function buildLook(p)
    local function u16(v) return string.format('%02x%02x', v % 256, math.floor(v / 256) % 256) end
    return u16(1)                                          -- size = MODEL_EQUIPPED
        .. u16((p.face or 0) + (p.race or 1) * 256)       -- face (low) + race (high)
        .. u16(p.head   or 0x1000)                         -- head  (slot 1)
        .. u16(p.body   or 0x2000)                         -- body  (slot 2)
        .. u16(p.hands  or 0x3000)                         -- hands (slot 3)
        .. u16(p.legs   or 0x4000)                         -- legs  (slot 4)
        .. u16(p.feet   or 0x5000)                         -- feet  (slot 5)
        .. u16(p.main   or 0x6000)                         -- main  (slot 6)
        .. u16(p.sub    or 0x7000)                         -- sub   (slot 7)
        .. u16(p.ranged or 0)                              -- ranged
end

-- Gear model pools, decoded from actual equipped-look NPCs in npc_list.
-- Values include the slot-index prefix, so they drop directly into buildLook.
--   0xN000 = slot N, no gear (underwear/default for that slot)
--   0xN0XX = slot N, model XX
local gearPool = {
    head   = { 0x1000, 0x1014, 0x1019, 0x1024 },
    body   = { 0x2000, 0x2007, 0x2017, 0x2019, 0x2066, 0x2088 },
    hands  = { 0x3000, 0x3007, 0x3008, 0x3019, 0x3066, 0x3088 },
    legs   = { 0x4000, 0x4007, 0x4019, 0x4066, 0x4067, 0x4088 },
    feet   = { 0x5000, 0x5003, 0x5007, 0x5019, 0x5066, 0x5088 },
    main   = { 0x6000, 0x6005 },    -- none or a basic one-handed weapon
    sub    = { 0x7000 },
    ranged = { 0, 0x8035 },
}

local function randomGear()
    local function pick(pool) return pool[math.random(#pool)] end
    return {
        head   = pick(gearPool.head),
        body   = pick(gearPool.body),
        hands  = pick(gearPool.hands),
        legs   = pick(gearPool.legs),
        feet   = pick(gearPool.feet),
        main   = pick(gearPool.main),
        sub    = pick(gearPool.sub),
        ranged = pick(gearPool.ranged),
    }
end

-- Destination: near the residential area entrance in Upper Jeuno.
-- Use !pos while standing at the Mog House door and update these if needed.
local MOG_HOUSE = { x = 43.6371, y = -5, z = -73.1605 }

commandObj.onTrigger = function(player, name)
    if player:getZone():getName() ~= 'Upper_Jeuno' then
        player:printToPlayer('!spawnpnpc: must be in Upper Jeuno.')
        return
    end

    name = (name and name ~= '') and name or 'Fade'

    local race = math.random(1, 8)
    local face = math.random(0, 7)
    local gear = randomGear()

    local look = buildLook({
        race = race, face = face,
        head = gear.head, body = gear.body, hands = gear.hands,
        legs = gear.legs, feet = gear.feet,
        main = gear.main, sub  = gear.sub, ranged = gear.ranged,
    })

    local npc = player:getZone():insertDynamicEntity({
        objtype  = xi.objType.NPC,
        name     = name,
        look     = look,
        x        = player:getXPos() + 1.5,
        y        = player:getYPos(),
        z        = player:getZPos(),
        rotation = player:getRotPos(),
        namevis  = 1,
        releaseIdOnDisappear = true,

        -- 1. Rename onPath → onPathComplete, drop the atPoint check
        onPathComplete = function(npc)
            player:printToPlayer(
                string.format('%s found their way back to the Mog House.', name),
                xi.msg.channel.NS_SAY
            )
            npc:setStatus(xi.status.DISAPPEAR)
        end,
    })

    if npc then
        npc:initNpcAi()
        npc:pathTo(
            MOG_HOUSE.x, MOG_HOUSE.y, MOG_HOUSE.z,
            xi.path.flag.WALLHACK + xi.path.flag.SCRIPT
        )
        player:printToPlayer(string.format(
            'Spawned %s (race %i, face %i) - heading to the Mog House.',
            name, race, face
        ))
    end
end

return commandObj