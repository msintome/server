-----------------------------------
-- Trust: Shantotto II
-----------------------------------
---@type TSpellTrust
local spellObject = {}

spellObject.onMagicCastingCheck = function(caster, target, spell)
    return xi.trust.canCast(caster, spell, xi.magic.spell.SHANTOTTO)
end

spellObject.onSpellCast = function(caster, target, spell)
    return xi.trust.spawn(caster, spell)
end

spellObject.onMobSpawn = function(mob)
    xi.trust.message(mob, xi.trust.messageOffset.SPAWN)

    -- Engage delay tracking: gives Val ~3 seconds to build enmity before
    -- Shantotto II starts nuking. Without this she rips hate immediately
    -- and dies to the mob turning on her.
    mob:addListener('ENGAGE', 'SHANTOTTO_II_ENGAGE', function(mobArg, target)
        mobArg:setLocalVar('[Gambit]EngageTime', GetSystemTime())
        mobArg:setLocalVar('[Gambit]EngageElapsed', 0)
    end)

    mob:addListener('DISENGAGE', 'SHANTOTTO_II_DISENGAGE', function(mobArg)
        mobArg:setLocalVar('[Gambit]EngageTime', 0)
        mobArg:setLocalVar('[Gambit]EngageElapsed', 0)
    end)

    mob:addListener('COMBAT_TICK', 'SHANTOTTO_II_COMBAT_TICK', function(mobArg)
        local engageTime = mobArg:getLocalVar('[Gambit]EngageTime')
        if engageTime > 0 then
            mobArg:setLocalVar('[Gambit]EngageElapsed', GetSystemTime() - engageTime)
        end
    end)

    -- Offensive gambits gated on 3-second engage delay
	mob:addGambit(ai.t.TARGET,
		{ { ai.c.MB_AVAILABLE,     0 }, { ai.c.LOCALVAR_GTE, 3 }, { ai.c.NOT_HAS_TOP_ENMITY, 0 } },
		{ ai.r.MA, ai.s.MB_ELEMENT, xi.magic.spellFamily.NONE })

	mob:addGambit(ai.t.TARGET,
		{ { ai.c.NOT_SC_AVAILABLE, 0 }, { ai.c.LOCALVAR_GTE, 3 }, { ai.c.NOT_HAS_TOP_ENMITY, 0 } },
		{ ai.r.MA, ai.s.HIGHEST,    xi.magic.spellFamily.NONE }, 45)

    local trustLevel  = mob:getMainLvl()
    local power       = trustLevel / 5
    local spellDamage = trustLevel * math.floor((trustLevel + 1) / 10)
	
    mob:addMod(xi.mod.MATT, power)
    mob:addMod(xi.mod.MACC, power)
    mob:addMod(xi.mod.HASTE_MAGIC, 1000) -- 10% Haste (Magic)
    mob:addMod(xi.mod.MAGIC_DAMAGE, spellDamage)
    mob:addMod(xi.mod.ACC, 1000)
	mob:addMod(xi.mod.ENMITY, -50)
	
    mob:setMobSkillAttack(1163)
    mob:setTrustTPSkillSettings(ai.tp.CLOSER_UNTIL_TP, ai.s.HIGHEST, 3000)

    mob:addListener('WEAPONSKILL_USE', 'SHANTOTTO_II_WEAPONSKILL_USE', function(mobArg, target, skill, tp, action, damage)
        if skill:getID() == 3740 then -- Final Exam
            xi.trust.message(mobArg, xi.trust.messageOffset.SPECIAL_MOVE_1)
        end
    end)

    mob:addListener('MAGIC_USE', 'SHANTOTTO_II_MAGIC', function(mobArg, target, spell, action)
        if math.random(1, 100) <= 33 then
            xi.trust.message(mobArg, xi.trust.messageOffset.SPECIAL_MOVE_2)
        end
    end)

    mob:setMobMod(xi.mobMod.TRUST_DISTANCE, xi.trust.movementType.NO_MOVE)
end

spellObject.onMobDespawn = function(mob)
    xi.trust.message(mob, xi.trust.messageOffset.DESPAWN)
end

spellObject.onMobDeath = function(mob)
    xi.trust.message(mob, xi.trust.messageOffset.DEATH)
end

return spellObject
