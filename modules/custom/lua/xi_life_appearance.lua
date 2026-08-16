-----------------------------------
-- XI_LIFE: PlayerNPC appearance and names
--
-- Everything needed to make one dynamic NPC look and read like a player character. Lifted out of
-- Upper_Jeuno/Zone.lua when the population system was generalised to every city zone.
--
-- Returns a table so the file is valid whether it is require()d or picked up by the module loader.
-----------------------------------
require('modules/custom/lua/xi_life_gear')
-----------------------------------
xi = xi or {}
xi.xiLife = xi.xiLife or {}

local appearance = {}

-- The client renders at most 15 characters; PacketNameLength in common/utils.h is 16 with the
-- terminator. Anything longer is re-rolled rather than truncated, since a clipped name reads as
-- a typo on the nameplate.
local MAX_NAME_LENGTH = 15

local function pick(t)
    return t[math.random(#t)]
end

-----------------------------------
-- Equipment
--
-- Models come from xi_life_gear.lua, generated out of item_equipment: a few hundred options per
-- slot rather than the handful that were hand-picked, plus the fifteen job Artifact sets.
--
-- look_t packs each slot as (slotIndex << 12) | model, so a raw model ID from the database has to
-- be shifted into the slot it is filling. See look_t in common/mmo.h.
--
-- Main and sub stay empty (model 0): townspeople walking around with a weapon drawn in each hand
-- looks wrong. A slung ranged weapon reads fine.
-----------------------------------

local slotIndex =
{
    head   = 1,
    body   = 2,
    hands  = 3,
    legs   = 4,
    feet   = 5,
    main   = 6,
    sub    = 7,
    ranged = 8,
}

local armourSlots = { 'head', 'body', 'hands', 'legs', 'feet' }

-- Roughly a third of any crowd in a real city is wearing a recognisable job set, which is what
-- sells the illusion. The rest are in mixed gear.
local ARTIFACT_CHANCE = 33

local rangedPool = { 0, 0x8035 }

local function encode(slot, model)
    if model == 0 then
        return 0
    end

    return (slotIndex[slot] * 0x1000) + model
end

-- Every piece of an Artifact set shares one model ID, so a complete set is that number applied
-- across all five armour slots.
local function artifactGear()
    local sets = xi.xiLife.gear and xi.xiLife.gear.artifact

    if not sets or #sets == 0 then
        return nil
    end

    local chosen = pick(sets)
    local gear   = { job = chosen.job }

    for _, slot in ipairs(armourSlots) do
        gear[slot] = encode(slot, chosen.model)
    end

    return gear
end

local function mixedGear()
    local slots = xi.xiLife.gear and xi.xiLife.gear.slots
    local gear  = {}

    for _, slot in ipairs(armourSlots) do
        if slots and slots[slot] and #slots[slot] > 0 then
            gear[slot] = encode(slot, pick(slots[slot]))
        else
            gear[slot] = 0
        end
    end

    return gear
end

-----------------------------------
-- Names
--
-- Built from syllable tables rather than a fixed list, so a busy city does not visibly repeat.
-- The style follows the race that was rolled, matching retail naming: Tarutaru names double or
-- hyphenate their syllables (Shantotto, Ajido-Marujido), Galka names are short and hard-consonant
-- (Zeid, Gumbah), Mithra names lean on soft syllables and vowel endings (Perih, Nanaa), and
-- Hume/Elvaan names are the general fantasy mix.
-----------------------------------

local nameParts =
{
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

    taru =
    {
        head = {
            'Aji', 'Chal', 'Kupi', 'Mora', 'Nana', 'Piku', 'Robo', 'Shan', 'Taru', 'Toto',
            'Wawa', 'Yoyo', 'Zuzu', 'Chomo', 'Fufu', 'Gigi', 'Hoho', 'Kiki', 'Momo', 'Pipi',
        },
        tail = { 'do', 'to', 'ru', 'ko', 'mi', 'na', 'pa', 'lo', 'ho', 'ma' },
    },

    galka =
    {
        head = {
            'Ba', 'Ber', 'Dor', 'Grim', 'Gum', 'Hor', 'Kro', 'Mog', 'Nag', 'Rao',
            'Rok', 'Thok', 'Ug', 'Vor', 'Wer', 'Zeid', 'Zog', 'Dur', 'Gral', 'Muk',
        },
        tail = { 'bah', 'grimm', 'dak', 'thar', 'gor', 'nak', 'rum', 'dun', 'ok', 'ei' },
    },

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

-----------------------------------
-- Public
-----------------------------------

appearance.randomName = function(race)
    for _ = 1, 10 do
        local name = buildName(race)

        if #name >= 3 and #name <= MAX_NAME_LENGTH then
            return name
        end
    end

    return 'Wanderer'
end

-- Encodes a look_t as the hex string insertDynamicEntity expects: size and race/face, then the
-- eight equipment model IDs. See look_t in common/mmo.h.
appearance.buildLook = function(p)
    local function u16(v)
        return string.format('%02x%02x', v % 256, math.floor(v / 256) % 256)
    end

    return u16(1)
        .. u16((p.face or 0) + (p.race or 1) * 256)
        .. u16(p.head or 0) .. u16(p.body or 0) .. u16(p.hands or 0)
        .. u16(p.legs or 0) .. u16(p.feet or 0)
        .. u16(p.main or 0) .. u16(p.sub or 0) .. u16(p.ranged or 0)
end

-- One complete random character: race, face, gear and a name that suits the race. `job` is set
-- only for the ones wearing a full Artifact set, so chatter can have them talk like that job.
appearance.randomCharacter = function()
    local race = math.random(xi.race.HUME_M, xi.race.GALKA)
    local gear = nil

    if math.random(100) <= ARTIFACT_CHANCE then
        gear = artifactGear()
    end

    if not gear then
        gear = mixedGear()
    end

    return
    {
        race = race,
        job  = gear.job,
        name = appearance.randomName(race),
        look = appearance.buildLook(
        {
            race   = race,
            face   = math.random(0, 7),
            head   = gear.head,
            body   = gear.body,
            hands  = gear.hands,
            legs   = gear.legs,
            feet   = gear.feet,
            main   = 0,
            sub    = 0,
            ranged = pick(rangedPool),
        }),
    }
end

xi.xiLife.appearance = appearance

return appearance
