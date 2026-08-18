-----------------------------------
-- XI_LIFE PlayerNPC points added in game with !addnpcpoi
--
-- Written by the command; safe to hand-edit or prune. Not touched by
-- tools/xi_life/generate_pois.py, which owns xi_life_pois.lua instead.
-----------------------------------
xi = xi or {}
xi.xiLife = xi.xiLife or {}

xi.xiLife.customPois =
{
    [241] =
    {
        { name = 'Fhelm_Jobeizat', kind = 'wander', x = 89.049, y = -4.108, z = -46.195 },
        { name = 'Teldro-Kesdrodo', kind = 'wander', x = 96.900, y = -5.230, z = -25.380 },
        { name = 'Phub_Bayzarahn', kind = 'wander', x = -7.853, y = 2.750, z = -67.147 },
        { name = 'Ibwam', kind = 'wander', x = -25.655, y = 2.749, z = -60.651 },
        { name = 'Chihpi_Kapirapehro', kind = 'wander', x = 2.282, y = -4.000, z = -146.234 },
        { name = 'Ephemeral_Moogle_Bone', kind = 'wander', x = -10.500, y = -5.250, z = -143.400 },
        { name = 'Meh_Kotomaihro', kind = 'exit', x = -78.366, y = 2.087, z = -72.934 },
    },

    [235] =
    {
        { name = 'Tancredi', kind = 'wander', x = -218.305, y = -7.999, z = 34.949 },
        { name = 'Synergy_Engineer', kind = 'wander', x = -266.000, y = -12.500, z = -33.000 },
        { name = 'Matthias', kind = 'wander', x = -114.101, y = -4.292, z = -107.276 },
        { name = 'Karine', kind = 'wander', x = -220.746, y = -6.051, z = -93.698 },
        { name = 'Oggodett', kind = 'wander', x = -186.673, y = -6.051, z = -108.654 },
    },

    [250] =
    {
        { name = 'Nomad_Moogle', kind = 'wander', x = 43.518, y = -11.000, z = -147.674 },
        { name = 'Nomad_Moogle', kind = 'wander', x = 15.977, y = -8.000, z = -82.779 },
        { name = 'Survival_Guide', kind = 'wander', x = -40.000, y = -10.000, z = -93.000 },
        { name = 'Kobhi_Sarhigamya', kind = 'exit', x = -115.290, y = -11.000, z = -22.609 },
        { name = 'Bhoyu_Halpatacco', kind = 'exit', x = -14.906, y = -5.000, z = -14.332 },
    },

    [87] =
    {
        { name = 'Magdalena', kind = 'wander', x = -281.566, y = -11.999, z = -41.420 },
        { name = 'Maximilian_Berger', kind = 'wander', x = -357.516, y = -10.002, z = -177.571 },
        { name = 'Survival_Guide', kind = 'wander', x = -247.000, y = 0.000, z = 95.000 },
        { name = 'Hieronymus', kind = 'wander', x = -325.702, y = -12.601, z = -51.150 },
    },

    [245] =
    {
        { name = 'Boisterous_Jackal', kind = 'wander', x = -26.250, y = 0.000, z = -16.400 },
        { name = 'Nantoto', kind = 'wander', x = -46.399, y = 0.000, z = -49.532 },
        { name = 'Shashan-Mishan', kind = 'wander', x = -113.449, y = 0.000, z = -167.358 },
        { name = 'Amhu_Sabaroleka', kind = 'wander', x = -22.153, y = -6.100, z = -87.616 },
        { name = 'Sweepstox', kind = 'wander', x = 14.700, y = 0.000, z = 8.480 },
    },

    [231] =
    {
        { name = 'Fantarviont', kind = 'wander', x = -138.804, y = 0.000, z = 106.240 },
        { name = 'Kuu_Mohzolhi', kind = 'wander', x = -123.137, y = -0.199, z = 80.462 },
        { name = 'Justi', kind = 'wander', x = -97.112, y = -2.261, z = 39.073 },
        { name = 'Maloquedil', kind = 'wander', x = 35.118, y = -0.199, z = 60.354 },
    },

    [239] =
    {
        { name = 'Augu-Maugu', kind = 'wander', x = -26.173, y = -2.455, z = -58.818 },
        { name = 'Luuh_Koplehn', kind = 'wander', x = -93.910, y = -5.097, z = 130.064 },
        { name = 'Gerun-Garun', kind = 'wander', x = 7.267, y = -7.620, z = 256.316 },
        { name = 'Finene', kind = 'wander', x = 46.371, y = -7.500, z = 216.384 },
        { name = 'Florencia', kind = 'wander', x = 105.183, y = -10.853, z = 158.458 },
    },

    [230] =
    {
        { name = 'Phamelise', kind = 'wander', x = 63.980, y = 2.000, z = -8.163 },
        { name = 'Amutiyaal', kind = 'wander', x = 116.512, y = 0.000, z = 84.679 },
        { name = 'Corua', kind = 'wander', x = -64.239, y = 1.999, z = -8.665 },
        { name = 'Synergy_Engineer', kind = 'wander', x = -197.500, y = -1.500, z = 45.155 },
    },

    [247] =
    {
        { name = 'Survival_Guide', kind = 'exit', x = -3.500, y = -2.502, z = -95.000 },
        { name = 'Rahi_Fohlatti', kind = 'wander', x = -14.624, y = 7.868, z = -10.363 },
        { name = 'Nomad_Moogle', kind = 'exit', x = -4.166, y = 8.033, z = 12.476 },
        { name = 'Brave_Wolf', kind = 'wander', x = -10.026, y = 7.999, z = 81.816 },
    },

    [248] =
    {
        { name = 'Chutarmire', kind = 'wander', x = -5.200, y = -6.558, z = 6.782 },
        { name = 'Falgima', kind = 'wander', x = 6.300, y = -6.558, z = 4.582 },
        { name = 'Thunder_Hawk', kind = 'wander', x = -60.431, y = -10.558, z = 4.840 },
        { name = 'Manfried', kind = 'wander', x = -36.073, y = -2.558, z = -5.373 },
        { name = 'Lucia', kind = 'wander', x = 30.552, y = -2.558, z = -30.023 },
        { name = 'Explorer_Moogle', kind = 'wander', x = 10.410, y = -14.558, z = 62.831 },
    },

    [240] =
    {
        { name = 'Martin', kind = 'wander', x = 202.824, y = -6.249, z = 126.393 },
        { name = 'Synergy_Engineer', kind = 'wander', x = 13.000, y = -4.500, z = 122.000 },
        { name = 'Lebondur', kind = 'wander', x = -79.849, y = -4.999, z = 145.154 },
        { name = 'HomePoint#1', kind = 'exit', x = -188.000, y = -4.000, z = 101.000 },
    },

    [249] =
    {
        { name = 'Gorpa-Masorpa', kind = 'wander', x = -27.584, y = -15.998, z = 52.565 },
        { name = 'Maximin', kind = 'wander', x = -0.860, y = -16.003, z = 73.526 },
        { name = 'Porter_Moogle', kind = 'wander', x = 24.000, y = -16.000, z = 60.000 },
        { name = 'Amalanbraux', kind = 'wander', x = 36.563, y = -16.047, z = 84.548 },
        { name = 'Felisa', kind = 'wander', x = 45.441, y = -7.999, z = 39.381 },
        { name = 'Pekuku', kind = 'wander', x = 4.701, y = -7.857, z = 39.627 },
        { name = 'Orlando', kind = 'wander', x = -37.268, y = -8.000, z = 58.047 },
        { name = 'Panoru-Kanoru', kind = 'wander', x = 5.241, y = -4.035, z = 93.891 },
    },

}

return xi.xiLife.customPois
