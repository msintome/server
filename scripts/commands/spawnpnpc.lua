-----------------------------------
-- func: spawnpnpc
-- desc: Spawn a single in-memory player-looking NPC beside you.
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops = { permission = 5, parameters = 's' }

-- Build the 40-char equipped-look string the engine expects.
-- look_t layout (each field is a uint16, written low-byte then high-byte):
--   size, [face|race], head, body, hands, legs, feet, main, sub, ranged
local function buildLook(p)
    local function u16(v) return string.format('%02x%02x', v % 256, math.floor(v / 256) % 256) end
    return u16(1)                                    -- size = MODEL_EQUIPPED
        .. u16((p.face or 0) + (p.race or 1) * 256)  -- face (low byte) + race (high byte)
        .. u16(p.head or 0) .. u16(p.body or 0) .. u16(p.hands or 0)
        .. u16(p.legs or 0) .. u16(p.feet or 0)
        .. u16(p.main or 0) .. u16(p.sub or 0) .. u16(p.ranged or 0)
end

commandObj.onTrigger = function(player, name)
    local zoneObj = player:getInstance() or player:getZone()
    if not zoneObj then return end

    local mine = player:getEquipmentModelIds()  -- head, body, hands, main, sub
    local look = buildLook({
        race = xi.race.HUME_M, face = 0,         -- race/face aren't in that table; set to taste
        head = mine.head, body = mine.body, hands = mine.hands,
        legs = 0, feet = 0,                       -- default until you fill them in
        main = mine.main, sub = mine.sub,
    })

    local npc = zoneObj:insertDynamicEntity({
        objtype  = xi.objType.NPC,
        name     = name or 'Adventurer',  -- internal lookup name (stored as DE_<name>)
        look     = look,                  -- string -> equipped look (player model)
        x        = player:getXPos() + 1.5, -- beside you, not inside you
        y        = player:getYPos(),
        z        = player:getZPos(),
        rotation = player:getRotPos(),
        namevis  = 0,
        releaseIdOnDisappear = true,
    })

    if npc then
        player:printToPlayer(string.format('Spawned %s (targid %i)', npc:getName(), npc:getID()))
    end
end

return commandObj