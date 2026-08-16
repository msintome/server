-----------------------------------
-- XI_LIFE PlayerNPC points of interest
--
-- GENERATED FILE - do not edit by hand.
-- Regenerate with: python -m tools.xi_life.generate_pois
--
-- Positions are candidates only. The navmesh cannot be consulted from the generator, so
-- the runtime validates each point with zone:isNavigablePoint before using it.
-----------------------------------
xi = xi or {}
xi.xiLife = xi.xiLife or {}

xi.xiLife.pois =
{
    [26] = -- Tavnazian_Safehold
    {
        population = 10,
        points =
        {
            { name = 'Eliot', kind = 'auction', x = -115.348, y = -27.250, z = -42.060 },
            { name = 'Ferocious_Artisan', kind = 'auction', x = -109.192, y = -26.812, z = -51.717 },
            { name = 'Senvaleget', kind = 'auction', x = -101.932, y = -27.250, z = -58.968 },
            { name = 'Lufaise_Meadows exit', kind = 'exit', x = 9.902, y = -31.566, z = 157.162 },
            { name = 'Lufaise_Meadows exit', kind = 'exit', x = 16.108, y = -27.796, z = 116.194 },
            { name = 'Misareaux_Coast exit', kind = 'exit', x = -48.435, y = -34.162, z = 159.972 },
            { name = 'Misareaux_Coast exit', kind = 'exit', x = -39.224, y = -31.364, z = 117.016 },
            { name = 'Phomiuna_Aqueducts exit', kind = 'exit', x = 27.989, y = -16.337, z = 57.053 },
            { name = 'Sealions_Den exit', kind = 'exit', x = -0.034, y = -11.218, z = -41.987 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -1.250, y = -27.907, z = 107.425 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 14.000, y = -10.000, z = -5.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = 73.590, y = -36.150, z = 38.870 },
        },
    },

    [48] = -- Al_Zahbi
    {
        population = 10,
        points =
        {
            { name = 'Goyuyu', kind = 'auction', x = -33.412, y = -0.398, z = -121.245 },
            { name = 'Sojan-Tamjan', kind = 'auction', x = -41.544, y = -0.398, z = -113.049 },
            { name = 'Yando-Memondo', kind = 'auction', x = -37.324, y = -0.401, z = -117.343 },
            { name = 'Aht_Urhgan_Whitegate exit', kind = 'exit', x = 122.109, y = -5.160, z = 40.005 },
            { name = 'Bhaflau_Thickets exit', kind = 'exit', x = -68.008, y = -1.091, z = 120.009 },
            { name = 'Mog House door', kind = 'exit', x = 40.000, y = -3.764, z = -74.000 },
            { name = 'Wajaom_Woodlands exit', kind = 'exit', x = -120.190, y = -1.369, z = 67.981 },
        },
    },

    [50] = -- Aht_Urhgan_Whitegate
    {
        population = 14,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = -137.709, y = -6.999, z = 73.858 },
            { name = 'Auction_Counter', kind = 'auction', x = -137.817, y = -6.999, z = 79.161 },
            { name = 'Auction_Counter', kind = 'auction', x = -137.744, y = -6.999, z = 84.582 },
            { name = 'Al_Zahbi exit', kind = 'exit', x = -158.102, y = 0.000, z = 0.005 },
            { name = 'Mog House door', kind = 'exit', x = -114.000, y = -3.333, z = -80.000 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -21.130, y = 0.000, z = -20.944 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 130.000, y = 0.000, z = -16.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = -108.000, y = -6.000, z = 108.000 },
            { name = 'HomePoint#4', kind = 'homepoint', x = -99.000, y = 0.000, z = -68.000 },
        },
    },

    [80] = -- Southern_San_dOria_[S]
    {
        population = 11,
        points =
        {
            { name = 'East_Ronfaure_[S] exit', kind = 'exit', x = 113.458, y = -4.079, z = -57.351 },
            { name = 'Mog House door', kind = 'exit', x = 164.933, y = -5.547, z = 164.792 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -85.468, y = 1.000, z = -66.454 },
        },
    },

    [87] = -- Bastok_Markets_[S]
    {
        population = 10,
        points =
        {
            { name = 'Mog House door', kind = 'exit', x = -150.750, y = -6.781, z = -30.329 },
            { name = 'Mog House door', kind = 'exit', x = -150.750, y = -6.766, z = 29.920 },
            { name = 'North_Gustaberg_[S] exit', kind = 'exit', x = -233.956, y = -4.231, z = 105.000 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -293.048, y = -10.000, z = -102.558 },
        },
    },

    [94] = -- Windurst_Waters_[S]
    {
        population = 10,
        points =
        {
            { name = 'Mog House door', kind = 'exit', x = 159.934, y = -8.386, z = -64.086 },
            { name = 'West_Sarutabaruta_[S] exit', kind = 'exit', x = -40.194, y = -7.871, z = 248.809 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -32.022, y = -5.000, z = 131.741 },
        },
    },

    [230] = -- Southern_San_dOria
    {
        population = 19,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = 8.929, y = 1.699, z = -31.030 },
            { name = 'Auction_Counter', kind = 'auction', x = -8.852, y = 1.699, z = -30.902 },
            { name = 'Auction_Counter', kind = 'auction', x = 2.197, y = -3.300, z = -39.870 },
            { name = 'Auction_Counter', kind = 'auction', x = -3.949, y = -3.300, z = -39.436 },
            { name = 'East_Ronfaure exit', kind = 'exit', x = 113.458, y = -4.079, z = -57.351 },
            { name = 'Mog House door', kind = 'exit', x = 164.933, y = -5.547, z = 164.792 },
            { name = 'Northern_San_dOria exit', kind = 'exit', x = 0.013, y = -8.469, z = 57.965 },
            { name = 'West_Ronfaure exit', kind = 'exit', x = -113.372, y = -4.075, z = -57.418 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -85.468, y = 1.000, z = -66.454 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 45.000, y = 2.000, z = -35.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = 140.000, y = -2.000, z = 123.000 },
            { name = 'HomePoint#4', kind = 'homepoint', x = -165.000, y = -1.000, z = 11.000 },
        },
    },

    [231] = -- Northern_San_dOria
    {
        population = 15,
        points =
        {
            { name = 'Carpenters_Landing exit', kind = 'exit', x = -123.566, y = 9.966, z = 192.841 },
            { name = 'Mog House door', kind = 'exit', x = 134.995, y = -7.068, z = -8.439 },
            { name = 'Port_San_dOria exit', kind = 'exit', x = -123.510, y = 8.289, z = 270.516 },
            { name = 'Southern_San_dOria exit', kind = 'exit', x = -0.107, y = -7.068, z = -36.133 },
            { name = 'West_Ronfaure exit', kind = 'exit', x = -252.158, y = 1.663, z = 43.913 },
            { name = 'West_Ronfaure exit', kind = 'exit', x = -238.702, y = -9.433, z = 105.961 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -178.101, y = 4.000, z = 71.279 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 10.000, y = -0.200, z = 95.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = 70.000, y = -0.200, z = 10.000 },
            { name = 'HomePoint#4', kind = 'homepoint', x = -133.000, y = 12.000, z = 195.000 },
        },
    },

    [232] = -- Port_San_dOria
    {
        population = 10,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = 2.961, y = -9.300, z = -151.221 },
            { name = 'Auction_Counter', kind = 'auction', x = -14.965, y = -9.300, z = -151.237 },
            { name = 'Auction_Counter', kind = 'auction', x = -10.014, y = -13.300, z = -159.593 },
            { name = 'Auction_Counter', kind = 'auction', x = -3.939, y = -13.300, z = -159.582 },
            { name = 'Mog House door', kind = 'exit', x = 83.260, y = -19.486, z = -139.282 },
            { name = 'Northern_San_dOria exit', kind = 'exit', x = -111.802, y = -11.876, z = -136.498 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -38.000, y = -4.000, z = -63.000 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 48.000, y = -12.000, z = -105.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = -6.000, y = -13.000, z = -150.000 },
        },
    },

    [233] = -- Chateau_dOraguille
    {
        population = 6,
        points =
        {
            { name = 'Bostaunieux_Oubliette exit', kind = 'exit', x = 12.495, y = 6.974, z = 24.047 },
        },
    },

    [234] = -- Bastok_Mines
    {
        population = 14,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = -15.942, y = -4.089, z = -48.424 },
            { name = 'Auction_Counter', kind = 'auction', x = -8.187, y = -4.089, z = -50.497 },
            { name = 'Auction_Counter', kind = 'auction', x = -0.022, y = -4.089, z = -51.556 },
            { name = 'Auction_Counter', kind = 'auction', x = 7.960, y = -4.089, z = -50.596 },
            { name = 'Auction_Counter', kind = 'auction', x = 15.482, y = -4.089, z = -48.730 },
            { name = 'Bastok_Markets exit', kind = 'exit', x = -104.080, y = 8.101, z = 84.578 },
            { name = 'Mog House door', kind = 'exit', x = 121.831, y = -3.367, z = -71.955 },
            { name = 'South_Gustaberg exit', kind = 'exit', x = -15.961, y = -5.475, z = -136.018 },
            { name = 'Zeruhn_Mines exit', kind = 'exit', x = -196.032, y = -10.599, z = -21.883 },
            { name = 'HomePoint#1', kind = 'homepoint', x = 39.189, y = 0.000, z = -42.618 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 118.000, y = 1.000, z = -58.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = 87.000, y = 7.000, z = 1.000 },
        },
    },

    [235] = -- Bastok_Markets
    {
        population = 15,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = -333.986, y = -15.301, z = -52.231 },
            { name = 'Auction_Counter', kind = 'auction', x = -331.874, y = -15.301, z = -59.848 },
            { name = 'Auction_Counter', kind = 'auction', x = -330.925, y = -15.301, z = -67.956 },
            { name = 'Auction_Counter', kind = 'auction', x = -331.981, y = -15.001, z = -76.197 },
            { name = 'Auction_Counter', kind = 'auction', x = -333.971, y = -15.301, z = -83.841 },
            { name = 'Bastok_Mines exit', kind = 'exit', x = -202.243, y = 0.332, z = -197.784 },
            { name = 'Metalworks exit', kind = 'exit', x = -211.990, y = -13.216, z = -0.046 },
            { name = 'Mog House door', kind = 'exit', x = -146.168, y = -6.781, z = -30.329 },
            { name = 'Mog House door', kind = 'exit', x = -146.160, y = -6.766, z = 29.920 },
            { name = 'Port_Bastok exit', kind = 'exit', x = -233.956, y = -1.943, z = 92.340 },
            { name = 'South_Gustaberg exit', kind = 'exit', x = -365.697, y = -13.544, z = -185.638 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -344.000, y = -10.000, z = -155.000 },
            { name = 'HomePoint#2', kind = 'homepoint', x = -328.000, y = -12.000, z = -33.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = -189.000, y = -8.000, z = 26.000 },
            { name = 'HomePoint#4', kind = 'homepoint', x = -191.000, y = -6.000, z = -69.000 },
        },
    },

    [236] = -- Port_Bastok
    {
        population = 14,
        points =
        {
            { name = 'Bastok_Markets exit', kind = 'exit', x = -193.452, y = 0.969, z = -84.046 },
            { name = 'Mog House door', kind = 'exit', x = 59.970, y = 5.919, z = -252.825 },
            { name = 'North_Gustaberg exit', kind = 'exit', x = 150.300, y = 5.934, z = 6.330 },
            { name = 'HomePoint#1', kind = 'homepoint', x = 126.000, y = 8.500, z = 8.000 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 40.000, y = 8.500, z = -238.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = -127.000, y = -6.000, z = 10.000 },
        },
    },

    [237] = -- Metalworks
    {
        population = 10,
        points =
        {
            { name = 'Bastok_Markets exit', kind = 'exit', x = -6.175, y = -2.966, z = -0.008 },
            { name = 'HomePoint#1', kind = 'homepoint', x = 45.000, y = -14.000, z = -19.000 },
            { name = 'HomePoint#2', kind = 'homepoint', x = -78.000, y = 2.000, z = 3.000 },
        },
    },

    [238] = -- Windurst_Waters
    {
        population = 17,
        points =
        {
            { name = 'Mog House door', kind = 'exit', x = 159.934, y = -8.386, z = -64.086 },
            { name = 'Port_Windurst exit', kind = 'exit', x = -59.591, y = -7.115, z = -209.045 },
            { name = 'West_Sarutabaruta exit', kind = 'exit', x = -40.194, y = -7.871, z = 248.809 },
            { name = 'Windurst_Walls exit', kind = 'exit', x = 160.108, y = -7.303, z = 60.360 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -32.022, y = -5.000, z = 131.741 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 138.000, y = 0.000, z = -14.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = 5.000, y = -4.000, z = -175.000 },
            { name = 'HomePoint#4', kind = 'homepoint', x = -92.000, y = -2.000, z = 54.000 },
        },
    },

    [239] = -- Windurst_Walls
    {
        population = 13,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = 56.033, y = -3.625, z = -56.556 },
            { name = 'Auction_Counter', kind = 'auction', x = 47.980, y = -3.625, z = -56.724 },
            { name = 'Auction_Counter', kind = 'auction', x = 40.061, y = -3.624, z = -56.565 },
            { name = 'Auction_Counter', kind = 'auction', x = 31.992, y = -3.625, z = -56.529 },
            { name = 'Mog House door', kind = 'exit', x = -259.849, y = -8.494, z = -120.051 },
            { name = 'Toraimarai_Canal exit', kind = 'exit', x = -18.340, y = -2.709, z = 253.680 },
            { name = 'Windurst_Waters exit', kind = 'exit', x = -204.979, y = -7.031, z = 139.551 },
            { name = 'Windurst_Woods exit', kind = 'exit', x = 100.505, y = -7.090, z = -166.490 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -72.070, y = -5.013, z = 124.784 },
            { name = 'HomePoint#2', kind = 'homepoint', x = -212.000, y = 0.000, z = -99.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = 31.000, y = -6.500, z = -40.000 },
        },
    },

    [240] = -- Port_Windurst
    {
        population = 13,
        points =
        {
            { name = 'Mog House door', kind = 'exit', x = 197.805, y = -21.667, z = 264.495 },
            { name = 'West_Sarutabaruta exit', kind = 'exit', x = -249.083, y = -11.658, z = 199.980 },
            { name = 'Windurst_Waters exit', kind = 'exit', x = -114.594, y = -11.654, z = 215.791 },
            { name = 'Windurst_Woods exit', kind = 'exit', x = 230.555, y = -11.658, z = 179.926 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -188.000, y = -4.000, z = 101.000 },
            { name = 'HomePoint#2', kind = 'homepoint', x = -207.000, y = -8.160, z = 210.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = 180.000, y = -12.000, z = 226.000 },
        },
    },

    [241] = -- Windurst_Woods
    {
        population = 16,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = 63.278, y = -3.625, z = -132.257 },
            { name = 'Auction_Counter', kind = 'auction', x = 63.406, y = -3.625, z = -123.963 },
            { name = 'Auction_Counter', kind = 'auction', x = 63.365, y = -3.625, z = -115.946 },
            { name = 'Auction_Counter', kind = 'auction', x = 63.465, y = -3.625, z = -108.036 },
            { name = 'East_Sarutabaruta exit', kind = 'exit', x = 126.748, y = -9.457, z = -39.977 },
            { name = 'Mog House door', kind = 'exit', x = -144.727, y = -14.513, z = 40.005 },
            { name = 'Port_Windurst exit', kind = 'exit', x = -94.202, y = -1.707, z = -72.738 },
            { name = 'Windurst_Walls exit', kind = 'exit', x = -60.725, y = -7.184, z = 91.983 },
            { name = 'HomePoint#1', kind = 'homepoint', x = 9.088, y = -2.500, z = -0.383 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 107.000, y = -5.000, z = -56.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = -92.000, y = -5.000, z = 62.000 },
            { name = 'HomePoint#4', kind = 'homepoint', x = 74.000, y = -7.500, z = -139.000 },
            { name = 'HomePoint#5', kind = 'homepoint', x = -43.500, y = 0.000, z = -145.000 },
        },
    },

    [243] = -- RuLude_Gardens
    {
        population = 12,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = -74.739, y = 5.589, z = 0.746 },
            { name = 'Auction_Counter', kind = 'auction', x = -73.980, y = 5.589, z = -4.880 },
            { name = 'Auction_Counter', kind = 'auction', x = -74.075, y = 5.589, z = -10.938 },
            { name = 'Auction_Counter', kind = 'auction', x = -74.741, y = 5.589, z = -16.535 },
            { name = 'Mog House door', kind = 'exit', x = 48.989, y = 17.190, z = -79.994 },
            { name = 'Upper_Jeuno exit', kind = 'exit', x = -0.004, y = -2.494, z = -109.710 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -6.000, y = 3.000, z = 0.000 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 53.000, y = 9.000, z = -57.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = -67.000, y = 6.000, z = -25.000 },
        },
    },

    [244] = -- Upper_Jeuno
    {
        population = 10,
        points =
        {
            { name = 'Indika', kind = 'auction', x = -39.504, y = 7.999, z = 99.632 },
            { name = 'Shama_Pikholo', kind = 'auction', x = -68.083, y = 1.000, z = 19.285 },
            { name = 'Ulesa', kind = 'auction', x = -37.028, y = 7.999, z = 94.895 },
            { name = 'Wise_Wolf', kind = 'auction', x = -66.300, y = 1.000, z = 16.156 },
            { name = 'Batallia_Downs exit', kind = 'exit', x = -106.095, y = -4.637, z = 189.999 },
            { name = 'Lower_Jeuno exit', kind = 'exit', x = 4.763, y = -1.796, z = -54.883 },
            { name = 'Mog House door', kind = 'exit', x = 49.180, y = -9.642, z = -82.946 },
            { name = 'RuLude_Gardens exit', kind = 'exit', x = 46.000, y = -6.542, z = -30.915 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -98.981, y = 0.000, z = 167.569 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 32.000, y = -1.000, z = -44.000 },
            { name = 'HomePoint#3', kind = 'homepoint', x = -52.000, y = 1.000, z = 16.000 },
        },
    },

    [245] = -- Lower_Jeuno
    {
        population = 13,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = -16.089, y = -0.101, z = -32.041 },
            { name = 'Auction_Counter', kind = 'auction', x = -13.752, y = -0.101, z = -27.704 },
            { name = 'Auction_Counter', kind = 'auction', x = -11.264, y = -0.101, z = -23.385 },
            { name = 'Auction_Counter', kind = 'auction', x = -8.674, y = -0.101, z = -19.042 },
            { name = 'Mog House door', kind = 'exit', x = 43.944, y = -9.359, z = 88.580 },
            { name = 'Port_Jeuno exit', kind = 'exit', x = 29.694, y = -3.019, z = 41.444 },
            { name = 'Rolanberry_Fields exit', kind = 'exit', x = -123.065, y = -4.435, z = -200.691 },
            { name = 'Upper_Jeuno exit', kind = 'exit', x = 0.177, y = -6.280, z = 59.589 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -98.588, y = 0.000, z = -183.416 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 18.000, y = -1.000, z = 54.000 },
        },
    },

    [246] = -- Port_Jeuno
    {
        population = 10,
        points =
        {
            { name = 'Basmus', kind = 'auction', x = -43.032, y = 7.999, z = -3.967 },
            { name = 'Kouang', kind = 'auction', x = -35.026, y = 7.999, z = -4.039 },
            { name = 'Rilve-Hitolve', kind = 'auction', x = -31.025, y = 7.999, z = 3.745 },
            { name = 'Sapladrepoin', kind = 'auction', x = -38.910, y = 7.999, z = 3.836 },
            { name = 'Lower_Jeuno exit', kind = 'exit', x = -150.994, y = -6.324, z = -22.820 },
            { name = 'Mog House door', kind = 'exit', x = -197.560, y = -8.546, z = 0.005 },
            { name = 'Qufim_Island exit', kind = 'exit', x = -157.114, y = 9.878, z = 100.055 },
            { name = 'Sauromugue_Champaign exit', kind = 'exit', x = 54.979, y = -3.629, z = -0.019 },
            { name = 'HomePoint#1', kind = 'homepoint', x = 37.076, y = 0.000, z = 8.831 },
            { name = 'HomePoint#2', kind = 'homepoint', x = -155.000, y = -1.000, z = -4.000 },
        },
    },

    [247] = -- Rabao
    {
        population = 9,
        points =
        {
            { name = 'Cavalgrinne', kind = 'auction', x = 154.471, y = 7.999, z = 59.692 },
            { name = 'Hyesun', kind = 'auction', x = 127.995, y = 7.999, z = 50.619 },
            { name = 'Smiling_Rat', kind = 'auction', x = 151.091, y = 7.999, z = 57.837 },
            { name = 'Western_Altepa_Desert exit', kind = 'exit', x = -20.586, y = 6.412, z = -128.046 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -29.276, y = 0.000, z = -76.585 },
            { name = 'HomePoint#2', kind = 'homepoint', x = -21.000, y = 8.130, z = 110.000 },
        },
    },

    [248] = -- Selbina
    {
        population = 8,
        points =
        {
            { name = 'Valkurm_Dunes exit', kind = 'exit', x = 16.895, y = -19.333, z = 104.284 },
            { name = 'HomePoint#1', kind = 'homepoint', x = 36.117, y = -10.729, z = 34.635 },
        },
    },

    [249] = -- Mhaura
    {
        population = 10,
        points =
        {
            { name = 'Buburimu_Peninsula exit', kind = 'exit', x = -0.179, y = -8.549, z = 121.015 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -12.750, y = -15.791, z = 87.286 },
        },
    },

    [250] = -- Kazham
    {
        population = 9,
        points =
        {
            { name = 'Cha_Chalco', kind = 'auction', x = -120.725, y = -10.000, z = -45.940 },
            { name = 'Cophi_Ricuub', kind = 'auction', x = -120.775, y = -10.000, z = -37.974 },
            { name = 'Sulo_Mouzho', kind = 'auction', x = -120.720, y = -10.000, z = -30.034 },
            { name = 'Yuhtunga_Jungle exit', kind = 'exit', x = -50.004, y = -11.780, z = -111.502 },
            { name = 'HomePoint#1', kind = 'homepoint', x = 77.654, y = -13.000, z = -94.457 },
        },
    },

    [252] = -- Norg
    {
        population = 8,
        points =
        {
            { name = 'Agatsum', kind = 'auction', x = -61.737, y = -9.414, z = 80.019 },
            { name = 'Atrevaux', kind = 'auction', x = -77.833, y = -9.699, z = 82.420 },
            { name = 'Gofufu', kind = 'auction', x = -66.748, y = -10.612, z = 85.187 },
            { name = 'Zoldba', kind = 'auction', x = -71.017, y = -9.286, z = 85.951 },
            { name = 'Sea_Serpent_Grotto exit', kind = 'exit', x = -19.216, y = -3.609, z = -67.525 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -26.910, y = 0.296, z = -47.164 },
            { name = 'HomePoint#2', kind = 'homepoint', x = -66.000, y = -5.200, z = 54.000 },
        },
    },

    [256] = -- Western_Adoulin
    {
        population = 12,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = -68.160, y = 2.800, z = -90.160 },
            { name = 'Auction_Counter', kind = 'auction', x = -80.780, y = 2.800, z = -90.150 },
            { name = 'Auction_Counter', kind = 'auction', x = -85.040, y = 2.800, z = -86.030 },
            { name = 'Auction_Counter', kind = 'auction', x = -89.320, y = 2.800, z = -81.880 },
            { name = 'Auction_Counter', kind = 'auction', x = -93.500, y = 2.800, z = -77.580 },
            { name = 'Auction_Counter', kind = 'auction', x = -93.720, y = 2.800, z = -64.900 },
            { name = 'Ceizak_Battlegrounds exit', kind = 'exit', x = -160.300, y = 0.000, z = -26.000 },
            { name = 'Eastern_Adoulin exit', kind = 'exit', x = 180.000, y = 1.000, z = -20.000 },
            { name = 'Mog House door', kind = 'exit', x = -4.500, y = -3.308, z = -146.000 },
            { name = 'Rala_Waterways exit', kind = 'exit', x = 74.000, y = 8.845, z = -148.000 },
            { name = 'Rala_Waterways exit', kind = 'exit', x = -76.000, y = 21.051, z = 114.000 },
            { name = 'Rala_Waterways exit', kind = 'exit', x = 138.000, y = 16.761, z = 4.000 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -84.435, y = 3.999, z = -32.303 },
            { name = 'HomePoint#2', kind = 'homepoint', x = 31.950, y = 0.000, z = -164.000 },
        },
    },

    [257] = -- Eastern_Adoulin
    {
        population = 11,
        points =
        {
            { name = 'Auction_Counter', kind = 'auction', x = -21.000, y = -0.600, z = -92.000 },
            { name = 'Auction_Counter', kind = 'auction', x = -21.000, y = -0.600, z = -100.000 },
            { name = 'Auction_Counter', kind = 'auction', x = -21.000, y = -0.600, z = -108.000 },
            { name = 'Auction_Counter', kind = 'auction', x = -21.000, y = -0.600, z = -116.000 },
            { name = 'Mog House door', kind = 'exit', x = -56.000, y = -4.500, z = -140.000 },
            { name = 'Rala_Waterways exit', kind = 'exit', x = -122.000, y = 4.874, z = 28.000 },
            { name = 'Western_Adoulin exit', kind = 'exit', x = -165.000, y = -3.500, z = -20.000 },
            { name = 'HomePoint#1', kind = 'homepoint', x = -51.857, y = -0.150, z = 59.877 },
            { name = 'HomePoint#2', kind = 'homepoint', x = -51.500, y = -0.150, z = -96.500 },
        },
    },

}

return xi.xiLife.pois
