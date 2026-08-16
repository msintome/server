-----------------------------------
-- func: addnpcpoi
-- desc: Adds whatever you currently have targeted as an XI_LIFE point of interest, so PlayerNPCs
--       will walk to it. Points are written to modules/custom/lua/xi_life_custom_pois.lua and
--       take effect on the next map server start.
--
--       That file is separate from the generated xi_life_pois.lua on purpose: regenerating the
--       point data with tools/xi_life/generate_pois.py will not touch anything added here.
--
-- usage: !addnpcpoi           -- adds the target as a 'wander' point (somewhere to loiter)
--      : !addnpcpoi homepoint -- or exit, auction, wander
-----------------------------------
require('modules/module_utils')
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops = { permission = 1, parameters = 's' }

local CUSTOM_POI_FILE = './modules/custom/lua/xi_life_custom_pois.lua'

local validKinds =
{
    wander    = true,
    homepoint = true,
    auction   = true,
    exit      = true,
}

-- Rewrites the whole file rather than appending, so the output stays a well-formed table no
-- matter how many points have been added.
local function writeCustomPois()
    local handle, err = io.open(CUSTOM_POI_FILE, 'w')
    if not handle then
        return false, tostring(err)
    end

    handle:write('-----------------------------------\n')
    handle:write('-- XI_LIFE PlayerNPC points added in game with !addnpcpoi\n')
    handle:write('--\n')
    handle:write('-- Written by the command; safe to hand-edit or prune. Not touched by\n')
    handle:write('-- tools/xi_life/generate_pois.py, which owns xi_life_pois.lua instead.\n')
    handle:write('-----------------------------------\n')
    handle:write('xi = xi or {}\n')
    handle:write('xi.xiLife = xi.xiLife or {}\n')
    handle:write('\n')
    handle:write('xi.xiLife.customPois =\n')
    handle:write('{\n')

    for zoneId, points in pairs(xi.xiLife.customPois) do
        handle:write(string.format('    [%d] =\n', zoneId))
        handle:write('    {\n')

        for _, point in ipairs(points) do
            handle:write(string.format(
                "        { name = '%s', kind = '%s', x = %.3f, y = %.3f, z = %.3f },\n",
                (point.name:gsub("'", "\\'")), point.kind, point.x, point.y, point.z))
        end

        handle:write('    },\n')
        handle:write('\n')
    end

    handle:write('}\n')
    handle:write('\n')
    handle:write('return xi.xiLife.customPois\n')
    handle:close()

    return true
end

commandObj.onTrigger = function(player, kind)
    kind = kind or 'wander'

    if not validKinds[kind] then
        player:printToPlayer('Unknown point kind. Use wander, homepoint, auction or exit.', xi.msg.channel.SYSTEM_3)

        return
    end

    local target = player:getCursorTarget()
    if not target then
        player:printToPlayer('Target something first, then run !addnpcpoi.', xi.msg.channel.SYSTEM_3)

        return
    end

    local zone = player:getZone()
    if not zone then
        return
    end

    local zoneId = zone:getID()

    if not xi.xiLife.pois or not xi.xiLife.pois[zoneId] then
        player:printToPlayer(
            string.format('%s is not an XI_LIFE zone, so this point would never be used.', zone:getName()),
            xi.msg.channel.SYSTEM_3)

        return
    end

    xi.xiLife.customPois = xi.xiLife.customPois or {}
    xi.xiLife.customPois[zoneId] = xi.xiLife.customPois[zoneId] or {}

    local point =
    {
        name = target:getName(),
        kind = kind,
        x    = target:getXPos(),
        y    = target:getYPos(),
        z    = target:getZPos(),
    }

    table.insert(xi.xiLife.customPois[zoneId], point)

    local ok, err = writeCustomPois()
    if not ok then
        player:printToPlayer(string.format('Could not write the point file: %s', err), xi.msg.channel.SYSTEM_3)

        return
    end

    player:printToPlayer(
        string.format('Added %s (%s) at %.1f, %.1f, %.1f in %s. Live after the next map restart.',
            point.name, point.kind, point.x, point.y, point.z, zone:getName()),
        xi.msg.channel.SYSTEM_3)
end

return commandObj
