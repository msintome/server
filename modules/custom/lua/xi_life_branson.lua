-----------------------------------
-- XI_LIFE: Branson
--
-- One named, recurring face. Where xi_life.lua fills a city with anonymous PlayerNPCs who arrive,
-- loiter and leave, Branson is the same character: a dark-haired Hume male in full monk Artifact.
-- He is not in every city, though - each city you walk into has a BRANSON_SPAWN_CHANCE of turning
-- up with him in it, decided once per visit, so he stays an occasional face rather than a shadow.
-- Where he is present he never leaves through a zone line and is never replaced for the length of
-- the visit.
--
-- His one trick is that he notices the player. Come within GREET_RANGE and, on a GREET_SAY_CHANCE
-- roll, he stops dead, turns to face them, waves, and greets them by name, then holds that for
-- GREET_DURATION - re-facing them on every tick, so he tracks the player rather than staring at
-- where they used to be. He will not do it twice inside GREET_GLOBAL_COOLDOWN, and rolls only once
-- per approach, so passing him is a chance of a hello rather than a guarantee of one. He breaks off
-- early if the player walks away, and runs rather than walks when he does move on.
--
-- He rides on xi_life's prepared zone data through xi.xiLife.runtime: the same navmesh-validated
-- points, and the same standing-slot bookkeeping, so he and the anonymous crowd can never claim the
-- same spot. He deliberately does not set the 'xiLife' local var, which is what keeps xi_life's own
-- chatter, roadside encounters and stuck watchdog from picking him up - his behaviour is all here.
-----------------------------------
require('modules/module_utils')
require('scripts/globals/interaction/interaction_global')
require('modules/custom/lua/xi_life_appearance')
-----------------------------------
local m = Module:new('xi_life_branson')

-----------------------------------
-- Who he is
-----------------------------------

local BRANSON_NAME = 'Branson'

-- Face is a single byte covering all eight faces and both hair variants of each: (face - 1) * 2,
-- plus one for the B variant, which is why login_helpers.cpp rejects anything above 15 as past
-- "Face 8B". 0 is Hume male face 1A, the short dark-haired one. Change this number if a different
-- head suits him better - nothing else depends on it.
local BRANSON_RACE = xi.race.HUME_M
local BRANSON_FACE = 0

-- Monk Artifact, the Temple set (Temple Crown is item 12512, model 66). Every piece of an Artifact
-- set shares the one model, so a full set is that number in all five armour slots. look_t packs a
-- slot as (slotIndex << 12) | model - see look_t in common/mmo.h.
local MNK_ARTIFACT_MODEL = 66

local armourSlotIndex =
{
    head  = 1,
    body  = 2,
    hands = 3,
    legs  = 4,
    feet  = 5,
}

-----------------------------------
-- Tuning
-----------------------------------

-- One poll drives everything: the proximity check that starts a greeting, the re-facing that keeps
-- him looking at the player during one, and the stuck check while he is walking. Two seconds is
-- close enough that his head follows the player around without a visible lag.
local TICK_MS = 2000

-- Near enough to count as passing each other. Comfortably inside the distance at which the player
-- can read a nameplate, so the greeting always has a face attached to it.
local GREET_RANGE = 10.0

-- And the distance at which he decides the player has gone. Wider than GREET_RANGE on purpose: with
-- one threshold for both, a player loitering right on the boundary would have him start and abandon
-- the greeting every couple of ticks.
local GREET_BREAK_RANGE = 13.0

-- Height still matters in a city built in layers. Ten yalms of separation on the map means nothing
-- if the player is on the tier above him.
local GREET_HEIGHT = 4.0

-- How long he stands and talks, in seconds, and how long he keeps standing there after the player
-- has walked out of range. The grace period is what stops him spinning on his heel the instant the
-- player turns their back.
local GREET_DURATION     = 15
local PLAYER_LEFT_GRACE  = 2

-- Gap between him coming to a stop facing the player and the wave that follows it. Long enough for
-- the rotation to have reached the client and played out, short enough to still read as one motion.
local WAVE_DELAY_MS = 800

-- Whether he shows up at all. Rolled once per genuine city visit - one where the zone actually
-- changed since the player was last placed somewhere, so Jeuno -> field -> Jeuno re-rolls but a
-- Jeuno -> Mog House -> Jeuno trip keeps the previous answer and he does not blink out mid-visit.
-- Most cities you walk into will not have him, which is the point: an occasional face, not a
-- fixture in every zone.
local BRANSON_SPAWN_CHANCE = 40

-- Whether he says anything when the player comes within GREET_RANGE. Rolled once per approach - the
-- rising edge of entering range - never every tick, or lingering near him would re-roll until it
-- hit and every pass would end in a greeting. A failed roll is spent for that approach: he stays
-- quiet until the player leaves range and comes back.
local GREET_SAY_CHANCE = 50

-- And he will not greet the same player twice inside this window, in seconds, however many times
-- they pass. Unlike every other timer here this has to survive him despawning and respawning as the
-- player walks from one city to the next, so it lives in a module table keyed by player rather than
-- in a local var on the NPC, which would reset with each fresh spawn. Ten minutes.
local GREET_GLOBAL_COOLDOWN = 600

-- A beat between spawning and setting off, so he does not pop into existence already sprinting.
local ARRIVAL_PAUSE_MS = 5000

-- How long he stands at a point before moving on. Shorter than the anonymous crowd's loiter: he is
-- meant to be seen moving around a city rather than parked at a counter.
local LOITER_MIN_MS = 8000
local LOITER_MAX_MS = 20000

-- CPathFind::PathTo silently ignores a destination within a yalm of where the entity already stands
-- (arePositionsClose in pathfind.cpp), which would strand him with no onPathComplete to move him on
-- again. Keep destinations well clear of that.
local MIN_TRAVEL_DISTANCE = 5.0

-- A clean arrival snaps to the destination exactly, so a large gap between his height and the
-- point's means the path got snapped to a surface above or below - the same vertical ambiguity
-- xi_life guards against, since pathTo resolves with a 5 yalm pick extent while the slot was
-- validated with 1.
local ARRIVAL_Y_TOLERANCE = 2.0

-- Stuck rescue. A path that stops making progress never reaches onPathComplete, so nothing else
-- would ever move him again. He is not despawned for it the way an anonymous PNPC is - he is the
-- one character who has to still be there - so he is simply sent somewhere else.
local STUCK_MOVE_EPSILON = 0.5
local STUCK_STRIKES      = 3

-----------------------------------
-- Greetings
--
-- Short enough to read as something called across a street. The player's own name is prepended, so
-- these are only ever the tail of the line.
-----------------------------------

local greetings =
{
    'Good to see you.',
    'Off adventuring again?',
    'Still in one piece, I see.',
    'Been a while!',
    'Fine day for it.',
    'Keep your guard up out there.',
    'Heading out, or heading back?',
    'Don\'t let me hold you up.',
    'Any luck with that drop yet?',
    'You look like you could use a rest.',
    'Safe travels.',
    'Give them hell out there.',
    'Say hello to the others for me.',
    'Training hard, I hope.',
    'Mind how you go.',
    'Same as ever, I see.',
}

-----------------------------------
-- State
--
-- One entry per zone we have spawned him into. He is found by scanning for his local var rather
-- than by holding on to the entity, the same way xi_life finds its own, so a stale reference can
-- never outlive a despawn.
-----------------------------------

local zoneState = {}

local MODE_TRAVEL   = 0
local MODE_GREETING = 1

-- Cross-zone greeting cooldown, keyed by player id: 'when did he last actually speak to this
-- player'. Module-level so it outlives him despawning as the player crosses from one city to the
-- next - a local var on the NPC would reset with every new zone's fresh spawn.
local lastGreet = {}

-- The city zone each player was last placed in, keyed by player id. Used to tell a genuine new
-- visit (re-roll his presence) from a Mog House trip back into the same zone (keep the decision).
local lastZone = {}

local function canGreet(player)
    local last = lastGreet[player:getID()] or 0

    return (GetSystemTime() - last) >= GREET_GLOBAL_COOLDOWN
end

-- xi_life.lua and this file are separate entries in modules/init.txt, and nothing sequences them
-- beyond the order they are listed in. Resolving the handle at call time rather than capturing it
-- at load time makes that order irrelevant.
local function runtime()
    return xi.xiLife and xi.xiLife.runtime
end

local function encode(slot, model)
    return (armourSlotIndex[slot] * 0x1000) + model
end

local function bransonIn(zone)
    for _, npc in pairs(zone:getNPCs()) do
        if npc:getLocalVar('xiLifeBranson') == 1 and npc:getStatus() ~= xi.status.DISAPPEAR then
            return npc
        end
    end

    return nil
end

-- Nearest player who can actually see the city, within the given range and on roughly his own
-- level. watchingPlayers filters out anyone inside a Mog House: entering one is a zone change back
-- into the same zone, so such a player is still standing in the street as far as the server is
-- concerned while the client draws a room around them.
local function nearestPlayer(npc, zone, range)
    local rt = runtime()
    if not rt then
        return nil
    end

    local best     = nil
    local bestDist = range * range

    for _, player in ipairs(rt.watchingPlayers(zone)) do
        local dx = player:getXPos() - npc:getXPos()
        local dy = player:getYPos() - npc:getYPos()
        local dz = player:getZPos() - npc:getZPos()

        local flat = (dx * dx) + (dz * dz)

        if flat <= bestDist and math.abs(dy) <= GREET_HEIGHT then
            best     = player
            bestDist = flat
        end
    end

    return best
end

-----------------------------------
-- Travelling
-----------------------------------

local walkOn
local scheduleLoiter

-- Every pending timer carries the trip number it was queued under. Bumping the number retires all
-- of them at once, which is what lets a greeting interrupt a loiter without the old loiter timer
-- firing later and re-routing him mid-conversation.
local function newTrip(npc)
    local trip = npc:getLocalVar('bransonTrip') + 1

    npc:setLocalVar('bransonTrip', trip)

    return trip
end

-- Sends him to a point he is not already standing at. Zone lines are a last resort rather than a
-- destination: he never leaves through one, so walking to a doorway only to turn around and come
-- back is something to do when the zone offers nothing else.
walkOn = function(npc, zone, zoneId, running)
    local rt    = runtime()
    local state = rt and rt.stateOf(zoneId)

    if not state or not state.enabled then
        return
    end

    local trip       = newTrip(npc)
    local currentIdx = npc:getLocalVar('xiLifePoint')
    local preferred  = {}
    local fallback   = {}

    for idx, point in ipairs(state.points) do
        if idx ~= currentIdx then
            local dx        = point.x - npc:getXPos()
            local dz        = point.z - npc:getZPos()
            local farEnough = ((dx * dx) + (dz * dz)) > (MIN_TRAVEL_DISTANCE * MIN_TRAVEL_DISTANCE)

            if farEnough then
                if point.kind == 'exit' then
                    table.insert(fallback, idx)
                else
                    table.insert(preferred, idx)
                end
            end
        end
    end

    local choices = #preferred > 0 and preferred or fallback

    -- Nowhere worth walking to. Stand still and try again shortly rather than despawning: an
    -- anonymous PNPC with no route can simply leave, but he is the one who has to still be here.
    if #choices == 0 then
        npc:timer(math.random(LOITER_MIN_MS, LOITER_MAX_MS), function(n)
            if n:getLocalVar('bransonTrip') == trip then
                walkOn(n, zone, zoneId, false)
            end
        end)

        return
    end

    local destIdx     = choices[math.random(#choices)]
    local destination = state.points[destIdx]

    -- Give up the spot he has been standing in before claiming the next, or he would hold two slots
    -- for the length of the walk.
    rt.releaseSlot(state, npc)

    local slotIdx = rt.chooseSlot(destination, npc:getXPos(), npc:getZPos())
    if slotIdx > 0 then
        destination.taken[slotIdx] = npc:getID()
    end

    npc:setLocalVar('xiLifePoint', destIdx)
    npc:setLocalVar('xiLifeSlot', slotIdx)

    local x, y, z = rt.destinationOf(destination, slotIdx)
    local flags   = xi.path.flag.WALLHACK + xi.path.flag.SCRIPT

    if running then
        flags = flags + xi.path.flag.RUN
    end

    npc:pathTo(x, y, z, flags)
end

scheduleLoiter = function(npc, zone, zoneId)
    local trip = newTrip(npc)

    npc:timer(math.random(LOITER_MIN_MS, LOITER_MAX_MS), function(n)
        -- Retired by a later trip, or he has stopped to talk to someone. Either way the greeting
        -- code owns what happens next.
        if n:getLocalVar('bransonTrip') ~= trip or n:getLocalVar('bransonMode') == MODE_GREETING then
            return
        end

        walkOn(n, zone, zoneId, false)
    end)
end

local function arriveAt(npc, zone, zoneId)
    local rt    = runtime()
    local state = rt and rt.stateOf(zoneId)

    if not state or not state.enabled then
        return
    end

    local point = state.points[npc:getLocalVar('xiLifePoint')]

    -- Arrived at the right place but the wrong height, which means the route was snapped to another
    -- storey. Let go of the slot and pick somewhere else. The slot is left in circulation rather
    -- than blacklisted: xi_life owns that data and retires bad slots itself when one of its own
    -- PNPCs lands on the same problem.
    if point and math.abs(npc:getYPos() - point.y) > ARRIVAL_Y_TOLERANCE then
        rt.releaseSlot(state, npc)
        walkOn(npc, zone, zoneId, false)

        return
    end

    -- Face whatever he walked over to look at. Zone lines are a doorway rather than a thing to
    -- stare at, so those are left alone.
    if point and point.kind ~= 'exit' then
        npc:lookAt(point.x, point.y, point.z)
    end

    scheduleLoiter(npc, zone, zoneId)
end

-----------------------------------
-- Greeting
-----------------------------------

local function startGreeting(npc, zone, zoneId, player)
    -- Stop before turning, so he faces the player from where he actually came to rest. clearPath
    -- does not fire onPathComplete (CPathFind::Clear just empties the point list), so nothing in
    -- the travel lifecycle runs behind this.
    npc:clearPath()
    npc:lookAt(player:getXPos(), player:getYPos(), player:getZPos())

    -- Retires the loiter or arrival timer that was pending, so it cannot fire mid-greeting. The
    -- number it returns is what the wave below checks itself against.
    local trip = newTrip(npc)

    npc:setLocalVar('bransonMode', MODE_GREETING)
    npc:setLocalVar('bransonUntil', GetSystemTime() + GREET_DURATION)
    npc:setLocalVar('bransonLeft', 0)

    -- Stop, turn, then wave - in that order, with a beat in between. The turn is a rotation change
    -- riding out on the next entity update, so firing the emote in the same instant would have him
    -- waving while still swinging round to face the player. The spoken line goes with the wave
    -- rather than the turn, so the whole greeting lands as one gesture once he is actually looking
    -- at them.
    npc:timer(WAVE_DELAY_MS, function(n)
        if n:getLocalVar('bransonTrip') ~= trip or n:getLocalVar('bransonMode') ~= MODE_GREETING then
            return
        end

        -- Look the player up again rather than closing over the one who triggered this. The timer
        -- lives on Branson, not on them, so it outlives their zoning out or logging off in the gap,
        -- and a captured entity would be a stale pointer by the time it fired. Nobody in range any
        -- more means the greeting has already fallen apart; the next tick will end it properly.
        local target = nearestPlayer(n, zone, GREET_BREAK_RANGE)
        if not target then
            return
        end

        -- Stamp the cooldown at the moment he actually speaks, not when the greeting was committed
        -- 800ms ago: if the player slipped out of range in that gap he never said anything, so the
        -- ten minutes should not start.
        lastGreet[target:getID()] = GetSystemTime()

        -- MOTION, not ALL: the client would otherwise print its own "Branson waves" line on top of
        -- what he is already saying. The animation is the half worth having.
        n:sendEmote(target, xi.emote.WAVE, xi.emoteMode.MOTION, false)

        local line = string.format('Hey %s! %s', target:getName(), greetings[math.random(#greetings)])

        target:printToPlayer(line, xi.msg.channel.SAY, BRANSON_NAME)
    end)
end

local function endGreeting(npc, zone, zoneId)
    npc:setLocalVar('bransonMode', MODE_TRAVEL)
    npc:setLocalVar('bransonLeft', 0)

    -- No per-NPC cooldown to set here: the GREET_GLOBAL_COOLDOWN table is what stops him greeting
    -- again, and bransonNear (still latched, since the player is right in front of him) stops the
    -- approach roll re-firing until they actually leave and come back.

    -- Running, not walking. Someone who stopped mid-errand to say hello does not amble away from it.
    walkOn(npc, zone, zoneId, true)
end

-- Keeps him pointed at the player, and decides when the conversation is over. Two ways it ends: the
-- fifteen seconds run out, or the player walked off and the grace period since has expired.
local function greetingTick(npc, zone, zoneId)
    local now    = GetSystemTime()
    local player = nearestPlayer(npc, zone, GREET_BREAK_RANGE)

    if player then
        npc:lookAt(player:getXPos(), player:getYPos(), player:getZPos())
        npc:setLocalVar('bransonLeft', 0)
    elseif npc:getLocalVar('bransonLeft') == 0 then
        npc:setLocalVar('bransonLeft', now)
    end

    local leftAt    = npc:getLocalVar('bransonLeft')
    local timeUp    = now >= npc:getLocalVar('bransonUntil')
    local walkedOff = leftAt > 0 and (now - leftAt) >= PLAYER_LEFT_GRACE

    if timeUp or walkedOff then
        endGreeting(npc, zone, zoneId)
    end
end

-----------------------------------
-- Stuck rescue
--
-- Compares him against where he stood last tick, and only while he is nominally following a path.
-- A greeting clears his path, so standing still to talk cannot be mistaken for being stuck.
-----------------------------------

local function stuckTick(npc, zone, zoneId)
    local state = zoneState[zoneId]

    if not npc:isFollowingPath() then
        state.watch = nil

        return
    end

    local x     = npc:getXPos()
    local z     = npc:getZPos()
    local watch = state.watch

    local moved =
        not watch or
        math.abs(x - watch.x) >= STUCK_MOVE_EPSILON or
        math.abs(z - watch.z) >= STUCK_MOVE_EPSILON

    if moved then
        state.watch = { x = x, z = z, strikes = 0 }

        return
    end

    watch.strikes = watch.strikes + 1

    if watch.strikes >= STUCK_STRIKES then
        state.watch = nil
        npc:clearPath()
        walkOn(npc, zone, zoneId, false)
    end
end

-----------------------------------
-- Tick
-----------------------------------

local tick

tick = function(npc, zone, zoneId, generation)
    local state = zoneState[zoneId]

    if not state or not state.active or generation ~= state.generation then
        return
    end

    if npc:getStatus() == xi.status.DISAPPEAR then
        return
    end

    -- Re-arm before doing any work, so a thrown error costs one tick rather than every tick that
    -- would have followed it.
    npc:timer(TICK_MS, function(n)
        tick(n, zone, zoneId, generation)
    end)

    local ok, err = pcall(function()
        if npc:getLocalVar('bransonMode') == MODE_GREETING then
            greetingTick(npc, zone, zoneId)

            return
        end

        stuckTick(npc, zone, zoneId)

        -- One roll per approach, on the rising edge of the player entering greeting range.
        -- bransonNear latches while they are in range so lingering does not re-roll every tick, and
        -- clears when they leave, arming the next pass. The ten-minute gate is checked before the
        -- roll rather than after, so a failed roll costs nothing - he can still greet on a later
        -- pass once the window has elapsed.
        local player = nearestPlayer(npc, zone, GREET_RANGE)

        if not player then
            npc:setLocalVar('bransonNear', 0)

            return
        end

        if npc:getLocalVar('bransonNear') == 1 then
            return
        end

        npc:setLocalVar('bransonNear', 1)

        if canGreet(player) and math.random(100) <= GREET_SAY_CHANCE then
            startGreeting(npc, zone, zoneId, player)
        end
    end)

    if not ok then
        printf('[XI_LIFE] Branson error in %s: %s', zone:getName(), tostring(err))
    end
end

-----------------------------------
-- Spawning
-----------------------------------

local function spawnBranson(zone, zoneId)
    local rt        = runtime()
    local lifeState = rt and rt.stateOf(zoneId)
    local state     = zoneState[zoneId]

    if not lifeState or not lifeState.enabled or not state then
        return
    end

    if bransonIn(zone) then
        return
    end

    -- Same starting choice as an anonymous PNPC, zone lines included: turning up at a zone line and
    -- walking inwards is exactly what someone who just arrived looks like. Points with no slots
    -- fall back to a jittered position at the point itself.
    local startIdx   = math.random(#lifeState.points)
    local startPoint = lifeState.points[startIdx]
    local startSlot  = rt.chooseSlot(startPoint, nil, nil)
    local x, y, z    = rt.destinationOf(startPoint, startSlot)

    local npc = zone:insertDynamicEntity(
    {
        objtype  = xi.objType.NPC,
        name     = BRANSON_NAME,
        look     = xi.xiLife.appearance.buildLook(
        {
            race   = BRANSON_RACE,
            face   = BRANSON_FACE,
            head   = encode('head', MNK_ARTIFACT_MODEL),
            body   = encode('body', MNK_ARTIFACT_MODEL),
            hands  = encode('hands', MNK_ARTIFACT_MODEL),
            legs   = encode('legs', MNK_ARTIFACT_MODEL),
            feet   = encode('feet', MNK_ARTIFACT_MODEL),
            main   = 0,
            sub    = 0,
            ranged = 0,
        }),
        x        = x,
        y        = y,
        z        = z,
        rotation = math.random(0, 255),

        -- namevis 0, not VIS_ICON: the (I) icon marks a talkable NPC and gives the game away.
        namevis  = 0,
        releaseIdOnDisappear = true,

        onPathComplete = function(pnpc)
            arriveAt(pnpc, zone, zoneId)
        end,
    })

    if not npc then
        return
    end

    npc:initNpcAi()
    npc:setLocalVar('xiLifeBranson', 1)
    npc:setLocalVar('xiLifePoint', startIdx)
    npc:setLocalVar('xiLifeSlot', startSlot)
    npc:setLocalVar('bransonMode', MODE_TRAVEL)

    if startSlot > 0 then
        startPoint.taken[startSlot] = npc:getID()
    end

    if startPoint.kind ~= 'exit' then
        npc:lookAt(startPoint.x, startPoint.y, startPoint.z)
    end

    -- Bumping the generation retires the poll left over from a previous visit to this zone, so
    -- afterZoneIn can spawn him without ever ending up with two polls running at once.
    state.generation = (state.generation or 0) + 1
    state.watch      = nil

    tick(npc, zone, zoneId, state.generation)

    local trip = newTrip(npc)

    npc:timer(ARRIVAL_PAUSE_MS, function(n)
        if n:getLocalVar('bransonTrip') == trip then
            walkOn(n, zone, zoneId, false)
        end
    end)
end

local function despawnBranson(zone, zoneId)
    local rt    = runtime()
    local state = zoneState[zoneId]
    local npc   = bransonIn(zone)

    if npc then
        if rt then
            rt.releaseSlot(rt.stateOf(zoneId), npc)
        end

        npc:setStatus(xi.status.DISAPPEAR)
    end

    if state then
        state.watch = nil
    end
end

-----------------------------------
-- Hooks
--
-- InteractionGlobal.afterZoneIn and onZoneOut are called from luautils for every zone, with the
-- zone's own handler passed in as fallbackFn. Call super first and hand its result straight back:
-- these return values are consumed upstream, and calling super first also means xi_life's own hook
-- has run by the time this does, whichever order the two modules were loaded in.
-----------------------------------

m:addOverride('InteractionGlobal.afterZoneIn', function(player, fallbackFn)
    local result = super(player, fallbackFn)

    local zone = player:getZone()
    local rt   = runtime()

    if zone and rt then
        local zoneId = zone:getID()

        -- Idempotent and cached, so it does not matter whether xi_life's hook has already done it.
        local lifeState = rt.prepareZone(zone, zoneId)

        zoneState[zoneId] = zoneState[zoneId] or {}

        local pid = player:getID()

        if not lifeState.enabled then
            -- Not a city he lives in, but it is still somewhere the player now stands: record it so
            -- that walking back into a city he might be in counts as a genuine fresh visit.
            lastZone[pid] = zoneId
            zoneState[zoneId].active = false
        elseif player:inMogHouse() then
            -- A Mog House is a zone change back into the same zone, leaving the player standing in
            -- the street server-side. Anything spawned now would be pushed to their client and walk
            -- through the room, so take him away until they come back out. His presence decision and
            -- lastZone are both left untouched, so stepping back out reuses the answer rather than
            -- rolling afresh - he does not vanish for a Mog House trip.
            zoneState[zoneId].active = false
            despawnBranson(zone, zoneId)
        else
            -- Roll his presence once per genuine visit and remember it on the zone. Deciding here
            -- rather than inside spawnBranson keeps the answer stable across the many ticks of one
            -- visit and, crucially, across a Mog House trip, which comes back through this same
            -- branch with the zone unchanged.
            if lastZone[pid] ~= zoneId then
                zoneState[zoneId].present = math.random(100) <= BRANSON_SPAWN_CHANCE
            end

            lastZone[pid] = zoneId
            zoneState[zoneId].active = true

            if zoneState[zoneId].present then
                spawnBranson(zone, zoneId)
            end
        end
    end

    return result
end)

m:addOverride('InteractionGlobal.onZoneOut', function(player, fallbackFn)
    local result = super(player, fallbackFn)

    local zone = player:getZone()

    if zone then
        local zoneId = zone:getID()
        local state  = zoneState[zoneId]

        -- Only tear down once the last player is gone. getPlayers still includes the player on
        -- their way out at this point, so one remaining means the zone is about to be empty.
        if state and #zone:getPlayers() <= 1 then
            state.active = false
            despawnBranson(zone, zoneId)
        end
    end

    return result
end)

return m
