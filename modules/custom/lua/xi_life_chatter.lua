-----------------------------------
-- XI_LIFE: PlayerNPC zone chatter
--
-- Hand-written content, not generated - this is the one part of the system that is writing rather
-- than data extraction, so it is kept out of the generators' way.
--
-- Lines are templates with {tokens} filled from the pools below, so a small file produces a very
-- large number of distinct messages. Each line declares the channel it belongs on:
--
--   shout - zone-wide, the way a real player broadcasts. Party seeking, trade, questions.
--   say   - local, only heard if the speaker is near the player. Idle remarks, muttering.
--
-- Tokens available: {zone} {job} {job2} {item} {price} {number} {name} {time}
-----------------------------------
xi = xi or {}
xi.xiLife = xi.xiLife or {}

local chatter = {}

-----------------------------------
-- Token pools
--
-- Zone names are spelled the way a player would type them, not the way the database stores them,
-- and deliberately stick to the classic levelling and camp zones people actually shout about.
-----------------------------------

chatter.tokens =
{
    zone =
    {
        'Valkurm', 'the Dunes', 'Qufim', 'Jugner', 'Buburimu', 'the Highlands',
        'Yuhtunga', 'Yhoator', 'Garlaige', 'Crawlers Nest', 'the Boyahda Tree',
        'Kuftal', 'Gustaberg', 'Konschtat', 'Tahrongi', 'La Theine', 'Ronfaure',
        'Sauromugue', 'Rolanberry', 'Batallia', 'Beaucedine', 'Xarcabard',
        'the Labyrinth', 'Castle Oztroja', 'Davoi', 'Eldieme', 'Gusgen',
        'Ordelles', 'the Maze', 'Altepa', 'Cape Terigan', 'Bibiki Bay',
    },

    job =
    {
        'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK',
        'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN',
    },

    item =
    {
        'a Scorpion Harness', 'Leaping Boots', 'a Peacock Charm', 'Sniper Rings',
        'an Astral Ring', 'a Fire Sword', 'Emperor Hairpin', 'a Noble\'s Tunic',
        'Rostrum Pumps', 'a Kraken Club', 'Federation Aketon', 'a Woodville\'s Axe',
        'silent oils', 'prism powders', 'echo drops', 'a stack of shihei',
        'meat mithkabobs', 'sole sushi', 'juices', 'a Rabbit Charm',
        'a Beetle Harness', 'Traveler\'s Mantle', 'a Balance Ring',
    },

    price =
    {
        '5k', '8k', '12k', '15k', '20k', '30k', '45k', '60k', '80k',
        '100k', '150k', '200k', '400k', 'half a mil',
    },

    number = { '2', '3', '4', '5' },
}

-----------------------------------
-- Lines
-----------------------------------

chatter.lines =
{
    -- Party seeking and travel
    { channel = 'shout', text = 'anyone lfg {zone}?' },
    { channel = 'shout', text = '{job} lfp, will go anywhere' },
    { channel = 'shout', text = 'party in {zone} needs {number} more' },
    { channel = 'shout', text = 'looking for {job} or {job2} for {zone}' },
    { channel = 'shout', text = 'need {number} for {zone}, have tank and healer' },
    { channel = 'shout', text = 'heading to {zone} in 5 if anyone wants in' },
    { channel = 'shout', text = 'any {job} around? we need one for {zone}' },
    { channel = 'shout', text = 'lf1m {zone}, {job} preferred' },
    { channel = 'shout', text = 'anyone going to {zone}? need a run out there' },
    { channel = 'shout', text = 'party forming for {zone}, msg me' },
    { channel = 'shout', text = 'can anyone raise in {zone}? died at camp' },
    { channel = 'shout', text = 'need a warp please, anywhere is fine' },
    { channel = 'shout', text = 'anyone got a teleport? paying' },

    -- Trade
    { channel = 'shout', text = 'wts {item}, {price}, pm me' },
    { channel = 'shout', text = 'wtb {item}, paying {price}' },
    { channel = 'shout', text = 'selling {item} cheap, {price}' },
    { channel = 'shout', text = 'anyone selling {item}? ah is empty' },
    { channel = 'shout', text = 'wts {item} - taking offers' },
    { channel = 'shout', text = 'looking for a synth, will supply mats' },

    -- Auction house grumbling
    { channel = 'say',   text = '{price} for {item}? no thanks' },
    { channel = 'say',   text = 'ah prices are ridiculous today' },
    { channel = 'say',   text = 'someone keeps undercutting me' },
    { channel = 'say',   text = 'been trying to sell {item} for three days' },
    { channel = 'say',   text = 'finally sold. {price}.' },
    { channel = 'say',   text = 'nothing on the ah again' },
    { channel = 'shout', text = 'who is buying every {item} off the ah?' },

    -- Time of day and weather
    { channel = 'say',   text = 'getting dark. i should log soon' },
    { channel = 'say',   text = 'is it {time} already?' },
    { channel = 'say',   text = 'been on since dawn' },
    { channel = 'say',   text = 'one more level then bed' },
    { channel = 'say',   text = 'i said one more level an hour ago' },

    -- Music and scenery
    { channel = 'say',   text = 'i never get tired of this music' },
    { channel = 'say',   text = 'this theme is the best one in the game' },
    { channel = 'say',   text = 'could listen to this all day' },
    { channel = 'say',   text = 'love it here' },

    -- Idle life
    { channel = 'say',   text = 'brb, afk a sec' },
    { channel = 'say',   text = 'back' },
    { channel = 'say',   text = 'inventory is full again' },
    { channel = 'say',   text = 'need to clear my mog house out' },
    { channel = 'say',   text = 'anyone know where the {job} guild is?' },
    { channel = 'say',   text = 'i have been running in circles for ten minutes' },
    { channel = 'say',   text = 'finally hit {number}0' },
    { channel = 'say',   text = 'my subjob is so far behind' },
    { channel = 'say',   text = 'that took way longer than it should have' },
    { channel = 'shout', text = 'congrats!' },
    { channel = 'shout', text = 'grats :)' },
    { channel = 'say',   text = 'gil is so tight right now' },
    { channel = 'say',   text = 'i should really level {job}' },
    { channel = 'say',   text = 'chocobo licence finally paid off' },
}

xi.xiLife.chatter = chatter

return chatter
