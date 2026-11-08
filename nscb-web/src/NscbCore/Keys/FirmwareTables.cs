namespace NscbCore.Keys;

/// <summary>
/// Key generation / RSV (required system version) / firmware string mapping tables.
/// Generations 0-20 verified against switchbrew (NCA page, 2025-11 snapshot) and the
/// NSC_BUILDER sq_tools.kgstring() tables; generations 21-23 follow the stable
/// one-key-generation-per-firmware-major pattern confirmed since generation 12
/// (21.0.0 - 2025-11, 22.0.0 - 2026, 23.0.0 - 2026-09).
/// </summary>
public static class FirmwareTables
{
    /// <summary>Highest key generation this build understands.</summary>
    public const int MaxKnownKeyGeneration = 23;

    /// <summary>
    /// Exact RSV values observed in the wild per key generation (NSC_BUILDER sq_tools).
    /// Index = key generation. Ordered high to low, matching the original tables.
    /// </summary>
    private static readonly uint[][] ExactRsvPerKg =
    {
        new uint[] { 450, 0 },                                                        // 0  1.0.0 - 2.3.0
        new uint[] { 262144, 196608, 131072, 65536 },                                 // 1  2.0.0 - 2.3.0
        new uint[] { 201326592 },                                                     // 2  3.0.0
        new uint[] { 201457664, 201392128 },                                          // 3  3.0.1 - 3.0.2
        new uint[] { 269484032, 268500992, 268435456 },                               // 4  4.0.0 - 4.1.0
        new uint[] { 336592896, 335675392, 335609856, 335544320 },                    // 5  5.0.0 - 5.1.0
        new uint[] { 403701760, 402718720, 402653184 },                               // 6  6.0.0 - 6.1.0
        new uint[] { 404750336 },                                                     // 7  6.2.0
        new uint[] { 536936448, 536870912, 469827584, 469762048 },                    // 8  7.0.0 - 8.0.1
        new uint[] { 537919488 },                                                     // 9  8.1.0
        new uint[] { 604045312, 603979776 },                                          // 10 9.0.0 - 9.0.1
        new uint[] { 805502976, 805437440, 805371904, 805306368, 738263040,           // 11 9.1.0 - 12.0.3
                     738197504, 673185792, 672202752, 672137216, 671350784,
                     671285248, 671219712, 671154176, 671088640, 606076928,
                     605028352 },
        new uint[] { 806354944 },                                                     // 12 12.1.0
        new uint[] { 874577920, 874512384, 873463808, 872415232 },                    // 13 13.0.0 - 13.2.1
        new uint[] { 940703744, 940638208, 940572672, 939524096 },                    // 14 14.0.0 - 14.1.2
        new uint[] { 1006698496, 1006632960 },                                        // 15 15.0.0 - 15.0.1
        new uint[] { 1074790400, 1073938432, 1073872896, 1073807360, 1073741824 },    // 16 16.0.0 - 16.1.0
        new uint[] { 1140916224, 1140850688 },                                        // 17 17.0.0 - 17.0.1
        new uint[] { 1209008128, 1208025088, 1207959552 },                            // 18 18.0.0 - 18.1.1
        new uint[] { 1275068416 },                                                    // 19 19.0.0 - 19.0.1
        new uint[] { 1347420160, 1342177280 },                                        // 20 20.0.0 - 20.5.0
        new uint[] { 1412433920, 1409286144 },                                        // 21 21.0.0 - 21.2.0
        new uint[] { 1476395008 },                                                    // 22 22.0.0 -
        new uint[] { 1543569408, 1543503872 },                                        // 23 23.0.0 - 23.0.1
    };

    /// <summary>Human readable firmware range per key generation (index = generation).</summary>
    private static readonly string[] FwRangePerKg =
    {
        "1.0.0 - 2.3.0",   // 0
        "2.0.0 - 2.3.0",   // 1
        "3.0.0",           // 2
        "3.0.1 - 3.0.2",   // 3
        "4.0.0 - 4.1.0",   // 4
        "5.0.0 - 5.1.0",   // 5
        "6.0.0 - 6.1.0",   // 6
        "6.2.0",           // 7
        "7.0.0 - 8.0.1",   // 8
        "8.1.0",           // 9
        "9.0.0 - 9.0.1",   // 10
        "9.1.0 - 12.0.3",  // 11
        "12.1.0",          // 12
        "13.0.0 - 13.2.1", // 13
        "14.0.0 - 14.1.2", // 14
        "15.0.0 - 15.0.1", // 15
        "16.0.0 - 16.1.0", // 16
        "17.0.0 - 17.0.1", // 17
        "18.0.0 - 18.1.1", // 18
        "19.0.0 - 19.0.1", // 19
        "20.0.0 - 20.5.0", // 20
        "21.0.0 - 21.2.0", // 21
        "22.0.0 -",        // 22
        "23.0.0 -",        // 23
    };

    /// <summary>Game card size flag (XCI header) to readable size.</summary>
    private static readonly Dictionary<byte, string> CardSizeNames = new()
    {
        [0xFA] = "1GB",
        [0xF8] = "2GB",
        [0xF0] = "4GB",
        [0xE0] = "8GB",
        [0xE1] = "16GB",
        [0xE2] = "32GB",
    };

    /// <summary>Human readable firmware range that uses the given key generation.</summary>
    public static string FwRangeForKeyGeneration(int keyGeneration)
    {
        if (keyGeneration < 0)
            return "unknown";
        if (keyGeneration < FwRangePerKg.Length)
            return FwRangePerKg[keyGeneration];
        return $"keygen {keyGeneration} (unknown firmware)";
    }

    /// <summary>First firmware version string that introduced the given key generation.</summary>
    public static string FirstFwForKeyGeneration(int keyGeneration)
    {
        string range = FwRangeForKeyGeneration(keyGeneration);
        int dash = range.IndexOf(" -", StringComparison.Ordinal);
        return dash > 0 ? range[..dash] : range;
    }

    /// <summary>Master key array index (master_key_NN) used by a key generation.</summary>
    public static int MasterKeyIndexFromKeyGeneration(int keyGeneration)
        => keyGeneration <= 1 ? 0 : keyGeneration - 1;

    /// <summary>Key generation implied by a master key index.</summary>
    public static int KeyGenerationFromMasterKeyIndex(int masterKeyIndex)
        => masterKeyIndex <= 0 ? 0 : masterKeyIndex + 1;

    /// <summary>True when the exact RSV is present in the observed-values table for its generation.</summary>
    public static bool IsExactKnownRsv(uint rsv)
    {
        for (int kg = 0; kg < ExactRsvPerKg.Length; kg++)
            if (ExactRsvPerKg[kg].Contains(rsv))
                return true;
        return false;
    }

    /// <summary>
    /// Maps an RSV value to the key generation it corresponds to.
    /// Generations up to 18 use exact value lookup; newer generations use range logic.
    /// Returns null when the value is not recognized.
    /// </summary>
    public static int? KeyGenerationFromRsv(uint rsv)
    {
        for (int kg = 0; kg < ExactRsvPerKg.Length; kg++)
        {
            if (ExactRsvPerKg[kg].Contains(rsv))
                return kg;
        }

        // Range fallback for values outside the exact tables (e.g. unseen patch releases):
        // an RSV belongs to the newest generation whose minimum RSV it reaches.
        int? best = null;
        for (int kg = 0; kg <= MaxKnownKeyGeneration; kg++)
        {
            uint min = MinRsvForKeyGeneration(kg);
            if (rsv >= min)
                best = kg;
        }

        return best;
    }

    /// <summary>Lowest RSV of a key generation (the firmware that introduced it).</summary>
    public static uint MinRsvForKeyGeneration(int keyGeneration)
    {
        if (keyGeneration < 0 || keyGeneration >= ExactRsvPerKg.Length)
            return uint.MaxValue;
        uint[] list = ExactRsvPerKg[keyGeneration];
        return list[list.Length - 1];
    }

    /// <summary>Highest RSV that still belongs to a key generation.</summary>
    public static uint TopRsvForKeyGeneration(int keyGeneration)
    {
        if (keyGeneration < 0 || keyGeneration >= ExactRsvPerKg.Length)
            return 0;
        uint[] list = ExactRsvPerKg[keyGeneration];
        return list[0];
    }

    /// <summary>
    /// Converts an RSV to a human readable firmware requirement, mirroring the
    /// NSC_BUILDER getFWRangeRSV semantics (including the legacy 1.x/2.x encodings).
    /// </summary>
    public static string FwStringFromRsv(uint rsv)
    {
        if (rsv >= 3u * 0x4000000)
        {
            uint major = rsv / 0x4000000;
            uint rem = rsv % 0x4000000;
            uint minor = rem / 0x100000;
            rem %= 0x100000;
            uint micro = rem / 0x10000;
            rem %= 0x10000;
            return FormatFw(major, minor, micro, rem);
        }

        if (rsv >= 0x10000)
        {
            uint sec = rsv / 0x10000;
            uint rem = rsv % 0x10000;
            return FormatFw(2, sec, 0, rem);
        }

        if (rsv > 0)
            return FormatFw(1, 0, 0, rsv % 0x10000);

        return "(1.0.0)";
    }

    /// <summary>
    /// Converts a firmware string ("19.0.1", "10.2.0-420") to the RSV value, mirroring
    /// the NSC_BUILDER transform_fw_string semantics.
    /// </summary>
    public static uint RsvFromFwString(string firmware)
    {
        if (string.IsNullOrWhiteSpace(firmware))
            return 0;

        string[] parts = firmware.Split('-');
        uint revision = parts.Length > 1 && uint.TryParse(parts[1], out uint r) ? r : 0;
        string[] nums = parts[0].Split('.');
        if (nums.Length < 2 || !int.TryParse(nums[0], out int major))
            return 0;
        int minor = nums.Length > 1 && int.TryParse(nums[1], out int m) ? m : 0;
        int micro = nums.Length > 2 && int.TryParse(nums[2], out int u) ? u : 0;

        uint rsv = 0;
        if (major >= 3)
            rsv += 0x4000000u * (uint)major;
        else if (major == 2)
            rsv += 0x10000;
        if (nums.Length > 1)
        {
            if (major > 3)
                rsv += 0x100000u * (uint)minor;
            else if (major == 2)
                rsv += (uint)minor;
        }

        if (nums.Length > 2 && major > 3)
            rsv += 0x10000u * (uint)micro;

        return rsv + revision;
    }

    /// <summary>Gamecard size flag (XCI header byte) for a file size, when a card fits.</summary>
    public static byte? CardSizeFlagForBytes(ulong bytes)
    {
        // Cards hold a little more than the raw content; use standard buckets.
        return bytes switch
        {
            <= 0x3AF400000 => 0xFA, // 1GB
            <= 0x756B80000 => 0xF8, // 2GB
            <= 0xEA6000000 => 0xF0, // 4GB
            <= 0x1D4C000000 => 0xE0, // 8GB
            <= 0x3A98000000 => 0xE1, // 16GB
            <= 0x7530000000 => 0xE2, // 32GB
            _ => null,
        };
    }

    /// <summary>Readable gamecard size for an XCI header size flag.</summary>
    public static string CardSizeName(byte flag)
        => CardSizeNames.TryGetValue(flag, out string? name) ? name : $"unknown (0x{flag:X2})";

    /// <summary>Byte capacity implied by a gamecard size flag.</summary>
    public static ulong? CardSizeBytes(byte flag) => flag switch
    {
        0xFA => 1_073_741_824UL,
        0xF8 => 2_147_483_648UL,
        0xF0 => 4_294_967_296UL,
        0xE0 => 8_589_934_592UL,
        0xE1 => 17_179_869_184UL,
        0xE2 => 34_359_738_368UL,
        _ => null,
    };

    private static string FormatFw(uint major, uint minor, uint micro, uint revision)
    {
        string s = $"{major}.{minor}.{micro}";
        if (revision > 0)
            s += $"-{revision}";
        return $"({s})";
    }
}
